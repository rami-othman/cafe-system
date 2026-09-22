<?php

namespace App\Services\Customer\Import;

use App\Domain\Customer\CustomerAccess;
use App\Domain\Customer\CustomerNameNormalizer;
use App\Domain\Customer\CustomerNumberGenerator;
use App\Models\Customer;
use App\Models\CustomerGroup;
use App\Models\CustomerImport;
use App\Models\CustomerImportRow;
use App\Services\OperationalAuditService;
use App\Support\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\StreamedResponse;

final class CustomerImportService
{
    private const PREVIEW_ROW_ISSUE_LIMIT = 25;

    public function __construct(
        private readonly CustomerAccess $access,
        private readonly CustomerCsvImportParser $parser,
        private readonly CustomerNumberGenerator $numbers,
        private readonly OperationalAuditService $audit,
    ) {}

    public function preview(Request $request, UploadedFile $file): CustomerImport
    {
        $actor = $this->access->actor($request);
        $tenantId = TenantContext::id($request);
        $parsed = $this->parser->parse($file);
        $rows = $this->classifyPreviewRows($tenantId, $parsed['rows']);

        $import = DB::transaction(function () use ($request, $actor, $tenantId, $file, $parsed, $rows): CustomerImport {
            $import = CustomerImport::query()->create([
                'tenant_id' => $tenantId,
                'actor_user_id' => $actor->id,
                'original_filename' => mb_substr($file->getClientOriginalName() ?: 'customers.csv', 0, 255),
                'file_fingerprint' => $parsed['fingerprint'],
                'detected_encoding' => $parsed['encoding'],
                'detected_delimiter' => $parsed['delimiter'],
                'status' => 'preview_ready',
                'total_rows' => count($rows),
                'ready_rows' => count(array_filter($rows, static fn (array $row): bool => in_array($row['status'], ['ready', 'warning'], true) && $row['classification'] !== 'duplicate')),
                'warning_rows' => count(array_filter($rows, static fn (array $row): bool => $row['warnings'] !== [])),
                'rejected_rows' => count(array_filter($rows, static fn (array $row): bool => $row['status'] === 'rejected')),
                'duplicate_candidates' => count(array_filter($rows, static fn (array $row): bool => $row['classification'] === 'duplicate')),
                'group_summary' => $this->groupSummary($rows),
            ]);

            foreach ($rows as $row) {
                $import->rows()->create([
                    'tenant_id' => $tenantId,
                    'source_row_number' => $row['sourceRowNumber'],
                    'legacy_customer_number' => $row['legacyCustomerNumber'],
                    'legacy_account_code' => $row['legacyAccountCode'],
                    'source_name' => $row['sourceName'],
                    'normalized_name' => $row['normalizedName'],
                    'source_phone_one' => $row['sourcePhoneOne'],
                    'source_mobile' => $row['sourceMobile'],
                    'source_group' => $row['sourceGroup'],
                    'parsed_payload' => $row['payload'],
                    'classification' => $row['classification'],
                    'status' => $row['status'],
                    'warning_codes' => $row['warnings'],
                    'error_codes' => $row['errors'],
                    'matched_customer_id' => $row['matchedCustomerId'] ?? null,
                ]);
            }

            $this->audit->recordContext($tenantId, 'customer.import.previewed', 'customer_import', $import->id, [
                'totalRows' => count($rows),
                'readyRows' => $import->ready_rows,
                'warningRows' => $import->warning_rows,
                'rejectedRows' => $import->rejected_rows,
            ], actorId: $actor->id, deduplicate: false);

            return $import;
        });

        return $this->loadImport($tenantId, (int) $import->id);
    }

    public function commit(Request $request, int $id, bool $createMissingGroups): CustomerImport
    {
        $actor = $this->access->actor($request);
        $tenantId = TenantContext::id($request);
        $shouldDispatch = false;
        $import = DB::transaction(function () use ($tenantId, $id, $actor, $createMissingGroups, &$shouldDispatch): CustomerImport {
            $import = CustomerImport::query()->forTenant($tenantId)->whereKey($id)->lockForUpdate()->firstOrFail();
            if (in_array($import->status, ['completed', 'completed_with_errors'], true)) {
                return $import;
            }
            if (! in_array($import->status, ['preview_ready', 'queued', 'processing', 'failed'], true)) {
                throw CustomerImportException::notReady();
            }
            if ($import->status === 'preview_ready' || $import->status === 'failed') {
                $completed = CustomerImport::query()->forTenant($tenantId)
                    ->where('file_fingerprint', $import->file_fingerprint)
                    ->whereIn('status', ['completed', 'completed_with_errors'])
                    ->where('id', '<>', $import->id)
                    ->exists();
                if ($completed) {
                    throw CustomerImportException::alreadyCompleted();
                }
                $import->update([
                    'status' => 'queued',
                    'create_missing_groups' => $createMissingGroups,
                    'failure_code' => null,
                    'completed_at' => null,
                    'updated_at' => now(),
                ]);
                $shouldDispatch = true;
            }

            return $import->fresh();
        });

        if ($shouldDispatch) {
            // The transaction above has already committed before dispatching.
            // This keeps the synchronous test queue deterministic and leaves
            // production free to process the same durable job asynchronously.
            \App\Jobs\ProcessCustomerImportJob::dispatch($import->id, $tenantId, $actor->id);
        }

        return $this->loadImport($tenantId, (int) $import->id);
    }

    public function find(Request $request, int $id): CustomerImport
    {
        $this->access->assertCanAdminister($request);

        return $this->loadImport(TenantContext::id($request), $id);
    }

    public function errors(Request $request, int $id): StreamedResponse
    {
        $import = $this->find($request, $id);
        $filename = 'customer-import-'.$import->id.'-errors.csv';

        return response()->streamDownload(function () use ($import): void {
            echo "\xEF\xBB\xBF";
            $handle = fopen('php://output', 'w');
            fputcsv($handle, ['row_number', 'status', 'classification', 'name', 'warnings', 'errors'], ',');
            $import->rows()->orderBy('source_row_number')->cursor()->each(function (CustomerImportRow $row) use ($handle): void {
                $warnings = $row->warning_codes ?? [];
                $errors = $row->error_codes ?? [];
                if ($warnings === [] && $errors === [] && ! in_array($row->status, ['failed', 'rejected'], true)) {
                    return;
                }
                fputcsv($handle, [
                    $row->source_row_number,
                    $this->safeCell($row->status),
                    $this->safeCell($row->classification),
                    $this->safeCell((string) $row->source_name),
                    $this->safeCell(implode('|', $warnings)),
                    $this->safeCell(implode('|', $errors)),
                ], ',');
            });
            fclose($handle);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    public function process(int $tenantId, int $id, int $actorId): void
    {
        $import = $this->loadImport($tenantId, $id);
        if (in_array($import->status, ['completed', 'completed_with_errors'], true)) {
            return;
        }

        try {
            $this->markStarted($tenantId, $id, $actorId);
            do {
                $rows = CustomerImportRow::query()->forTenant($tenantId)
                    ->where('customer_import_id', $id)
                    ->whereIn('status', ['ready', 'warning'])
                    ->orderBy('id')
                    ->limit(200)
                    ->get();
                foreach ($rows as $row) {
                    $this->processRow($tenantId, $import, (int) $row->id, $actorId);
                }
            } while ($rows->isNotEmpty());

            $this->finish($tenantId, $id, $actorId);
        } catch (\Throwable $exception) {
            Log::error('Customer import processing failed.', ['import_id' => $id, 'tenant_id' => $tenantId, 'exception' => $exception]);
            CustomerImport::query()->forTenant($tenantId)->whereKey($id)->update([
                'status' => 'failed',
                'failure_code' => 'CUSTOMER_IMPORT_FAILED',
                'completed_at' => now(),
                'updated_at' => now(),
            ]);
            $this->audit->recordContext($tenantId, 'customer.import.failed', 'customer_import', $id, ['code' => 'CUSTOMER_IMPORT_FAILED'], actorId: $actorId);
        }
    }

    /** @return array<int,array<string,mixed>> */
    private function classifyPreviewRows(int $tenantId, array $rows): array
    {
        $names = array_values(array_unique(array_filter(array_column($rows, 'normalizedName'))));
        $phones = [];
        foreach ($rows as $row) {
            foreach ($row['payload']['phones'] as $phone) {
                $phones[] = $phone['normalizedNumber'];
            }
        }
        $existingCustomers = DB::table('customers')->where('tenant_id', $tenantId)->whereIn('normalized_name', $names)->get(['id', 'normalized_name']);
        $existingPhones = DB::table('customer_phones')->where('tenant_id', $tenantId)->whereIn('normalized_number', array_values(array_unique($phones)))->get(['customer_id', 'normalized_number']);
        $customerNames = $existingCustomers->groupBy('normalized_name');
        $phonesByNumber = $existingPhones->groupBy('normalized_number');
        $groupNames = [];
        foreach ($rows as $candidate) {
            if (($candidate['payload']['groupNormalizedName'] ?? null) !== null) {
                $groupNames[] = $candidate['payload']['groupNormalizedName'];
            }
        }
        $groupRows = DB::table('customer_groups')->where('tenant_id', $tenantId)->whereIn('normalized_name', array_values(array_unique($groupNames)))->get(['id', 'name', 'normalized_name', 'is_active', 'deleted_at']);

        foreach ($rows as &$row) {
            if ($row['status'] === 'rejected') {
                continue;
            }
            $sameName = $customerNames->get($row['normalizedName'], collect());
            $rowPhoneNumbers = array_column($row['payload']['phones'], 'normalizedNumber');
            $sameNameAndPhone = $sameName->first(function (object $customer) use ($rowPhoneNumbers, $phonesByNumber): bool {
                if ($rowPhoneNumbers === []) {
                    return false;
                }
                foreach ($rowPhoneNumbers as $phone) {
                    if ($phonesByNumber->get($phone, collect())->contains(fn (object $match): bool => (int) $match->customer_id === (int) $customer->id)) {
                        return true;
                    }
                }

                return false;
            });
            if ($sameNameAndPhone) {
                $row['classification'] = 'duplicate';
                $row['status'] = 'ready';
                $row['matchedCustomerId'] = (int) $sameNameAndPhone->id;
            } else {
                if ($sameName->isNotEmpty()) {
                    $row['warnings'][] = 'SAME_NAME_WITHOUT_MATCHING_PHONE';
                }
                foreach ($rowPhoneNumbers as $phone) {
                    if ($phonesByNumber->get($phone, collect())->contains(fn (object $match): bool => ! $sameName->contains(fn (object $candidate): bool => (int) $candidate->id === (int) $match->customer_id))) {
                        $row['warnings'][] = 'SHARED_PHONE_WITH_DIFFERENT_NAME';
                        break;
                    }
                }
                $row['warnings'] = array_values(array_unique($row['warnings']));
                $row['status'] = $row['warnings'] === [] ? 'ready' : 'warning';
            }
            if ($row['classification'] !== 'duplicate' && ($row['payload']['groupNormalizedName'] ?? null) !== null) {
                $group = $groupRows->firstWhere('normalized_name', $row['payload']['groupNormalizedName']);
                if (! $group) {
                    $row['warnings'][] = 'MISSING_GROUP';
                } elseif (! $group->is_active || $group->deleted_at !== null) {
                    $row['warnings'][] = 'GROUP_UNAVAILABLE';
                }
                $row['warnings'] = array_values(array_unique($row['warnings']));
                if ($row['status'] === 'ready' && $row['warnings'] !== []) {
                    $row['status'] = 'warning';
                }
            }
        }
        unset($row);

        return $rows;
    }

    private function processRow(int $tenantId, CustomerImport $import, int $rowId, int $actorId): void
    {
        try {
            DB::transaction(function () use ($tenantId, $import, $rowId, $actorId): void {
                $row = CustomerImportRow::query()->forTenant($tenantId)->where('customer_import_id', $import->id)->whereKey($rowId)->lockForUpdate()->first();
                if (! $row || ! in_array($row->status, ['ready', 'warning'], true)) {
                    return;
                }
                $payload = $row->parsed_payload ?? [];
                $warnings = array_values(array_unique($row->warning_codes ?? []));
                $existing = $this->strongMatch($tenantId, (string) $row->normalized_name, array_column($payload['phones'] ?? [], 'normalizedNumber'));
                if ($existing) {
                    $row->update(['classification' => 'duplicate', 'status' => 'skipped_existing', 'matched_customer_id' => $existing->id]);
                    return;
                }
                if (DB::table('customers')->where('tenant_id', $tenantId)->where('normalized_name', $row->normalized_name)->exists()) {
                    $warnings[] = 'SAME_NAME_WITHOUT_MATCHING_PHONE';
                }
                foreach (array_column($payload['phones'] ?? [], 'normalizedNumber') as $number) {
                    if (DB::table('customer_phones')->where('tenant_id', $tenantId)->where('normalized_number', $number)->whereNotExists(function ($query) use ($tenantId, $row): void {
                        $query->select(DB::raw(1))->from('customers')->whereColumn('customers.id', 'customer_phones.customer_id')->where('customers.tenant_id', $tenantId)->where('customers.normalized_name', $row->normalized_name);
                    })->exists()) {
                        $warnings[] = 'SHARED_PHONE_WITH_DIFFERENT_NAME';
                        break;
                    }
                }

                $customer = Customer::query()->create([
                    'tenant_id' => $tenantId,
                    'name' => $payload['displayName'],
                    'normalized_name' => $payload['normalizedName'],
                    'customer_number' => $this->numbers->next($tenantId),
                    'phone' => null,
                    'is_active' => true,
                ]);
                $primaryRaw = null;
                foreach ($payload['phones'] ?? [] as $phone) {
                    $primary = (bool) ($phone['isPrimary'] ?? false);
                    if ($primary) {
                        $primaryRaw = $phone['rawNumber'];
                    }
                    DB::table('customer_phones')->insert([
                        'tenant_id' => $tenantId,
                        'customer_id' => $customer->id,
                        'raw_number' => $phone['rawNumber'],
                        'normalized_number' => $phone['normalizedNumber'],
                        'type' => $phone['type'] ?? 'phone',
                        'is_primary' => $primary,
                        'validation_status' => $phone['validationStatus'] ?? 'unverified',
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
                if ($primaryRaw !== null) {
                    $customer->update(['phone' => $primaryRaw]);
                }

                $createdGroupId = null;
                $membershipCreated = false;
                $groupNormalized = $payload['groupNormalizedName'] ?? null;
                if ($groupNormalized !== null) {
                    [$group, $createdGroupId, $groupWarning] = $this->resolveGroup($tenantId, $payload['groupName'], $groupNormalized, (bool) $import->create_missing_groups, $actorId);
                    $warnings = array_values(array_diff($warnings, ['MISSING_GROUP']));
                    if ($groupWarning !== null) {
                        $warnings[] = $groupWarning;
                    }
                    if ($group && $group->is_active && $group->deleted_at === null) {
                        $membershipCreated = DB::table('customer_group_memberships')->where('tenant_id', $tenantId)->where('customer_id', $customer->id)->where('customer_group_id', $group->id)->exists();
                        if (! $membershipCreated) {
                            DB::table('customer_group_memberships')->insert([
                                'tenant_id' => $tenantId,
                                'customer_id' => $customer->id,
                                'customer_group_id' => $group->id,
                                'created_at' => now(),
                                'updated_at' => now(),
                            ]);
                            $membershipCreated = true;
                        }
                    }
                }

                $row->update([
                    'classification' => 'imported',
                    'status' => 'imported',
                    'warning_codes' => array_values(array_unique($warnings)),
                    'created_customer_id' => $customer->id,
                    'created_group_id' => $createdGroupId,
                    'membership_created' => $membershipCreated,
                ]);
                $this->audit->recordContext($tenantId, 'customer.import.customer_imported', 'customer', $customer->id, ['importId' => $import->id, 'rowNumber' => $row->source_row_number], actorId: $actorId);
            });
        } catch (\Throwable $exception) {
            Log::warning('Customer import row failed.', ['import_id' => $import->id, 'row_id' => $rowId, 'tenant_id' => $tenantId, 'exception' => $exception]);
            CustomerImportRow::query()->forTenant($tenantId)->whereKey($rowId)->update([
                'classification' => 'failed',
                'status' => 'failed',
                'error_codes' => ['CUSTOMER_IMPORT_FAILED'],
                'updated_at' => now(),
            ]);
        }
    }

    private function strongMatch(int $tenantId, string $normalizedName, array $numbers): ?object
    {
        if ($numbers === []) {
            return null;
        }
        return DB::table('customers')->join('customer_phones', function ($join) use ($tenantId, $numbers): void {
            $join->on('customer_phones.customer_id', '=', 'customers.id')->where('customer_phones.tenant_id', $tenantId)->whereIn('customer_phones.normalized_number', $numbers);
        })->where('customers.tenant_id', $tenantId)->where('customers.normalized_name', $normalizedName)->select('customers.id')->first();
    }

    /** @return array{0:?object,1:?int,2:?string} */
    private function resolveGroup(int $tenantId, string $name, string $normalizedName, bool $create, int $actorId): array
    {
        $existing = DB::table('customer_groups')->where('tenant_id', $tenantId)->where('normalized_name', $normalizedName)->lockForUpdate()->first();
        if ($existing) {
            return [$existing, null, ($existing->is_active && $existing->deleted_at === null) ? null : 'GROUP_UNAVAILABLE'];
        }
        if (! $create) {
            return [null, null, 'MISSING_GROUP_NOT_CREATED'];
        }
        try {
            $group = CustomerGroup::query()->create(['tenant_id' => $tenantId, 'name' => $name, 'normalized_name' => $normalizedName, 'is_active' => true]);
        } catch (\Throwable $exception) {
            $group = DB::table('customer_groups')->where('tenant_id', $tenantId)->where('normalized_name', $normalizedName)->lockForUpdate()->first();
            if (! $group) {
                throw $exception;
            }
        }
        $this->audit->recordContext($tenantId, 'customer.import.group_created', 'customer_group', (int) $group->id, ['importGroup' => true], actorId: $actorId);

        return [$group, (int) $group->id, null];
    }

    private function markStarted(int $tenantId, int $id, int $actorId): void
    {
        $updated = CustomerImport::query()->forTenant($tenantId)->whereKey($id)->whereIn('status', ['queued', 'processing'])->update([
            'status' => 'processing',
            'started_at' => now(),
            'updated_at' => now(),
        ]);
        if ($updated > 0) {
            $this->audit->recordContext($tenantId, 'customer.import.started', 'customer_import', $id, ['status' => 'processing'], actorId: $actorId);
        }
    }

    private function finish(int $tenantId, int $id, int $actorId): void
    {
        $stats = $this->rowStats($tenantId, $id);
        $status = $stats['processedRows'] < $stats['totalRows'] ? 'processing' : (($stats['warningRows'] > 0 || $stats['rejectedRows'] > 0 || $stats['failedRows'] > 0) ? 'completed_with_errors' : 'completed');
        CustomerImport::query()->forTenant($tenantId)->whereKey($id)->update([
            'status' => $status,
            'processed_rows' => $stats['processedRows'],
            'created_customers' => $stats['createdCustomers'],
            'skipped_customers' => $stats['skippedCustomers'],
            'failed_rows' => $stats['failedRows'],
            'created_groups' => $stats['createdGroups'],
            'created_memberships' => $stats['createdMemberships'],
            'warning_rows' => $stats['warningRows'],
            'rejected_rows' => $stats['rejectedRows'],
            'completed_at' => $status === 'processing' ? null : now(),
            'failure_code' => $stats['failedRows'] > 0 ? 'CUSTOMER_IMPORT_FAILED' : null,
            'updated_at' => now(),
        ]);
        if ($status !== 'processing') {
            $this->audit->recordContext($tenantId, 'customer.import.completed', 'customer_import', $id, [
                'status' => $status,
                'createdCustomers' => $stats['createdCustomers'],
                'skippedCustomers' => $stats['skippedCustomers'],
                'failedRows' => $stats['failedRows'],
                'createdGroups' => $stats['createdGroups'],
                'createdMemberships' => $stats['createdMemberships'],
            ], actorId: $actorId);
        }
    }

    /** @return array<string,int> */
    private function rowStats(int $tenantId, int $id): array
    {
        $stats = ['totalRows' => 0, 'processedRows' => 0, 'createdCustomers' => 0, 'skippedCustomers' => 0, 'failedRows' => 0, 'createdGroups' => 0, 'createdMemberships' => 0, 'warningRows' => 0, 'rejectedRows' => 0];
        foreach (CustomerImportRow::query()->forTenant($tenantId)->where('customer_import_id', $id)->cursor() as $row) {
            $stats['totalRows']++;
            if (in_array($row->status, ['imported', 'skipped_existing', 'rejected', 'failed', 'duplicate'], true)) {
                $stats['processedRows']++;
            }
            if ($row->status === 'imported' && $row->created_customer_id !== null) $stats['createdCustomers']++;
            if ($row->status === 'skipped_existing' || $row->status === 'duplicate') $stats['skippedCustomers']++;
            if ($row->status === 'failed') $stats['failedRows']++;
            if ($row->created_group_id !== null) $stats['createdGroups']++;
            if ($row->membership_created) $stats['createdMemberships']++;
            if (($row->warning_codes ?? []) !== []) $stats['warningRows']++;
            if ($row->status === 'rejected') $stats['rejectedRows']++;
        }

        return $stats;
    }

    private function loadImport(int $tenantId, int $id): CustomerImport
    {
        return CustomerImport::query()->forTenant($tenantId)->whereKey($id)->with(['rows' => fn ($query) => $query->orderBy('source_row_number')->limit(self::PREVIEW_ROW_ISSUE_LIMIT)])->firstOrFail();
    }

    /** @return array{matched:array<int,string>,missing:array<int,string>} */
    private function groupSummary(array $rows): array
    {
        $matched = [];
        $missing = [];
        foreach ($rows as $row) {
            $group = $row['payload']['groupName'] ?? null;
            if ($group === null) continue;
            if (in_array('MISSING_GROUP', $row['warnings'], true)) $missing[$row['payload']['groupNormalizedName']] = $group;
            else $matched[$row['payload']['groupNormalizedName']] = $group;
        }

        return ['matched' => array_values($matched), 'missing' => array_values($missing)];
    }

    private function safeCell(string $value): string
    {
        return preg_match('/^[=+\-@]/', $value) === 1 ? "'".$value : $value;
    }

    /** @return array<string,mixed> */
    public function serialize(CustomerImport $import): array
    {
        $rows = $import->relationLoaded('rows') ? $import->rows : collect();

        return [
            'id' => (int) $import->id,
            'filename' => $import->original_filename,
            'fingerprint' => $import->file_fingerprint,
            'encoding' => $import->detected_encoding,
            'delimiter' => $import->detected_delimiter === "\t" ? 'tab' : $import->detected_delimiter,
            'status' => $import->status,
            'createMissingGroups' => $import->create_missing_groups,
            'counts' => [
                'total' => (int) $import->total_rows,
                'ready' => (int) $import->ready_rows,
                'warnings' => (int) $import->warning_rows,
                'rejected' => (int) $import->rejected_rows,
                'duplicateCandidates' => (int) $import->duplicate_candidates,
                'processed' => (int) $import->processed_rows,
                'createdCustomers' => (int) $import->created_customers,
                'skippedCustomers' => (int) $import->skipped_customers,
                'failedRows' => (int) $import->failed_rows,
                'createdGroups' => (int) $import->created_groups,
                'createdMemberships' => (int) $import->created_memberships,
            ],
            'groups' => $import->group_summary ?? ['matched' => [], 'missing' => []],
            'issues' => $rows->filter(fn (CustomerImportRow $row): bool => ($row->warning_codes ?? []) !== [] || ($row->error_codes ?? []) !== [] || $row->classification === 'duplicate' || in_array($row->status, ['duplicate', 'skipped_existing'], true))->map(fn (CustomerImportRow $row): array => [
                'rowNumber' => (int) $row->source_row_number,
                'name' => $row->source_name,
                'status' => $row->status,
                'classification' => $row->classification,
                'warnings' => $row->warning_codes ?? [],
                'errors' => $row->error_codes ?? [],
            ])->values()->all(),
            'startedAt' => $import->started_at?->toISOString(),
            'completedAt' => $import->completed_at?->toISOString(),
            'failureCode' => $import->failure_code,
            'errorReportAvailable' => $import->warning_rows > 0 || $import->rejected_rows > 0 || $import->failed_rows > 0,
        ];
    }
}
