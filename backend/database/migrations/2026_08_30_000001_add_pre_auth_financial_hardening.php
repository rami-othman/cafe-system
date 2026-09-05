<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pos_number_counters', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('kind');
            $table->unsignedBigInteger('branch_scope_id')->default(0);
            $table->unsignedBigInteger('next_value')->default(0);
            $table->timestamps();
            $table->unique(['tenant_id', 'kind', 'branch_scope_id']);
        });

        // Preserve the old count-based visible sequence as the initial
        // high-water mark. New allocations never count business rows.
        $now = now();
        foreach (DB::table('orders')
            ->select('tenant_id', 'branch_id', DB::raw('count(*) as next_value'))
            ->groupBy('tenant_id', 'branch_id')
            ->orderBy('tenant_id')->orderBy('branch_id')->cursor() as $counter) {
            DB::table('pos_number_counters')->insert([
                'tenant_id' => $counter->tenant_id,
                'kind' => 'order',
                'branch_scope_id' => $counter->branch_id,
                'next_value' => $counter->next_value,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
        foreach (DB::table('payment_refunds')
            ->select('tenant_id', DB::raw('count(*) as next_value'))
            ->groupBy('tenant_id')->orderBy('tenant_id')->cursor() as $counter) {
            DB::table('pos_number_counters')->insert([
                'tenant_id' => $counter->tenant_id,
                'kind' => 'refund',
                'branch_scope_id' => 0,
                'next_value' => $counter->next_value,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        // Finance owns the tenant-scoped key. MAIN adds the lifecycle hash.
        if (! Schema::hasColumn('payments', 'idempotency_key')) {
            Schema::table('payments', fn (Blueprint $table) => $table->string('idempotency_key', 120)->nullable()->after('status'));
        }
        if (! Schema::hasColumn('payments', 'idempotency_hash')) {
            Schema::table('payments', fn (Blueprint $table) => $table->string('idempotency_hash', 64)->nullable()->after('idempotency_key'));
        }

        if (! Schema::hasColumn('payment_refunds', 'idempotency_key')) {
            Schema::table('payment_refunds', fn (Blueprint $table) => $table->string('idempotency_key', 120)->nullable()->after('status'));
        }
        if (! Schema::hasColumn('payment_refunds', 'idempotency_hash')) {
            Schema::table('payment_refunds', fn (Blueprint $table) => $table->string('idempotency_hash', 64)->nullable()->after('idempotency_key'));
        }
    }

    public function down(): void
    {
        Schema::table('payment_refunds', function (Blueprint $table): void {
            $table->dropColumn('idempotency_hash');
        });
        Schema::table('payments', function (Blueprint $table): void {
            $table->dropColumn('idempotency_hash');
        });
        Schema::dropIfExists('pos_number_counters');
    }
};
