<?php

namespace App\Services\Menu;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Domain\Menu\Enums\MenuPublicationStatus;
use App\Domain\Menu\Enums\PublishedMenuVersionStatus;
use App\Models\Branch;
use App\Models\Menu;
use App\Models\MenuAuditLog;
use App\Models\MenuPublication;
use App\Models\PublishedMenuVersion;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class MenuPublishingService
{
    public function __construct(private readonly MenuValidationService $validation, private readonly PublishedMenuSnapshotBuilder $snapshots, private readonly CanonicalMenuSnapshotSerializer $serializer) {}

    public function publish(int $tenantId, array $input): array
    {
        $automatic = ! array_key_exists('menuIds', $input);
        $publication = MenuPublication::query()->create(['tenant_id' => $tenantId, 'status' => MenuPublicationStatus::Pending]);
        $lockKey = "menu-publish:{$tenantId}:{$input['branchId']}:{$input['channel']}";

        try {
            // This must be a session lock, not an xact lock: a blocked
            // pg_advisory_xact_lock establishes its transaction snapshot
            // before it wakes. Acquiring first means the transaction below
            // begins only after the preceding publisher has committed.
            DB::select('SELECT pg_advisory_lock(hashtext(?))', [$lockKey]);
            try {
                $outcome = DB::transaction(function ($connection) use ($tenantId, $input, $automatic, $publication): array {
                    // PostgreSQL establishes a REPEATABLE READ snapshot on the
                    // first statement. Set it before resolving the scope so
                    // validation and the subsequently-built payload observe the
                    // exact same authoritative database state. PostgreSQL forbids
                    // changing isolation inside a savepoint, so production refuses
                    // a caller-owned transaction rather than silently weakening
                    // the invariant. Laravel's transaction-wrapped feature tests
                    // are the only intentional exception.
                    if ($connection->transactionLevel() === 1) {
                        $connection->statement('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
                    } elseif (! app()->environment('testing')) {
                        throw new \LogicException('Menu publishing must begin its own transaction.');
                    }
                    $branch = $this->validation->branch($tenantId, $input['branchId']);
                    $menuIds = $this->menuIds($tenantId, $branch->id, $input['channel'], $automatic ? null : $input['menuIds']);
                    $this->audit($tenantId, $publication, MenuAuditAction::PublicationStarted, ['branchId' => $branch->id, 'channel' => $input['channel'], 'menuIds' => $menuIds]);
                    $result = $this->validation->validateCollection($tenantId, $branch, $input['channel'], $automatic ? null : $menuIds, null)->toArray();
                    if ($result['errorCount'] > 0) {
                        $publication->update(['status' => MenuPublicationStatus::Failed, 'validation_result' => $this->boundedValidation($result), 'failure_message' => 'Menu validation failed.']);
                        $this->audit($tenantId, $publication, MenuAuditAction::PublicationFailed, ['branchId' => $branch->id, 'channel' => $input['channel'], 'validation' => $this->counts($result)]);

                        return ['validationFailure' => true];
                    }
                    $current = PublishedMenuVersion::query()->where('tenant_id', $tenantId)->where('branch_id', $branch->id)->where('channel', $input['channel'])->where('status', PublishedMenuVersionStatus::Current)->lockForUpdate()->first();
                    $snapshot = $this->snapshots->build($tenantId, $branch, $input['channel'], $menuIds);
                    $checksum = $this->serializer->checksum($snapshot);
                    if ($current && hash_equals($current->checksum, $checksum)) {
                        $publication->update(['status' => MenuPublicationStatus::Published, 'validation_result' => $this->boundedValidation($result), 'change_summary' => ['branchId' => $branch->id, 'channel' => $input['channel'], 'menuIds' => $menuIds, 'noChanges' => true], 'published_at' => now()]);
                        $this->audit($tenantId, $publication, MenuAuditAction::PublicationNoChanges, ['branchId' => $branch->id, 'channel' => $input['channel'], 'versionNumber' => $current->version_number, 'checksum' => $checksum, 'noChanges' => true]);

                        return ['response' => $this->response(false, true, $publication, $current, $result)];
                    }
                    $next = ((int) PublishedMenuVersion::query()->where('tenant_id', $tenantId)->where('branch_id', $branch->id)->where('channel', $input['channel'])->max('version_number')) + 1;
                    if ($current) {
                        $current->update(['status' => PublishedMenuVersionStatus::Superseded]);
                        $this->audit($tenantId, $publication, MenuAuditAction::VersionSuperseded, ['branchId' => $branch->id, 'channel' => $input['channel'], 'versionNumber' => $current->version_number]);
                    }
                    $version = PublishedMenuVersion::query()->create(['tenant_id' => $tenantId, 'menu_publication_id' => $publication->id, 'branch_id' => $branch->id, 'channel' => $input['channel'], 'version_number' => $next, 'payload_json' => $snapshot, 'checksum' => $checksum, 'status' => PublishedMenuVersionStatus::Current, 'published_at' => now()]);
                    $publication->update(['status' => MenuPublicationStatus::Published, 'validation_result' => $this->boundedValidation($result), 'change_summary' => ['branchId' => $branch->id, 'channel' => $input['channel'], 'menuIds' => $menuIds, 'versionNumber' => $next, 'checksum' => $checksum, 'noChanges' => false], 'published_at' => now()]);
                    $this->audit($tenantId, $publication, MenuAuditAction::Published, ['branchId' => $branch->id, 'channel' => $input['channel'], 'versionNumber' => $next, 'checksum' => $checksum, 'noChanges' => false]);

                    return ['response' => $this->response(true, false, $publication, $version, $result)];
                });
            } finally {
                DB::select('SELECT pg_advisory_unlock(hashtext(?))', [$lockKey]);
            }
            if ($outcome['validationFailure'] ?? false) {
                throw ValidationException::withMessages(['publish' => 'Menu validation failed.']);
            }

            return $outcome['response'];
        } catch (\Throwable $exception) {
            $publication->refresh();
            if ($publication->status === MenuPublicationStatus::Pending) {
                $publication->update(['status' => MenuPublicationStatus::Failed, 'failure_message' => 'Publishing could not be completed.']);
                $this->audit($tenantId, $publication, MenuAuditAction::PublicationFailed, ['branchId' => $input['branchId'], 'channel' => $input['channel']]);
            }
            throw $exception;
        }
    }

    public function current(int $tenantId, array $input): ?PublishedMenuVersion
    {
        $branch = $this->validation->branch($tenantId, $input['branchId']);

        return $this->currentForBranch($tenantId, $branch, $input['channel']);
    }

    public function currentForBranch(int $tenantId, Branch $branch, string $channel): ?PublishedMenuVersion
    {
        return PublishedMenuVersion::query()->where('tenant_id', $tenantId)->where('branch_id', $branch->id)->where('channel', $channel)->where('status', PublishedMenuVersionStatus::Current)->first();
    }

    private function menuIds(int $tenantId, int $branchId, string $channel, ?array $submitted): array
    {
        if ($submitted !== null) {
            $count = Menu::withTrashed()->where('tenant_id', $tenantId)->whereIn('id', $submitted)->count();
            if ($count !== count($submitted)) {
                throw ValidationException::withMessages(['menuIds' => 'One or more selected menus are invalid.']);
            }

            // Explicit subsets retain the existing global Menu canonical order.
            return Menu::withTrashed()->where('tenant_id', $tenantId)->whereIn('id', $submitted)->orderBy('priority')->orderBy('id')->pluck('id')->all();
        }

        return $this->validation->assignedMenuIds($tenantId, $branchId, $channel);
    }

    private function response(bool $published, bool $noChanges, MenuPublication $publication, PublishedMenuVersion $version, array $validation): array
    {
        return ['published' => $published, 'noChanges' => $noChanges, 'publicationId' => $publication->id, 'version' => ['id' => $version->id, 'versionNumber' => $version->version_number, 'checksum' => $version->checksum, 'status' => $this->value($version->status), 'publishedAt' => $version->published_at?->toIso8601String()], 'validation' => ['isValid' => true] + $this->counts($validation)];
    }

    private function boundedValidation(array $result): array
    {
        return $this->counts($result) + ['errors' => array_slice($result['errors'], 0, 20), 'warnings' => array_slice($result['warnings'], 0, 20), 'information' => array_slice($result['information'], 0, 20)];
    }

    private function counts(array $result): array
    {
        return ['errorCount' => $result['errorCount'], 'warningCount' => $result['warningCount'], 'informationCount' => $result['informationCount']];
    }

    private function audit(int $tenantId, MenuPublication $publication, MenuAuditAction $action, array $after): void
    {
        MenuAuditLog::query()->create(['tenant_id' => $tenantId, 'menu_publication_id' => $publication->id, 'entity_type' => MenuPublication::class, 'entity_id' => $publication->id, 'action' => $action, 'after_data' => $after]);
    }

    private function value(mixed $value): mixed
    {
        return $value instanceof \BackedEnum ? $value->value : $value;
    }
}
