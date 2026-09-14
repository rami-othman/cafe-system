<?php

namespace Tests\Feature\Customer;

use App\Domain\Customer\CustomerDomainException;
use App\Domain\Customer\CustomerOperationalEligibility;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\TestCase;

class CustomerOrderEligibilityTest extends TestCase
{
    use DatabaseMigrations;

    public function test_only_active_non_archived_same_tenant_customers_are_eligible_and_null_is_allowed(): void
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Eligibility', 'slug' => 'eligibility-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $active = $this->customer($tenant, true, null);
        $inactive = $this->customer($tenant, false, null);
        $archived = $this->customer($tenant, false, now());
        $service = app(CustomerOperationalEligibility::class);

        $service->assert($tenant, null);
        $service->assert($tenant, $active);
        foreach ([$inactive, $archived, 999999] as $id) {
            try {
                $service->assert($tenant, $id);
                $this->fail('Expected ineligible customer exception.');
            } catch (CustomerDomainException $exception) {
                $this->assertSame('CUSTOMER_NOT_OPERATIONALLY_ELIGIBLE', $exception->domainCode);
            }
        }
    }

    public function test_archive_and_attachment_race_serializes_without_partial_order_effects(): void
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Eligibility Race', 'slug' => 'eligibility-race-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'timezone' => 'Asia/Damascus', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $customer = $this->customer($tenant, true, null);
        $order = DB::table('orders')->insertGetId([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'order_number' => 'ELIGIBILITY-RACE-'.uniqid(),
            'type' => 'takeaway',
            'status' => 'draft',
            'payment_status' => 'unpaid',
            'subtotal' => 10,
            'tax_rate' => 0,
            'total' => 10,
            'opened_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $barrier = random_int(1, PHP_INT_MAX);
        DB::select('select pg_advisory_lock(?)', [$barrier]);
        $workers = [];

        try {
            foreach (['archive', 'attach'] as $mode) {
                $payload = base64_encode(json_encode([
                    'tenantId' => $tenant,
                    'customerId' => $customer,
                    'orderId' => $order,
                    'mode' => $mode,
                    'barrier' => $barrier,
                ], JSON_THROW_ON_ERROR));
                $pipes = [];
                $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/ConcurrentCustomerEligibilityWorker.php'), $payload], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path());
                if (! is_resource($process)) {
                    throw new RuntimeException('Could not start concurrent customer worker.');
                }
                $workers[] = compact('process', 'pipes');
            }

            $this->waitForBarrierWorkers(2, $workers);
            DB::select('select pg_advisory_unlock(?)', [$barrier]);
            $barrier = null;
            $results = array_map(function (array $worker): array {
                $stdout = stream_get_contents($worker['pipes'][1]);
                $stderr = stream_get_contents($worker['pipes'][2]);
                fclose($worker['pipes'][1]);
                fclose($worker['pipes'][2]);
                $exit = proc_close($worker['process']);
                $result = json_decode($stdout, true);
                if (! is_array($result)) {
                    throw new RuntimeException("Concurrent customer worker did not return JSON (exit {$exit}): {$stderr}");
                }

                return $result;
            }, $workers);
        } finally {
            if ($barrier !== null) {
                DB::select('select pg_advisory_unlock(?)', [$barrier]);
            }
            foreach ($workers as $worker) {
                if (is_resource($worker['process'])) {
                    proc_terminate($worker['process']);
                }
            }
        }

        $attachment = collect($results)->first(fn (array $result): bool => ($result['result']['action'] ?? null) === 'attached' || ($result['code'] ?? null) === 'CUSTOMER_NOT_OPERATIONALLY_ELIGIBLE');
        $this->assertIsArray($attachment, json_encode($results, JSON_THROW_ON_ERROR));
        $this->assertSame(1, DB::table('orders')->where('id', $order)->count());

        if (($attachment['ok'] ?? false) === true) {
            $this->assertTrue($attachment['result']['attached']);
            $this->assertTrue($attachment['result']['eligibleAtCommit']);
            $this->assertSame($customer, (int) DB::table('orders')->where('id', $order)->value('customer_id'));
        } else {
            $this->assertSame('CUSTOMER_NOT_OPERATIONALLY_ELIGIBLE', $attachment['code']);
            $this->assertNull(DB::table('orders')->where('id', $order)->value('customer_id'));
        }
    }

    private function waitForBarrierWorkers(int $expected, array $workers): void
    {
        $deadline = microtime(true) + 30;
        do {
            $waiting = (int) DB::selectOne("select count(*) as count from pg_locks where locktype = 'advisory' and granted = false")->count;
            if ($waiting >= $expected) {
                return;
            }
            usleep(10_000);
        } while (microtime(true) < $deadline);

        $diagnostics = array_map(function (array $worker): array {
            stream_set_blocking($worker['pipes'][2], false);

            return [
                'status' => proc_get_status($worker['process']),
                'stderr' => stream_get_contents($worker['pipes'][2]),
            ];
        }, $workers);
        throw new RuntimeException("Only {$waiting} of {$expected} customer workers reached the PostgreSQL start barrier: ".json_encode($diagnostics, JSON_THROW_ON_ERROR));
    }

    private function customer(int $tenant, bool $active, $deletedAt): int
    {
        return (int) DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => uniqid('customer'), 'customer_number' => 'C-'.str_pad((string) random_int(1, 999999), 6, '0', STR_PAD_LEFT), 'normalized_name' => 'customer', 'is_active' => $active, 'deleted_at' => $deletedAt, 'created_at' => now(), 'updated_at' => now()]);
    }
}
