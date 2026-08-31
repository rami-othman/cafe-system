<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('order_items', function (Blueprint $table): void {
            // No foreign key: this is immutable selling identity, including after
            // a Catalog category is archived or deleted.
            $table->unsignedBigInteger('category_id')->nullable()->after('product_id')->index();
        });
        Schema::create('discount_usages', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('discount_id')->constrained();
            $table->foreignId('order_id')->constrained();
            $table->foreignId('payment_id')->nullable()->constrained()->nullOnDelete();
            $table->unsignedBigInteger('customer_id')->nullable();
            $table->timestamps();
            $table->unique('order_id');
            $table->index(['tenant_id', 'discount_id']);
            $table->index(['tenant_id', 'discount_id', 'customer_id']);
        });

        // Existing version-bound drafts predate order_items.category_id. Recover
        // their immutable category from the already-pinned published payload;
        // do not backfill from the mutable live Catalog.
        $categoriesByVersion = [];
        foreach (DB::table('order_items')->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->whereNotNull('orders.published_menu_version_id')
            ->whereNull('order_items.category_id')
            ->select('order_items.id as item_id', 'order_items.product_id', 'order_items.menu_item_placement_id', 'orders.published_menu_version_id')
            ->cursor() as $item) {
            $versionId = (int) $item->published_menu_version_id;
            if (! array_key_exists($versionId, $categoriesByVersion)) {
                $payload = json_decode((string) DB::table('published_menu_versions')->where('id', $versionId)->value('payload_json'), true) ?: [];
                $categoriesByVersion[$versionId] = [];
                foreach ($payload['menus'] ?? [] as $menu) {
                    foreach ($menu['sections'] ?? [] as $section) {
                        foreach ($section['products'] ?? [] as $product) {
                            $key = ((int) ($product['placementId'] ?? 0)).':'.((int) ($product['productId'] ?? 0));
                            $categoriesByVersion[$versionId][$key] = $product['categoryId'] ?? null;
                        }
                    }
                }
            }
            $key = ((int) $item->menu_item_placement_id).':'.((int) $item->product_id);
            $categoryId = $categoriesByVersion[$versionId][$key] ?? null;
            if ($categoryId !== null) {
                DB::table('order_items')->where('id', $item->item_id)->update(['category_id' => $categoryId]);
            }
        }

        $now = now();
        foreach (DB::table('order_discounts')->join('orders', 'orders.id', '=', 'order_discounts.order_id')
            ->whereNotNull('order_discounts.discount_id')->where('orders.payment_status', 'paid')
            ->select('order_discounts.tenant_id', 'order_discounts.discount_id', 'order_discounts.order_id', 'orders.customer_id')->cursor() as $usage) {
            DB::table('discount_usages')->updateOrInsert(['order_id' => $usage->order_id], [
                'tenant_id' => $usage->tenant_id, 'discount_id' => $usage->discount_id,
                'customer_id' => $usage->customer_id, 'created_at' => $now, 'updated_at' => $now,
            ]);
        }
        DB::statement('UPDATE discounts SET used_count = (SELECT COUNT(*) FROM discount_usages WHERE discount_usages.discount_id = discounts.id)');
    }

    public function down(): void
    {
        Schema::dropIfExists('discount_usages');
        Schema::table('order_items', fn (Blueprint $table) => $table->dropColumn('category_id'));
    }
};
