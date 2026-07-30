<?php

namespace App\Services\Menu;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Domain\Menu\Enums\MenuPublicationStatus;
use App\Domain\Menu\Enums\PublishedMenuVersionStatus;
use App\Models\MenuAuditLog;
use App\Models\MenuPublication;
use App\Models\PublishedMenuVersion;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PublishedMenuVersionService
{
    public function __construct(private readonly MenuValidationService $validation, private readonly PublishedMenuVersionComparisonService $comparison) {}

    public function history(int $tenant, array $input)
    {
        $b = $this->validation->branch($tenant, $input['branchId']);

        return PublishedMenuVersion::query()->with('menuPublication')->where('tenant_id', $tenant)->where('branch_id', $b->id)->where('channel', $input['channel'])->orderByDesc('version_number')->paginate($input['perPage'] ?? 20);
    }

    public function version(int $tenant, int $id): PublishedMenuVersion
    {
        return PublishedMenuVersion::query()->with('menuPublication')->where('tenant_id', $tenant)->findOrFail($id);
    }

    public function compare(int $tenant, int $id, int $against): array
    {
        $from = $this->version($tenant, $id);
        $to = $this->version($tenant, $against);
        if ($from->branch_id !== $to->branch_id || $this->value($from->channel) !== $this->value($to->channel)) {
            throw ValidationException::withMessages(['againstVersionId' => 'Versions must share a branch and channel.']);
        }

return $this->comparison->compare($from, $to);
    }

    public function rollback(int $tenant, int $id, array $input): array
    {
        $target = $this->version($tenant, $id);
        $p = MenuPublication::query()->create(['tenant_id' => $tenant, 'status' => MenuPublicationStatus::Pending, 'source_publication_id' => $target->menu_publication_id]);
        $this->audit($tenant, $p, MenuAuditAction::RollbackStarted, ['sourceVersionId' => $target->id]);
        try {
            return DB::transaction(function () use ($tenant, $target, $p, $input) {
                $channel = $this->value($target->channel);
                DB::select('SELECT pg_advisory_xact_lock(hashtext(?))', ["menu-publish:{$tenant}:{$target->branch_id}:{$channel}"]);
                $current = PublishedMenuVersion::query()->where('tenant_id', $tenant)->where('branch_id', $target->branch_id)->where('channel', $channel)->where('status', PublishedMenuVersionStatus::Current)->lockForUpdate()->first();
                if ($current && hash_equals($current->checksum, $target->checksum)) {
                    $p->update(['status' => MenuPublicationStatus::Published, 'change_summary' => ['rollbackReason' => $input['reason'] ?? null, 'sourceVersionId' => $target->id, 'noChanges' => true], 'published_at' => now()]);
                    $this->audit($tenant, $p, MenuAuditAction::RollbackNoChanges, ['sourceVersionId' => $target->id]);

                    return $this->reply(false, true, $p, $target, null);
                } $next = ((int) PublishedMenuVersion::query()->where('tenant_id', $tenant)->where('branch_id', $target->branch_id)->where('channel', $channel)->max('version_number')) + 1;
                if ($current) {
                    $current->update(['status' => PublishedMenuVersionStatus::RolledBack]);
                    $this->audit($tenant, $p, MenuAuditAction::VersionRolledBack, ['versionNumber' => $current->version_number]);
                }$new = PublishedMenuVersion::query()->create(['tenant_id' => $tenant, 'menu_publication_id' => $p->id, 'branch_id' => $target->branch_id, 'channel' => $channel, 'version_number' => $next, 'payload_json' => $target->payload_json, 'checksum' => $target->checksum, 'status' => PublishedMenuVersionStatus::Current, 'published_at' => now()]);
                $p->update(['status' => MenuPublicationStatus::Published, 'change_summary' => ['rollbackReason' => $input['reason'] ?? null, 'sourceVersionId' => $target->id, 'versionNumber' => $next], 'published_at' => now()]);
                $this->audit($tenant, $p, MenuAuditAction::Published, ['sourceVersionId' => $target->id, 'versionNumber' => $next]);

                return $this->reply(true, false, $p, $target, $new);
            });
        } catch (\Throwable $e) {
            $p->refresh();
            if ($p->status === MenuPublicationStatus::Pending) {
                $p->update(['status' => MenuPublicationStatus::Failed, 'failure_message' => 'Rollback could not be completed.']);
                $this->audit($tenant, $p, MenuAuditAction::RollbackFailed, ['sourceVersionId' => $target->id]);
            }throw $e;
        }
    }

    private function reply(bool $rolled, bool $none, MenuPublication $p, PublishedMenuVersion $source, ?PublishedMenuVersion $version): array
    {
        $v = $version ?? $source;

        return ['rolledBack' => $rolled, 'noChanges' => $none, 'publicationId' => $p->id, 'sourceVersion' => ['id' => $source->id, 'versionNumber' => $source->version_number], 'version' => ['id' => $v->id, 'versionNumber' => $v->version_number, 'checksum' => $v->checksum, 'status' => $this->value($v->status)]];
    }

    private function audit(int $tenant, MenuPublication $p, MenuAuditAction $a, array $data): void
    {
        MenuAuditLog::query()->create(['tenant_id' => $tenant, 'menu_publication_id' => $p->id, 'entity_type' => MenuPublication::class, 'entity_id' => $p->id, 'action' => $a, 'after_data' => $data]);
    }

    private function value(mixed $v): mixed
    {
        return $v instanceof \BackedEnum ? $v->value : $v;
    }
}
