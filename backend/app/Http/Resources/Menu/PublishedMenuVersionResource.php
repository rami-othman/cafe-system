<?php

namespace App\Http\Resources\Menu;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PublishedMenuVersionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'versionNumber' => $this->version_number, 'checksum' => $this->checksum, 'status' => $this->status instanceof \BackedEnum ? $this->status->value : $this->status, 'branchId' => $this->branch_id, 'channel' => $this->channel instanceof \BackedEnum ? $this->channel->value : $this->channel, 'publishedAt' => $this->published_at?->toIso8601String(), 'publicationId' => $this->menu_publication_id];
    }
}
