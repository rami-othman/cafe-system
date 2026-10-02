<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FinancialAccountAutoCodeTest extends TestCase
{
    use RefreshDatabase;

    public function test_blank_or_duplicate_code_is_replaced_by_the_next_free_code_under_the_parent(): void
    {
        $this->seed();
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        DB::table('api_tokens')->insert([
            'tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'auto-code',
            'token_hash' => hash('sha256', 'auto-code-token'), 'expires_at' => now()->addDay(),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $h = ['Authorization' => 'Bearer auto-code-token', 'X-Tenant-Id' => $tenant];
        $parent = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->first();
        $this->assertNotNull($parent);
        $body = fn (array $o = []) => array_merge([
            'nameAr' => 'حساب تجريبي', 'nameEn' => 'Test', 'parentAccountId' => $parent->id, 'isActive' => true,
        ], $o);

        $first = $this->postJson('/api/v1/finance/accounts', $body(['code' => '']), $h)->assertCreated()->json('data.code');
        $second = $this->postJson('/api/v1/finance/accounts', $body(['code' => $first]), $h)->assertCreated()->json('data.code');
        $third = $this->postJson('/api/v1/finance/accounts', $body(), $h)->assertCreated()->json('data.code');
        $custom = $this->postJson('/api/v1/finance/accounts', $body(['code' => 'zz9']), $h)->assertCreated()->json('data.code');

        $this->assertNotSame($first, $second);
        $this->assertNotSame($second, $third);
        $this->assertSame('ZZ9', $custom, 'a free typed code is kept');
        $this->assertSame(4, count(array_unique([$first, $second, $third, $custom])));
    }
}
