<?php

namespace App\Http\Resources\Menu;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MenuAssignmentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'menuId' => $this->menu_id, 'branchId' => $this->branch_id, 'channel' => $this->channel instanceof \BackedEnum ? $this->channel->value : $this->channel, 'priority' => $this->priority, 'isActive' => (bool) $this->is_active, 'menu' => MenuSummaryResource::make($this->whenLoaded('menu')), 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
