<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('order_items', function (Blueprint $table): void {
            $table->foreignId('menu_item_placement_id')->nullable()->after('product_variant_id')->constrained()->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('order_items', fn (Blueprint $table) => $table->dropConstrainedForeignId('menu_item_placement_id'));
    }
};
