<?php

namespace App\Services\Menu;

class MenuValidationIssue
{
    public function __construct(public readonly string $code, public readonly string $severity, public readonly string $message, public readonly string $entityType, public readonly ?int $entityId, public readonly int $menuId, public readonly ?int $sectionId = null, public readonly ?int $placementId = null, public readonly array $metadata = []) {}

    public function toArray(): array
    {
        return ['code' => $this->code, 'severity' => $this->severity, 'message' => $this->message, 'entityType' => $this->entityType, 'entityId' => $this->entityId, 'menuId' => $this->menuId, 'sectionId' => $this->sectionId, 'placementId' => $this->placementId, 'metadata' => $this->metadata];
    }
}
