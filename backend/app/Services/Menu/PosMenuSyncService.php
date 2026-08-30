<?php

namespace App\Services\Menu;

use App\Domain\Menu\Enums\SalesChannel;
use App\Models\Branch;

class PosMenuSyncService
{
    public function __construct(private readonly MenuValidationService $validation, private readonly MenuPublishingService $publishing, private readonly PublishedMenuPosMapper $mapper, private readonly PosMenuRuntimeService $runtime) {}

    public function sync(int $tenantId, int $branchId, ?int $knownVersionId): array
    {
        $branch = $this->validation->branch($tenantId, $branchId);
        $version = $this->publishing->currentForBranch($tenantId, $branch, SalesChannel::Pos->value);
        $context = $this->context($branch);
        if ($version === null) {
            return ['context' => $context, 'upToDate' => false, 'version' => null, 'menu' => null, 'runtime' => null];
        }

        $sourceSchemaVersion = $this->mapper->sourceSchemaVersion($version->payload_json);
        $upToDate = $knownVersionId !== null && $knownVersionId === $version->id;

        return ['context' => $context, 'upToDate' => $upToDate,
            'version' => ['id' => $version->id, 'versionNumber' => $version->version_number, 'publishedAt' => $version->published_at?->toIso8601String(), 'sourceSchemaVersion' => $sourceSchemaVersion, 'runtimeContractVersion' => PublishedMenuPosMapper::RUNTIME_CONTRACT_VERSION],
            'menu' => $upToDate ? null : $this->mapper->menu($version->payload_json),
            'runtime' => $this->runtime->resolve($tenantId, $branch, $version->payload_json)];
    }

    private function context(Branch $branch): array
    {
        return ['branchId' => $branch->id, 'channel' => SalesChannel::Pos->value, 'timezone' => $branch->timezone ?: config('app.timezone'), 'currency' => $branch->currency];
    }
}
