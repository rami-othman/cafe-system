<?php

namespace Tests\Feature;

use App\Services\WhatsAppCloudService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ReceiptWhatsAppApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_phone_numbers_are_normalized_to_international_digits(): void
    {
        $this->assertSame('963933123456', WhatsAppCloudService::normalizePhone('0933 123 456'));
        $this->assertSame('963933123456', WhatsAppCloudService::normalizePhone('+963 933 123 456'));
        $this->assertSame('963933123456', WhatsAppCloudService::normalizePhone('00963933123456'));
        $this->assertSame('963933123456', WhatsAppCloudService::normalizePhone('٠٩٣٣١٢٣٤٥٦'));
        $this->assertSame('97455123456', WhatsAppCloudService::normalizePhone('+97455123456'));
        $this->assertNull(WhatsAppCloudService::normalizePhone('12'));
        $this->assertNull(WhatsAppCloudService::normalizePhone('abc'));
    }

    public function test_it_answers_not_configured_so_the_app_can_fall_back_to_manual(): void
    {
        $orderId = $this->paidOrderId();
        config(['services.whatsapp.token' => null, 'services.whatsapp.phone_number_id' => null]);
        Http::fake();

        $this->postJson("/api/v1/orders/{$orderId}/whatsapp", ['phone' => '0933123456', 'image' => $this->png()])
            ->assertStatus(503)
            ->assertJsonPath('code', 'whatsapp_not_configured');

        Http::assertNothingSent();
    }

    public function test_it_uploads_the_image_sends_it_and_records_the_job(): void
    {
        $orderId = $this->paidOrderId();
        config(['services.whatsapp.token' => 'test-token', 'services.whatsapp.phone_number_id' => '555', 'services.whatsapp.template' => null]);
        Http::fake([
            'graph.facebook.com/*/media' => Http::response(['id' => 'MEDIA1']),
            'graph.facebook.com/*/messages' => Http::response(['messages' => [['id' => 'wamid.TEST']]]),
        ]);

        $this->postJson("/api/v1/orders/{$orderId}/whatsapp", ['phone' => '0933123456', 'image' => $this->png()])
            ->assertOk()
            ->assertJsonPath('data.status', 'completed')
            ->assertJsonPath('data.messageId', 'wamid.TEST');

        Http::assertSent(fn ($request) => str_ends_with($request->url(), '/555/messages')
            && $request['to'] === '963933123456'
            && $request['type'] === 'image'
            && $request['image']['id'] === 'MEDIA1');
        $this->assertDatabaseHas('print_jobs', ['order_id' => $orderId, 'channel' => 'whatsapp', 'status' => 'completed']);
    }

    public function test_it_records_a_failed_job_when_whatsapp_rejects_the_message(): void
    {
        $orderId = $this->paidOrderId();
        config(['services.whatsapp.token' => 'test-token', 'services.whatsapp.phone_number_id' => '555', 'services.whatsapp.template' => null]);
        Http::fake([
            'graph.facebook.com/*/media' => Http::response(['id' => 'MEDIA1']),
            'graph.facebook.com/*/messages' => Http::response(['error' => ['message' => 'Re-engagement message']], 400),
        ]);

        $this->postJson("/api/v1/orders/{$orderId}/whatsapp", ['phone' => '0933123456', 'image' => $this->png()])
            ->assertStatus(502)
            ->assertJsonPath('code', 'whatsapp_failed');

        $this->assertDatabaseHas('print_jobs', ['order_id' => $orderId, 'channel' => 'whatsapp', 'status' => 'failed', 'failure_code' => 'whatsapp_failed']);
    }

    public function test_it_rejects_an_invalid_phone_number(): void
    {
        $orderId = $this->paidOrderId();
        config(['services.whatsapp.token' => 'test-token', 'services.whatsapp.phone_number_id' => '555']);
        Http::fake();

        $this->postJson("/api/v1/orders/{$orderId}/whatsapp", ['phone' => '12', 'image' => $this->png()])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('phone');

        Http::assertNothingSent();
    }

    private function png(): UploadedFile
    {
        // 1x1 PNG; UploadedFile::fake()->image() needs GD, which the image lacks.
        return UploadedFile::fake()->createWithContent('invoice.png', base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));
    }

    private function paidOrderId(): int
    {
        $this->seed();
        $branchId = DB::table('branches')->where('name', 'Downtown')->value('id');
        $productId = DB::table('products')->where('name', 'Cappuccino')->value('id');
        $tenantId = DB::table('branches')->where('id', $branchId)->value('tenant_id');

        $shiftId = $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => 0], ['X-Tenant-Id' => (string) $tenantId])
            ->assertCreated()->json('data.id');

        $modifiers = DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->join('modifier_options', 'modifier_options.modifier_group_id', '=', 'modifier_groups.id')
            ->where('product_modifier_group.product_id', $productId)
            ->where('modifier_groups.is_required', true)
            ->where('modifier_options.is_default', true)
            ->select(['modifier_groups.id as groupId', 'modifier_options.id as optionId'])
            ->get()
            ->map(fn ($modifier) => ['groupId' => $modifier->groupId, 'optionId' => $modifier->optionId])
            ->all();
        DB::table('modifier_options')->whereIn('id', collect($modifiers)->pluck('optionId'))->update(['price_delta' => 0]);

        $orderId = $this->postJson('/api/v1/orders', [
            'branchId' => $branchId,
            'shiftId' => $shiftId,
            'orderType' => 'dine_in',
            'tableId' => DB::table('cafe_tables')->where('branch_id', $branchId)->value('id'),
            'items' => [['productId' => $productId, 'quantity' => 1, 'modifiers' => $modifiers]],
        ])->assertCreated()->json('data.id');

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => 30, 'idempotencyKey' => 'wa-test-payment'])
            ->assertOk();

        return (int) $orderId;
    }
}
