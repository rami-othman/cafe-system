<?php

use App\Domain\Customer\CustomerNameNormalizer;
use App\Domain\Customer\CustomerPhoneNormalizer;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $nextByTenant = [];

        DB::table('customers')->orderBy('tenant_id')->orderBy('id')->get()->each(function (object $customer) use (&$nextByTenant): void {
            $tenantId = (int) $customer->tenant_id;
            $nextByTenant[$tenantId] ??= $this->nextSequenceForTenant($tenantId);

            $updates = ['updated_at' => now()];
            if ($customer->customer_number === null) {
                $updates['customer_number'] = $this->formatNumber($nextByTenant[$tenantId]++);
            }
            if ($customer->normalized_name === null) {
                $updates['normalized_name'] = CustomerNameNormalizer::normalize($customer->name)['normalizedName'];
            }
            if (count($updates) > 1) {
                DB::table('customers')->where('id', $customer->id)->update($updates);
            }

            if ($customer->phone !== null && ! DB::table('customer_phones')->where('customer_id', $customer->id)->exists()) {
                $phone = CustomerPhoneNormalizer::normalize($customer->phone);
                DB::table('customer_phones')->insert([
                    'tenant_id' => $tenantId,
                    'customer_id' => $customer->id,
                    'raw_number' => $phone['rawNumber'],
                    'normalized_number' => $phone['normalizedNumber'],
                    'type' => 'mobile',
                    'is_primary' => true,
                    'validation_status' => $phone['validationStatus'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        });

        foreach ($nextByTenant as $tenantId => $nextValue) {
            $max = DB::table('customers')->where('tenant_id', $tenantId)->pluck('customer_number')->map(fn (?string $number): int => (int) preg_replace('/\D+/', '', (string) $number))->max() ?? 0;
            DB::table('customer_number_counters')->updateOrInsert(
                ['tenant_id' => $tenantId],
                ['next_value' => max($nextValue, $max + 1), 'created_at' => now(), 'updated_at' => now()],
            );
        }

        $this->assertInvariants();
        if (Schema::hasColumn('customers', 'customer_number')) {
            DB::statement('ALTER TABLE customers ALTER COLUMN customer_number SET NOT NULL');
        }
        if (Schema::hasColumn('customers', 'normalized_name')) {
            DB::statement('ALTER TABLE customers ALTER COLUMN normalized_name SET NOT NULL');
        }
        if (! $this->indexExists('customers_tenant_customer_number_unique')) {
            DB::statement('CREATE UNIQUE INDEX customers_tenant_customer_number_unique ON customers (tenant_id, customer_number)');
        }
        if (! $this->indexExists('customer_phones_one_primary_unique')) {
            DB::statement('CREATE UNIQUE INDEX customer_phones_one_primary_unique ON customer_phones (customer_id) WHERE is_primary = true');
        }
    }

    public function down(): void
    {
        // Customer writes are additive and may exist in production; rollback is roll-forward.
    }

    private function nextSequenceForTenant(int $tenantId): int
    {
        $numbers = DB::table('customers')->where('tenant_id', $tenantId)->pluck('customer_number');

        return (($numbers->map(fn (?string $number): int => (int) preg_replace('/\D+/', '', (string) $number))->max() ?? 0) + 1);
    }

    private function formatNumber(int $sequence): string
    {
        return 'C-'.str_pad((string) $sequence, 6, '0', STR_PAD_LEFT);
    }

    private function assertInvariants(): void
    {
        if (DB::table('customers')->whereNull('customer_number')->exists() || DB::table('customers')->whereNull('normalized_name')->exists()) {
            throw new RuntimeException('Customer foundation backfill left required identity fields null.');
        }
        $duplicate = DB::table('customers')->select('tenant_id', 'customer_number')->groupBy('tenant_id', 'customer_number')->havingRaw('COUNT(*) > 1')->exists();
        if ($duplicate) {
            throw new RuntimeException('Customer foundation backfill found duplicate customer numbers.');
        }
        $multiplePrimaries = DB::table('customer_phones')->select('customer_id')->where('is_primary', true)->groupBy('customer_id')->havingRaw('COUNT(*) > 1')->exists();
        if ($multiplePrimaries) {
            throw new RuntimeException('Customer foundation backfill found multiple primary phones.');
        }
    }

    private function indexExists(string $name): bool
    {
        return DB::table('pg_indexes')->where('indexname', $name)->exists();
    }
};
