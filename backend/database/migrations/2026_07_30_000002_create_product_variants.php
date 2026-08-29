<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_variants', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('product_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->string('sku')->nullable();
            $table->string('barcode')->nullable();
            $table->decimal('base_price', 12, 2)->default(0);
            $table->decimal('cost_price', 12, 2)->default(0);
            $table->boolean('is_default')->default(false);
            $table->boolean('is_active')->default(true);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
            $table->softDeletes();
            $table->index(['tenant_id', 'product_id']);
            $table->index(['tenant_id', 'product_id', 'is_active']);
            $table->index(['tenant_id', 'product_id', 'is_default']);
            $table->unique(['tenant_id', 'sku']);
            $table->unique(['tenant_id', 'barcode']);
        });

        DB::table('products')->orderBy('id')->chunkById(500, function ($products): void {
            $now = now();
            $rows = [];
            foreach ($products as $product) {
                $exists = DB::table('product_variants')->where('product_id', $product->id)->exists();
                if (! $exists) {
                    $rows[] = ['tenant_id' => $product->tenant_id, 'product_id' => $product->id, 'name' => 'Regular', 'sku' => $product->sku, 'barcode' => $product->barcode, 'base_price' => $product->price, 'cost_price' => $product->cost_price, 'is_default' => true, 'is_active' => $product->is_active, 'sort_order' => 0, 'created_at' => $now, 'updated_at' => $now];
                }
            }
            if ($rows !== []) {
                DB::table('product_variants')->insert($rows);
            }
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_variants');
    }
};
