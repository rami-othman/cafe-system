<?php

namespace Tests\Feature;

use App\Services\AccountingPostingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class JournalEntryUserNamesTest extends TestCase
{
    use RefreshDatabase;

    public function test_journal_entry_shows_creator_and_poster_names_not_only_ids(): void
    {
        $this->seed();
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        DB::table('api_tokens')->insert([
            'tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'names-test',
            'token_hash' => hash('sha256', 'names-token'), 'expires_at' => now()->addDay(),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $headers = ['Authorization' => 'Bearer names-token', 'X-Tenant-Id' => $tenant];
        $entry = app(AccountingPostingService::class)->post(Request::create('/x', 'POST'), $tenant, [
            'sourceType' => 'manual', 'sourceId' => 1, 'sourceEvent' => 'TEST', 'entryDate' => now()->toDateString(),
            'description' => 'اختبار', 'lines' => [['accountCode' => '1010', 'debit' => '5.00'], ['accountCode' => '4000', 'credit' => '5.00']],
        ], $owner);
        $name = DB::table('users')->where('id', $owner)->value('name');

        $this->getJson('/api/v1/finance/journal-entries/'.$entry, $headers)->assertOk()
            ->assertJsonPath('data.createdBy', $owner)->assertJsonPath('data.createdByName', $name)
            ->assertJsonPath('data.postedByName', $name);
    }

    public function test_automatic_sale_entry_hides_cost_and_inventory_lines_and_totals_follow(): void
    {
        $this->seed();
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        DB::table('api_tokens')->insert([
            'tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'hide-test',
            'token_hash' => hash('sha256', 'hide-token'), 'expires_at' => now()->addDay(),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $headers = ['Authorization' => 'Bearer hide-token', 'X-Tenant-Id' => $tenant];
        $entry = app(AccountingPostingService::class)->post(Request::create('/x', 'POST'), $tenant, [
            'sourceType' => 'pos_order', 'sourceId' => 9001, 'sourceEvent' => 'POS_ORDER_PAID', 'entryDate' => now()->toDateString(),
            'description' => 'بيع', 'lines' => [
                ['accountCode' => '1010', 'debit' => '10.00'], ['accountCode' => '4000', 'credit' => '10.00'],
                ['accountCode' => '5000', 'debit' => '4.00'], ['accountCode' => '1100', 'credit' => '4.00'],
            ],
        ], $owner);

        $response = $this->getJson('/api/v1/finance/journal-entries/'.$entry, $headers)->assertOk()
            ->assertJsonPath('data.debitTotal', '10.00')->assertJsonPath('data.creditTotal', '10.00');
        $codes = collect($response->json('data.lines'))->pluck('accountCode')->all();
        $this->assertSame(['1010', '4000'], $codes);
        $this->assertSame(4, DB::table('journal_entry_lines')->where('journal_entry_id', $entry)->count());
    }
}
