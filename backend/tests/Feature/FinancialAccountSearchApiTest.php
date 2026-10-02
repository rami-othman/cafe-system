<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FinancialAccountSearchApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_chart_search_forgives_spelling_variants_typos_and_matches_the_parent_path(): void
    {
        $this->seed();
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        DB::table('api_tokens')->insert([
            'tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'search-test',
            'token_hash' => hash('sha256', 'account-search-token'), 'expires_at' => now()->addDay(),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $headers = ['Authorization' => 'Bearer account-search-token', 'X-Tenant-Id' => $tenant];
        $this->artisan('finance:import-phinix-accounts', ['tenantId' => $tenant, '--apply' => true])->assertExitCode(0);

        $names = fn (string $term): array => collect(
            $this->getJson('/api/v1/finance/accounts?perPage=50&search='.rawurlencode($term), $headers)->assertOk()->json('data'),
        )->pluck('nameAr')->all();

        $exactTerm = $names('الأجهزة الإلكترونية');
        $this->assertNotEmpty($exactTerm);
        $this->assertSame($exactTerm, $names('الاجهزة الالكتزو'), 'typo + missing hamza finds the same accounts');
        $this->assertSame($exactTerm[0], $names('اجهزه الكترونيه')[0]);
        $this->assertContains('محمصة ارت للبن المختص', $names('محمصه ارت'));
        $this->assertContains('محمصة ارت للبن المختص', $names('موردين ارت'), 'ancestor names are searchable');
        $this->assertSame([], $names('zzzz غير موجود'));
        $this->getJson('/api/v1/finance/accounts?search=22321', $headers)->assertOk()->assertJsonPath('data.0.code', '22321');
    }
}
