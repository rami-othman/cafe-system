<?php

namespace App\Services;

use App\Domain\Discount\DiscountAccess;
use App\Exceptions\OrderLifecycleException;
use App\Support\SalePaymentMethodResolver;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

final class DiscountEngineProtocol
{
    public const VERSION = 2;

    public function __construct(private readonly DiscountResolutionService $engine, private readonly DiscountSettingsService $settings, private readonly DiscountAccess $access, private readonly OperationalAuditService $audit) {}

    public function capabilities(int $tenantId, ?Request $request = null): array
    {
        $settings = $this->settings->read($tenantId);

        return ['contractVersion' => self::VERSION, 'engineReady' => false, 'automaticPolicyCreationAvailable' => $this->engine->isolatedAutomatic(), 'automaticEnabled' => $this->engine->automatic($tenantId), 'settingsVersion' => $settings['version'], 'supportsDiscountReview' => true, 'supportsPaymentQuote' => true, 'supportsMultipleDiscounts' => true, 'maximumRequestedDiscounts' => DiscountResolutionService::MAX_REQUESTED_INTENTS, 'policy' => DiscountSettingsService::effectivePolicy($settings), 'requiresPaymentQuote' => $request?->header('X-Discount-Contract') === '2' || $this->engine->requiresContract($tenantId), 'canSuppressAutomatic' => $request !== null && $settings['allowAutomaticSuppression'] && $this->access->allows($request, DiscountAccess::SUPPRESS_AUTOMATIC)];
    }

    public function compatible(Request $request, int $tenantId, ?int $orderId = null, bool $required = false): void
    {
        $new = $request->header('X-Discount-Contract') === (string) self::VERSION;
        $unsupported = $required || $this->engine->requiresContract($tenantId)
            || ($orderId !== null && $this->engine->active($tenantId, $orderId));
        if ($unsupported && ! $new) {
            throw new OrderLifecycleException('DISCOUNT_CLIENT_UPDATE_REQUIRED', 'Update the client to review discounts and payment quotes.');
        }
    }

    public function legacyMutation(Request $request, int $tenantId, int $orderId): void
    {
        $this->compatible($request, $tenantId, $orderId);
        if ($this->engine->active($tenantId, $orderId)) {
            throw new OrderLifecycleException('DISCOUNT_REVIEW_REQUIRED', 'Preview this change before applying it.');
        }
    }

    public function method(int $tenantId, array $data): ?object
    {
        if (($data['paymentMethodId'] ?? null) === null) {
            return null;
        }
        if (! DB::table('payment_methods as pm')->join('financial_accounts as a', 'a.id', '=', 'pm.financial_account_id')
            ->where('pm.tenant_id', $tenantId)->where('pm.id', (int) $data['paymentMethodId'])->where('a.tenant_id', $tenantId)->exists()) {
            throw new OrderLifecycleException('PAYMENT_METHOD_INVALID', 'Review the active payment methods.');
        }
        try {
            $method = SalePaymentMethodResolver::resolveExplicit($tenantId, (int) $data['paymentMethodId']);
        } catch (ValidationException) {
            throw new OrderLifecycleException('PAYMENT_METHOD_INVALID', 'Review the active payment methods.');
        }
        if (! in_array($method->type, ['cash', 'card'], true)) {
            throw new OrderLifecycleException('PAYMENT_METHOD_INVALID', 'Review the active payment methods.');
        }

        return $method;
    }

    /**
     * Normalize secret coupon text to policy identity before any storage.
     *
     * $retainedCodes: coupon discount ids already saved as explicit intents on
     * this order. A full `set` list may keep such a coupon by `discountId`, since
     * the coupon text is never stored or returned; a new coupon still needs its
     * code, so a policy id alone can never redeem a coupon.
     */
    private function explicit(Request $request, int $tenantId, array $input, array $retainedCodes = []): array
    {
        $source = $input['source'];
        if ($source === 'ad_hoc') {
            throw new OrderLifecycleException('DISCOUNT_AD_HOC_DISABLED', 'Choose an existing eligible discount policy.');
        }
        $retained = $source === 'code' && ! array_key_exists('code', $input) && array_key_exists('discountId', $input);
        $allowed = match ($source) {
            'code' => $retained ? ['source', 'discountId'] : ['source', 'code'],
            'configured_manual' => ['source', 'discountId'],
        };
        if (array_diff(array_keys($input), $allowed) !== []) {
            throw ValidationException::withMessages(['intent' => 'Specify exactly one explicit discount intent.']);
        }
        $this->access->authorize($request, DiscountAccess::APPLY_CONFIGURED);
        if ($retained && ! in_array((int) $input['discountId'], $retainedCodes, true)) {
            throw new OrderLifecycleException('DISCOUNT_NOT_FOUND', 'Enter the coupon code again.');
        }
        $query = DB::table('discounts')->where('tenant_id', $tenantId)->whereNull('deleted_at');
        $policy = $source === 'code'
            ? ($retained ? $query->where('application_mode', 'code')->where('id', (int) $input['discountId'])->first()
                : $query->where('application_mode', 'code')->whereRaw('lower(code) = ?', [strtolower(trim((string) ($input['code'] ?? '')))])->first())
            : $query->where('application_mode', 'manual')->where('id', $input['discountId'] ?? 0)->first();
        if (! $policy) {
            throw new OrderLifecycleException('DISCOUNT_NOT_FOUND', 'The selected discount is unavailable.');
        }

        return ['source' => $source, 'discountId' => (int) $policy->id];
    }

    private function authorizeChange(Request $request, int $tenantId, array $change): void
    {
        if (in_array($change['action'], ['suppress', 'undo'], true)) {
            if (! $this->access->allows($request, DiscountAccess::SUPPRESS_AUTOMATIC)) {
                throw new OrderLifecycleException('DISCOUNT_SUPPRESSION_FORBIDDEN', 'Automatic suppression requires an authorized manager.');
            }
            if (! $this->settings->read($tenantId)['allowAutomaticSuppression']) {
                throw new OrderLifecycleException('DISCOUNT_SUPPRESSION_DISABLED', 'Automatic suppression is disabled.');
            }
            if (! DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $change['discountId'])->where('application_mode', 'automatic')->whereNull('deleted_at')->exists()) {
                throw new OrderLifecycleException('DISCOUNT_NOT_FOUND', 'The selected automatic discount is unavailable.');
            }
        } else {
            $source = $change['intent']['source'] ?? null;
            // Outstanding pre-removal reviews must not create a new free discount.
            // Removing a saved legacy intent remains available to configured users.
            if ($change['action'] === 'apply' && $source === 'ad_hoc') {
                throw new OrderLifecycleException('DISCOUNT_AD_HOC_DISABLED', 'Choose an existing eligible discount policy.');
            }
            $this->access->authorize($request, DiscountAccess::APPLY_CONFIGURED);
        }
    }

    private function calculate(int $tenantId, object $order, array $change): array
    {
        $intent = match ($change['action']) {
            'apply' => $change['intent'],
            'set' => $change['intents'],
            'remove' => null,
            default => $this->engine->intent($tenantId, (int) $order->id),
        };
        $suppressed = DB::table('order_discount_suppressions')->where('tenant_id', $tenantId)->where('order_id', $order->id)->pluck('discount_id')->map(fn ($id) => (int) $id)->all();
        if ($change['action'] === 'suppress') {
            $suppressed[] = $change['discountId'];
        } elseif ($change['action'] === 'undo') {
            $suppressed = array_values(array_diff($suppressed, [$change['discountId']]));
        }
        sort($suppressed);

        return $this->engine->resolve($tenantId, $order, $intent, $this->method($tenantId, $change), suppressionOverride: array_values(array_unique($suppressed)));
    }

    public function preview(Request $request, int $tenantId, object $order, array $data): array
    {
        $this->engine->lock($tenantId);
        $change = ['action' => $data['action'], 'paymentMethodId' => $data['paymentMethodId'] ?? null];
        if ($change['action'] === 'apply') {
            $change['intent'] = $this->explicit($request, $tenantId, $data['intent']);
        } elseif ($change['action'] === 'set') {
            // One reviewed, ordered set that replaces every explicit intent. The
            // client sends intent only; the server resolves eligibility and money.
            $retainedCodes = [];
            foreach ($this->engine->intents($this->engine->intent($tenantId, (int) $order->id)) as $saved) {
                if (($saved['source'] ?? null) === 'code' && isset($saved['discountId'])) {
                    $retainedCodes[] = (int) $saved['discountId'];
                }
            }
            $change['intents'] = array_map(fn (array $one): array => $this->explicit($request, $tenantId, $one, $retainedCodes), $data['intents']);
            if (count(array_unique(array_column($change['intents'], 'discountId'))) !== count($change['intents'])) {
                throw new OrderLifecycleException('DISCOUNT_DUPLICATE_INTENT', 'Each discount can be requested only once.');
            }
        } elseif (in_array($change['action'], ['suppress', 'undo'], true)) {
            $change['discountId'] = (int) $data['discountId'];
            $change['reason'] = trim($data['reason'] ?? '');
            if ($change['action'] === 'suppress' && $change['reason'] === '') {
                throw ValidationException::withMessages(['reason' => 'A reason is required.']);
            }
        } elseif ($change['action'] === 'remove') {
            $change['intent'] = $this->engine->intent($tenantId, (int) $order->id);
        }
        $this->authorizeChange($request, $tenantId, $change);
        $result = $this->calculate($tenantId, $order, $change);
        $before = $this->state($tenantId, $order);
        $result += ['reviewId' => (string) Str::uuid(), 'before' => $before['totals'], 'after' => $result['totals'], 'removals' => $before['discounts'], 'additions' => $result['discounts']];
        DB::table('discount_reviews')->insert(['tenant_id' => $tenantId, 'order_id' => $order->id, 'identity' => $result['reviewId'], 'fingerprint' => $result['fingerprint'], 'payload' => json_encode($change), 'result' => json_encode($result), 'created_at' => now(), 'updated_at' => now()]);

        return $result;
    }

    public function apply(Request $request, int $tenantId, object $order, array $data): array
    {
        $hash = hash('sha256', json_encode(['orderId' => (int) $order->id, 'reviewId' => $data['reviewId']], JSON_THROW_ON_ERROR));
        $existing = DB::table('discount_operations')->where('tenant_id', $tenantId)->where('identity', $data['operationId'])->first();
        if ($existing) {
            if ((int) $existing->order_id !== (int) $order->id || ! hash_equals($existing->fingerprint, $hash)) {
                throw new OrderLifecycleException('DISCOUNT_OPERATION_CONFLICT', 'This operation identity belongs to another request.');
            }

            return json_decode($existing->result, true, flags: JSON_THROW_ON_ERROR);
        }
        app(OrderLifecyclePolicy::class)->assertDiscountable($order);
        $this->engine->lock($tenantId);
        // Identity is tenant-wide, including requests against different orders.
        DB::select('select pg_advisory_xact_lock(hashtextextended(?, 20404))', [$tenantId.':'.$data['operationId']]);
        $existing = DB::table('discount_operations')->where('tenant_id', $tenantId)->where('identity', $data['operationId'])->first();
        if ($existing) {
            if (! hash_equals($existing->fingerprint, $hash)) {
                throw new OrderLifecycleException('DISCOUNT_OPERATION_CONFLICT', 'This operation identity belongs to another request.');
            }

            return json_decode($existing->result, true, flags: JSON_THROW_ON_ERROR);
        }
        $review = DB::table('discount_reviews')->where('tenant_id', $tenantId)->where('order_id', $order->id)->where('identity', $data['reviewId'])->first();
        if (! $review || now()->diffInSeconds($review->created_at, true) > 300) {
            throw new OrderLifecycleException('DISCOUNT_REVIEW_REQUIRED', 'Create a fresh discount preview.');
        }
        $change = json_decode($review->payload, true, flags: JSON_THROW_ON_ERROR);
        $this->authorizeChange($request, $tenantId, $change);
        $result = $this->calculate($tenantId, $order, $change);
        if (! hash_equals($review->fingerprint, $result['fingerprint'])) {
            throw new OrderLifecycleException('DISCOUNT_REVIEW_STALE', 'Order or discount context changed. Review again.');
        }
        if (in_array($change['action'], ['apply', 'remove', 'set'], true)) {
            $stored = match ($change['action']) {
                'remove' => null,
                'apply' => $change['intent'],
                // Excluded requests are not retained: the reviewed result is what is saved.
                'set' => array_map(fn (array $d): array => ['discountId' => $d['discountId'], 'source' => $d['source']], $result['discounts']),
            };
            DB::table('order_discount_intents')->updateOrInsert(['tenant_id' => $tenantId, 'order_id' => $order->id], ['intent' => json_encode($stored), 'created_at' => now(), 'updated_at' => now()]);
        } elseif ($change['action'] === 'suppress') {
            DB::table('order_discount_suppressions')->updateOrInsert(['tenant_id' => $tenantId, 'order_id' => $order->id, 'discount_id' => $change['discountId']], ['suppressed_by' => (int) $request->attributes->get('auth_user')->id, 'reason' => $change['reason'], 'created_at' => now(), 'updated_at' => now()]);
        } elseif ($change['action'] === 'undo') {
            DB::table('order_discount_suppressions')->where('tenant_id', $tenantId)->where('order_id', $order->id)->where('discount_id', $change['discountId'])->delete();
        }
        $this->engine->persist($tenantId, $order, $result);
        $after = $this->state($tenantId, DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order->id)->first());
        $after['operationId'] = $data['operationId'];
        $this->audit->record($request, $tenantId, 'discount.engine.'.$change['action'], 'order', (int) $order->id, [], ['operationId' => $data['operationId'], 'discountId' => $change['discountId'] ?? ($change['intent']['discountId'] ?? null), 'discountIds' => array_column($result['discounts'], 'discountId'), 'reason' => $change['reason'] ?? null], branchId: (int) $order->branch_id, actorId: (int) $request->attributes->get('auth_user')->id);
        DB::table('discount_operations')->insert(['tenant_id' => $tenantId, 'order_id' => $order->id, 'identity' => $data['operationId'], 'fingerprint' => $hash, 'payload' => json_encode(['reviewId' => $data['reviewId']]), 'result' => json_encode($after), 'created_at' => now(), 'updated_at' => now()]);

        return json_decode(DB::table('discount_operations')->where('tenant_id', $tenantId)->where('identity', $data['operationId'])->value('result'), true, flags: JSON_THROW_ON_ERROR);
    }

    public function quote(Request $request, int $tenantId, object $order, array $data): array
    {
        $this->engine->lock($tenantId);
        $method = $this->method($tenantId, $data);
        $result = $this->engine->resolve($tenantId, $order, $this->engine->intent($tenantId, (int) $order->id), $method);
        $result += ['quoteId' => (string) Str::uuid(), 'paymentMethodId' => $method?->paymentMethodId, 'method' => $method?->type, 'expiresInSeconds' => 300];
        DB::table('discount_payment_quotes')->insert(['tenant_id' => $tenantId, 'order_id' => $order->id, 'identity' => $result['quoteId'], 'fingerprint' => $result['fingerprint'], 'payload' => json_encode(['paymentMethodId' => $method?->paymentMethodId]), 'result' => json_encode($result), 'created_at' => now(), 'updated_at' => now()]);

        return $result;
    }

    public function confirmQuote(int $tenantId, object $order, array $data): array
    {
        $this->engine->lock($tenantId);
        $quote = DB::table('discount_payment_quotes')->where('tenant_id', $tenantId)->where('order_id', $order->id)->where('identity', $data['quoteId'] ?? '')->first();
        if (! $quote || now()->diffInSeconds($quote->created_at, true) > 300) {
            throw new OrderLifecycleException('PAYMENT_QUOTE_REQUIRED', 'Review a fresh payment quote.');
        }
        $payload = json_decode($quote->payload, true, flags: JSON_THROW_ON_ERROR);
        if (($data['paymentMethodId'] ?? null) !== $payload['paymentMethodId']) {
            throw new OrderLifecycleException('ORDER_TOTAL_CHANGED', 'Payment method changed. Review a fresh quote.');
        }
        $method = $this->method($tenantId, $payload);
        if (($data['method'] ?? null) !== $method?->type) {
            throw new OrderLifecycleException('ORDER_TOTAL_CHANGED', 'Payment method changed. Review a fresh quote.');
        }
        $result = $this->engine->resolve($tenantId, $order, $this->engine->intent($tenantId, (int) $order->id), $method);
        if (! hash_equals($quote->fingerprint, $result['fingerprint'])) {
            throw new OrderLifecycleException('ORDER_TOTAL_CHANGED', 'Order or discount context changed. Review a fresh quote.');
        }
        if ($method === null && ($this->engine->cents($result['totals']['total']) > 0 || collect($result['discounts'])->contains(fn ($d) => $d['source'] !== 'automatic' && $d['discountId'] !== null && $this->engine->tenderRestricted($tenantId, DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $d['discountId'])->first())))) {
            throw new OrderLifecycleException('PAYMENT_TENDER_REQUIRED', 'Select a payment method and review a fresh quote.');
        }

        return ['resolution' => $result, 'method' => $method];
    }

    /** Saved snapshots only: this read never discovers or reprices discounts. */
    public function state(int $tenantId, object $order): array
    {
        $stored = DB::table('order_discount_intents')->where('tenant_id', $tenantId)->where('order_id', $order->id)->value('intent');
        $intents = $stored === null ? [] : $this->engine->intents(json_decode($stored, true, flags: JSON_THROW_ON_ERROR));
        $rows = DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order->id)->orderByRaw('coalesce(application_sequence, 0), id')->get();
        $discounts = $rows->map(function ($row) use ($tenantId): array {
            $snapshot = $row->policy_snapshot === null ? [] : json_decode($row->policy_snapshot, true, flags: JSON_THROW_ON_ERROR);

            return ['id' => (int) $row->id, 'discountId' => $row->discount_id === null ? null : (int) $row->discount_id, 'name' => $row->discount_name, 'source' => $row->source, 'stage' => $row->stage, 'type' => $row->discount_type, 'value' => (string) $row->discount_value, 'amount' => (string) $row->discount_amount, 'settingsVersion' => $row->settings_version, 'sequence' => $row->application_sequence === null ? null : (int) $row->application_sequence, 'combinationBehavior' => $snapshot['combinationBehavior'] ?? 'follow_cafe_policy', 'capped' => (bool) ($snapshot['capped'] ?? false), 'allocations' => DB::table('order_discount_allocations')->where('tenant_id', $tenantId)->where('order_discount_id', $row->id)->orderBy('order_item_id')->get()->map(fn ($a) => ['orderItemId' => (int) $a->order_item_id, 'amount' => (string) $a->amount])->all()];
        })->all();

        return ['orderId' => (int) $order->id, 'explicitIntent' => $intents[0] ?? null, 'explicitIntents' => $intents, 'discounts' => $discounts, 'requiresDiscountBreakdown' => count($discounts) > 1, 'discountContractVersion' => self::VERSION, 'policy' => DiscountSettingsService::effectivePolicy($this->settings->read($tenantId)), 'totals' => ['subtotal' => (string) $order->subtotal, 'discountTotal' => (string) $order->discount_total, 'taxTotal' => (string) $order->tax_total, 'total' => (string) $order->total], 'suppressions' => DB::table('order_discount_suppressions')->where('tenant_id', $tenantId)->where('order_id', $order->id)->orderBy('discount_id')->get(['discount_id', 'reason', 'suppressed_by'])->map(fn ($s) => ['discountId' => (int) $s->discount_id, 'reason' => $s->reason, 'actorId' => (int) $s->suppressed_by])->all()];
    }
}
