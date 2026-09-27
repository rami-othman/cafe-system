<?php

namespace App\Support;

use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Document money is converted once; ledger, inventory valuation and allocations stay in SYP. */
final class FactoryCurrency
{
    public static function rules(): array
    {
        return ['documentCurrency' => ['nullable', 'in:SYP,USD'], 'usdToSyp' => ['nullable', 'regex:/^\d+(\.\d{1,6})?$/', 'numeric', 'gt:0', 'max:1000000000']];
    }

    public static function normalize(int $tenant, array $data, string $kind): array
    {
        if (! isset($data['documentCurrency'])) {
            return $data;
        }
        $branch = DB::table('branches')->where('tenant_id', $tenant)->where('id', $data['branchId'] ?? 0)->whereNull('deleted_at')->first();
        if ($branch?->branch_type !== 'factory') {
            throw ValidationException::withMessages(['documentCurrency' => 'اختيار العملة متاح للمعمل فقط.']);
        }
        $currency = $data['documentCurrency'];
        if (! in_array($currency, ['SYP', 'USD'], true)) {
            throw ValidationException::withMessages(['documentCurrency' => 'عملة غير مدعومة.']);
        }
        $rate = $currency === 'USD' ? ($data['usdToSyp'] ?? DB::table('factory_currency_settings')->where('tenant_id', $tenant)->where('branch_id', $branch->id)->value('usd_to_syp')) : '1';
        if (! is_numeric($rate) || $rate <= 0 || $rate > 1000000000 || ! preg_match('/^\d+(\.\d{1,6})?$/', (string) $rate)) {
            throw ValidationException::withMessages(['usdToSyp' => 'أدخل سعر الدولار مقابل الليرة السورية.']);
        }
        $original = $data;
        $convert = fn ($value, int $precision = 2) => self::convert((string) $value, (string) $rate, $precision);
        if ($currency === 'USD') {
            foreach (['subtotal', 'taxAmount', 'totalAmount', 'manualAdjustment', 'amount'] as $field) {
                if (isset($data[$field])) {
                    $data[$field] = $convert($data[$field]);
                }
            }
            foreach (['discountValue' => 'discountType', 'invoiceDiscountValue' => 'invoiceDiscountType'] as $field => $type) {
                if (isset($data[$field]) && ! in_array($data[$type] ?? 'fixed', ['percent', 'percentage'], true)) {
                    $data[$field] = $convert($data[$field]);
                }
            }
            foreach ($data['lines'] ?? [] as $i => $line) {
                foreach (['unitCost', 'unitPrice', 'lineGrossAmount', 'taxAmount', 'amount'] as $field) {
                    if (isset($line[$field])) {
                        $data['lines'][$i][$field] = $convert($line[$field], $field === 'unitCost' ? 4 : 2);
                    }
                }
                if (isset($line['discountValue']) && ! in_array($line['discountType'] ?? 'fixed', ['percent', 'percentage'], true)) {
                    $data['lines'][$i]['discountValue'] = $convert($line['discountValue']);
                }
                if ($kind === 'sales' && ! isset($line['unitPrice'])) {
                    throw ValidationException::withMessages(['lines' => 'أدخل سعر البيع بالدولار لكل منتج.']);
                }
            }
            foreach ($data['charges'] ?? [] as $i => $charge) {
                foreach (['amount', 'taxAmount'] as $field) {
                    if (isset($charge[$field])) {
                        $data['charges'][$i][$field] = $convert($charge[$field]);
                    }
                }
            }
            // Payment allocations are explicitly entered in ledger SYP, not the voucher currency.
        }
        $data['_factoryCurrency'] = ['currency' => $currency, 'baseCurrency' => 'SYP', 'rate' => (string) $rate, 'input' => $original];

        return $data;
    }

    public static function columns(array $data): array
    {
        return isset($data['_factoryCurrency']) ? ['factory_currency' => json_encode($data['_factoryCurrency'], JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR)] : [];
    }

    public static function paymentDisplay(object $invoice, string $baseAmount): array
    {
        $snapshot = self::snapshot($invoice);
        if ($snapshot === null) {
            return [];
        }
        $amount = BigDecimal::of($baseAmount)->dividedBy($snapshot['rate'], 6, RoundingMode::HALF_UP);

        return ['_factoryCurrency' => ['currency' => $snapshot['currency'], 'baseCurrency' => 'SYP',
            'rate' => $snapshot['rate'], 'input' => ['amount' => (string) $amount, 'baseAmount' => $baseAmount]]];
    }

    public static function snapshot(object $row): ?array
    {
        $value = $row->factory_currency ?? null;

        return is_string($value) ? json_decode($value, true, 512, JSON_THROW_ON_ERROR) : $value;
    }

    private static function convert(string $value, string $rate, int $precision): string
    {
        if (! preg_match('/^-?\d+(\.\d{1,6})?$/', $value)) {
            throw ValidationException::withMessages(['amount' => 'المبلغ يجب أن يحتوي على ست منازل عشرية كحد أقصى.']);
        }
        $result = BigDecimal::of($value)->multipliedBy($rate)->toScale($precision, RoundingMode::HALF_UP);
        if ($result->abs()->isGreaterThan('999999999999.99')) {
            throw ValidationException::withMessages(['amount' => 'المبلغ المحول يتجاوز الحد المسموح.']);
        }

        return (string) $result;
    }
}
