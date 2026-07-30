<?php

namespace App\Services\Menu;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Domain\Menu\Enums\MenuPublicationStatus;
use App\Domain\Menu\Enums\PublishedMenuVersionStatus;
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
        $branch = $this->validation->branch($tenantId, $input['branchId']);
        $menuIds = $this->menuIds($tenantId, $branch->id, $input['channel'], $input['menuIds'] ?? null);
        $publication = MenuPublication::query()->create(['tenant_id' => $tenantId, 'status' => MenuPublicationStatus::Pending]);
        $this->audit($tenantId, $publication, MenuAuditAction::PublicationStarted, ['branchId' => $branch->id, 'channel' => $input['channel'], 'menuIds' => $menuIds]);
        $result = $menuIds === []
            ? ['isValid' => false, 'errorCount' => 1, 'warningCount' => 0, 'informationCount' => 0, 'errors' => [['code' => 'NO_ASSIGNED_MENU', 'severity' => 'error', 'message' => 'No actively assigned menus are available for publishing.']], 'warnings' => [], 'information' => [], 'menus' => []]
            : $this->validation->validateCollection($tenantId, $branch, $input['channel'], $menuIds, null)->toArray();
        if ($result['errorCount'] > 0) {
            $publication->update(['status' => MenuPublicationStatus::Failed, 'validation_result' => $this->boundedValidation($result), 'failure_message' => 'Menu validation failed.']);
            $this->audit($tenantId, $publication, MenuAuditAction::PublicationFailed, ['branchId' => $branch->id, 'channel' => $input['channel'], 'validation' => $this->counts($result)]);
            throw ValidationException::withMessages(['publish' => 'Menu validation failed.']);
        }

        try {
            return DB::transaction(function () use ($tenantId, $branch, $input, $menuIds, $publication, $result): array {
                DB::select('SELECT pg_advisory_xact_lock(hashtext(?))', ["menu-publish:{$tenantId}:{$branch->id}:{$input['channel']}"]);
                $current = PublishedMenuVersion::query()->where('tenant_id', $tenantId)->where('branch_id', $branch->id)->where('channel', $input['channel'])->where('status', PublishedMenuVersionStatus::Current)->lockForUpdate()->first();
                $snapshot = $this->snapshots->build($tenantId, $branch, $input['channel'], $menuIds);
                $checksum = $this->serializer->checksum($snapshot);
                if ($current && hash_equals($current->checksum, $checksum)) {
                    $publication->update(['status' => MenuPublicationStatus::Published, 'validation_result' => $this->boundedValidation($result), 'change_summary' => ['branchId' => $branch->id, 'channel' => $input['channel'], 'menuIds' => $menuIds, 'noChanges' => true], 'published_at' => now()]);
                    $this->audit($tenantId, $publication, MenuAuditAction::PublicationNoChanges, ['branchId' => $branch->id, 'channel' => $input['channel'], 'versionNumber' => $current->version_number, 'checksum' => $checksum, 'noChanges' => true]);

                    return $this->response(false, true, $publication, $current, $result);
                }
                $next = ((int) PublishedMenuVersion::query()->where('tenant_id', $tenantId)->where('branch_id', $branch->id)->where('channel', $input['channel'])->max('version_number')) + 1;
                if ($current) {
                    $current->update(['status' => PublishedMenuVersionStatus::Superseded]);
                    $this->audit($tenantId, $publication, MenuAuditAction::VersionSuperseded, ['branchId' => $branch->id, 'channel' => $input['channel'], 'versionNumber' => $current->version_number]);
                }
                $version = PublishedMenuVersion::query()->create(['tenant_id' => $tenantId, 'menu_publication_id' => $publication->id, 'branch_id' => $branch->id, 'channel' => $input['channel'], 'version_number' => $next, 'payload_json' => $snapshot, 'checksum' => $checksum, 'status' => PublishedMenuVersionStatus::Current, 'published_at' => now()]);
                $publication->update(['status' => MenuPublicationStatus::Published, 'validation_result' => $this->boundedValidation($result), 'change_summary' => ['branchId' => $branch->id, 'channel' => $input['channel'], 'menuIds' => $menuIds, 'versionNumber' => $next, 'checksum' => $checksum, 'noChanges' => false], 'published_at' => now()]);
                $this->audit($tenantId, $publication, MenuAuditAction::Published, ['branchId' => $branch->id, 'channel' => $input['channel'], 'versionNumber' => $next, 'checksum' => $checksum, 'noChanges' => false]);

                return $this->response(true, false, $publication, $version, $result);
            });
        } catch (\Throwable $exception) {
            $publication->refresh();
            if ($publication->status === MenuPublicationStatus::Pending) {
                $publication->update(['status' => MenuPublicationStatus::Failed, 'failure_message' => 'Publishing could not be completed.']);
                $this->audit($tenantId, $publication, MenuAuditAction::PublicationFailed, ['branchId' => $branch->id, 'channel' => $input['channel']]);
            }
            throw $exception;
        }
    }

    public function current(int $tenantId, array $input): ?PublishedMenuVersion
    {
        $branch = $this->validation->branch($tenantId, $input['branchId']);

        return PublishedMenuVersion::query()->where('tenant_id', $tenantId)->where('branch_id', $branch->id)->where('channel', $input['channel'])->where('status', PublishedMenuVersionStatus::Current)->first();
    }

    private function menuIds(int $tenantId, int $branchId, string $channel, ?array $submitted): array
    {
        if ($submitted !== null) {
            $count = Menu::withTrashed()->where('tenant_id', $tenantId)->whereIn('id', $submitted)->count();
            if ($count !== count($submitted)) {
                throw ValidationException::withMessages(['menuIds' => 'One or more selected menus are invalid.']);
            }

            return array_values($submitted);
        }

        return Menu::query()->where('tenant_id', $tenantId)->whereHas('assignments', fn ($q) => $q->where('branch_id', $branchId)->where('channel', $channel)->where('is_active', true))->orderBy('priority')->orderBy('id')->pluck('id')->all();
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
