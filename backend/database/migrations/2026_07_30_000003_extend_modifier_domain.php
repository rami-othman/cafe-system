<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('modifier_groups', function (Blueprint $table): void {
            $table->string('group_type')->default('choice')->after('selection_type');
            $table->boolean('allow_quantity')->default(false)->after('max_selections');
        });
        Schema::table('modifier_options', function (Blueprint $table): void {
            $table->decimal('cost_delta', 12, 2)->default(0)->after('price_delta');
            $table->boolean('is_active')->default(true)->after('is_default');
        });
        Schema::table('product_modifier_group', function (Blueprint $table): void {
            $table->boolean('is_required_override')->nullable()->after('sort_order');
            $table->unsignedInteger('min_selections_override')->nullable()->after('is_required_override');
            $table->unsignedInteger('max_selections_override')->nullable()->after('min_selections_override');
            $table->boolean('allow_quantity_override')->nullable()->after('max_selections_override');
        });
        Schema::table('order_item_modifiers', function (Blueprint $table): void {
            $table->unsignedInteger('quantity')->default(1)->after('price_delta');
        });
    }

    public function down(): void
    {
        Schema::table('order_item_modifiers', fn (Blueprint $table) => $table->dropColumn('quantity'));
        Schema::table('product_modifier_group', fn (Blueprint $table) => $table->dropColumn(['is_required_override', 'min_selections_override', 'max_selections_override', 'allow_quantity_override']));
        Schema::table('modifier_options', fn (Blueprint $table) => $table->dropColumn(['cost_delta', 'is_active']));
        Schema::table('modifier_groups', fn (Blueprint $table) => $table->dropColumn(['group_type', 'allow_quantity']));
    }
};
