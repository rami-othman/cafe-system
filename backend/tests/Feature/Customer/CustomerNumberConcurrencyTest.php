<?php

namespace Tests\Feature\Customer;

use App\Domain\Customer\CustomerNumberGenerator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerNumberConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_numbers_are_padded_grow_beyond_six_digits_and_are_independent_per_tenant(): void
    {
        $tenantOne = $this->tenant('number-one');
        $tenantTwo = $this->tenant('number-two');
        $generator = app(CustomerNumberGenerator::class);

        DB::transaction(function () use ($generator, $tenantOne, $tenantTwo): void {
            $this->assertSame('C-000001', $generator->next($tenantOne));
            $this->assertSame('C-000001', $generator->next($tenantTwo));
        });

        DB::table('customers')->insert([
            'tenant_id' => $tenantOne, 'name' => 'High', 'customer_number' => 'C-999999', 'normalized_name' => 'high',
            'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::transaction(fn () => $this->assertSame('C-1000000', $generator->next($tenantOne)));
    }

    public function test_archived_numbers_are_not_reused_and_counter_is_high_water_safe(): void
    {
        $tenant = $this->tenant('number-archive');
        DB::table('customers')->insert([
            'tenant_id' => $tenant, 'name' => 'Archived', 'customer_number' => 'C-000042', 'normalized_name' => 'archived',
            'is_active' => false, 'deleted_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);

        DB::transaction(function () use ($tenant): void {
            $this->assertSame('C-000043', app(CustomerNumberGenerator::class)->next($tenant));
        });
    }

    private function tenant(string $slug): int
    {
        return (int) DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug.'-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
    }
}
