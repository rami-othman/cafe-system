<?php

namespace App\Http\Resources\Menu;

use App\Http\Resources\Catalog\ProductSummaryResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MenuItemPlacementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'sectionId' => $this->menu_section_id, 'productId' => $this->product_id, 'displayNameOverride' => $this->display_name_override, 'displayDescriptionOverride' => $this->display_description_override, 'displayImageOverride' => $this->display_image_override, 'sortOrder' => $this->sort_order, 'isFeatured' => (bool) $this->is_featured, 'isVisible' => (bool) $this->is_visible, 'archivedAt' => $this->deleted_at, 'product' => new ProductSummaryResource($this->whenLoaded('product')), 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
