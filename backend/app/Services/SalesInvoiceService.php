<?php

namespace App\Services;

use App\Support\IdempotencyFingerprint;
use App\Domain\Inventory\RecipeMaterialEligibility;
use App\Domain\Inventory\UnitConversionResolver;
use App\Support\InventoryDecimal;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Canonical, integer-cent snapshot for a draft sales invoice. */
final class SalesInvoiceService
{
    public function __construct(private readonly UnitConversionResolver $conversions) {}
    public function create(int $tenantId, int $actorId, array $data): object
    {
        return DB::transaction(function () use ($tenantId, $actorId, $data): object {
            DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->firstOrFail();
            $fingerprint = IdempotencyFingerprint::from($data);
            if (! empty($data['idempotencyKey'])) {
                $existing = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('idempotency_key', $data['idempotencyKey'])->first();
                if ($existing) { if ($existing->request_fingerprint !== $fingerprint) throw ValidationException::withMessages(['idempotencyKey' => 'This idempotency key was already used for a different request.']); return $existing; }
            }
            $this->assertAccountsReceivableMapping($tenantId);
            $customer = $this->customer($tenantId, (int) $data['customerId']);
            $lines = $this->pricedLines($tenantId, $data['lines']); $charges = $this->charges($data['charges'] ?? []); $totals = $this->totals($lines, $charges, $data);
            $date = CarbonImmutable::parse($data['invoiceDate'])->toDateString();
            $due = ! empty($data['dueDate']) ? CarbonImmutable::parse($data['dueDate'])->toDateString() : CarbonImmutable::parse($date)->addDays((int) $customer->default_credit_terms_days)->toDateString();
            $year = CarbonImmutable::parse($date)->year; $sequence = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('invoice_number', 'like', "SI-{$year}-%")->count() + 1;
            $id = DB::table('sales_invoices')->insertGetId($this->header($tenantId, $actorId, $data, $customer, $date, $due, $year, $sequence, $fingerprint, $totals));
            $this->replaceLines($tenantId, $id, $lines); $this->replaceCharges($tenantId, $id, $charges, $totals['rate']);
            return $this->find($tenantId, $id);
        });
    }

    public function update(int $tenantId, int $invoiceId, int $actorId, array $data): object
    {
        return DB::transaction(function () use ($tenantId, $invoiceId, $actorId, $data): object {
            $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->lockForUpdate()->first(); abort_unless($invoice, 404, 'Sales invoice not found.');
            if ($invoice->status !== 'draft') throw ValidationException::withMessages(['status' => 'Only draft sales invoices can be edited.']);
            $customer = $this->customer($tenantId, (int) ($data['customerId'] ?? $invoice->customer_id));
            $lines = array_key_exists('lines', $data) ? $this->pricedLines($tenantId, $data['lines']) : $this->currentLines($invoiceId);
            $charges = array_key_exists('charges', $data) ? $this->charges($data['charges']) : $this->currentCharges($invoiceId);
            $totals = $this->totals($lines, $charges, ['invoiceDiscountType' => $data['invoiceDiscountType'] ?? $invoice->invoice_discount_type, 'invoiceDiscountValue' => $data['invoiceDiscountValue'] ?? $invoice->invoice_discount_value, 'manualAdjustment' => $data['manualAdjustment'] ?? $invoice->manual_adjustment]);
            $date = array_key_exists('invoiceDate', $data) ? CarbonImmutable::parse($data['invoiceDate'])->toDateString() : $invoice->invoice_date;
            $due = array_key_exists('dueDate', $data) ? (! empty($data['dueDate']) ? CarbonImmutable::parse($data['dueDate'])->toDateString() : CarbonImmutable::parse($date)->addDays((int) $customer->default_credit_terms_days)->toDateString()) : $invoice->due_date;
            $values = $this->totalValues($totals) + ['customer_id' => $customer->id, 'invoice_date' => $date, 'due_date' => $due, 'updated_by' => $actorId, 'updated_at' => now()];
            foreach (['branchId' => 'branch_id', 'reference' => 'reference', 'notes' => 'notes'] as $input => $column) if (array_key_exists($input, $data)) $values[$column] = $data[$input];
            DB::table('sales_invoices')->where('id', $invoiceId)->update($values);
            if (array_key_exists('lines', $data)) { DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->delete(); $this->replaceLines($tenantId, $invoiceId, $lines); }
            if (array_key_exists('charges', $data)) { DB::table('sales_invoice_charges')->where('sales_invoice_id', $invoiceId)->delete(); $this->replaceCharges($tenantId, $invoiceId, $charges, $totals['rate']); }
            return $this->find($tenantId, $invoiceId);
        });
    }

    public function cancel(int $tenantId, int $invoiceId, int $actorId, ?string $reason): object
    {
        $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->first(); abort_unless($invoice, 404, 'Sales invoice not found.');
        if ($invoice->status !== 'draft') throw ValidationException::withMessages(['status' => 'Only draft sales invoices can be cancelled.']);
        DB::table('sales_invoices')->where('id', $invoiceId)->update(['status' => 'cancelled', 'cancelled_by' => $actorId, 'cancelled_at' => now(), 'cancellation_reason' => $reason, 'updated_by' => $actorId, 'updated_at' => now()]); return $this->find($tenantId, $invoiceId);
    }

    public function find(int $tenantId, int $invoiceId): object
    {
        $invoice = DB::table('sales_invoices as i')->join('customers as c', 'c.id', '=', 'i.customer_id')->join('branches as b', 'b.id', '=', 'i.branch_id')->leftJoin('users as u', 'u.id', '=', 'i.created_by')->where('i.tenant_id', $tenantId)->where('i.id', $invoiceId)->select('i.*', 'c.name as customer_name', 'c.customer_number', 'b.name as branch_name', 'u.name as creator_name')->first(); abort_unless($invoice, 404, 'Sales invoice not found.');
        $invoice->lines = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->orderBy('line_number')->get();
        $invoice->charges = DB::table('sales_invoice_charges')->where('sales_invoice_id', $invoiceId)->orderBy('sort_order')->orderBy('id')->get(); return $invoice;
    }

    private function header(int $tenant, int $actor, array $data, object $customer, string $date, string $due, int $year, int $sequence, string $fingerprint, array $totals): array
    { return $this->totalValues($totals) + ['tenant_id' => $tenant, 'branch_id' => $data['branchId'], 'customer_id' => $customer->id, 'invoice_number' => sprintf('SI-%d-%06d', $year, $sequence), 'invoice_date' => $date, 'due_date' => $due, 'currency_code' => 'SYP', 'reference' => $data['reference'] ?? null, 'notes' => $data['notes'] ?? null, 'status' => 'draft', 'idempotency_key' => $data['idempotencyKey'] ?? null, 'request_fingerprint' => $fingerprint, 'created_by' => $actor, 'updated_by' => $actor, 'created_at' => now(), 'updated_at' => now()]; }
    private function totalValues(array $t): array
    { return ['tax_rate' => $this->rateDecimal($t['rate']), 'gross_subtotal' => Money::decimal($t['gross']), 'line_discount_total' => Money::decimal($t['lineDiscount']), 'invoice_discount_type' => $t['invoiceDiscountType'], 'invoice_discount_value' => Money::decimal($t['invoiceDiscountValue']), 'invoice_discount_total' => Money::decimal($t['invoiceDiscount']), 'additional_charges_total' => Money::decimal($t['charges']), 'manual_adjustment' => Money::decimal($t['adjustment']), 'taxable_amount' => Money::decimal($t['taxable']), 'subtotal' => Money::decimal($t['netProducts']), 'discount_total' => Money::decimal($t['lineDiscount'] + $t['invoiceDiscount']), 'tax_total' => Money::decimal($t['tax']), 'total' => Money::decimal($t['total'])]; }
    private function customer(int $tenant, int $id): object { $c = DB::table('customers')->where('tenant_id', $tenant)->where('id', $id)->where('is_active', true)->whereNull('deleted_at')->first(); if (! $c) throw ValidationException::withMessages(['customerId' => 'Select an active customer belonging to this tenant.']); return $c; }
    private function assertAccountsReceivableMapping(int $tenant): void { $m = DB::table('sales_account_mappings as m')->join('financial_accounts as a', 'a.id', '=', 'm.financial_account_id')->where('m.tenant_id', $tenant)->where('m.mapping_key', 'sales.accounts_receivable')->where('a.tenant_id', $tenant)->where('a.is_active', true)->whereNull('a.deleted_at')->select('a.account_group', 'a.normal_balance')->first(); if (! $m || $m->account_group !== 'assets' || $m->normal_balance !== 'debit') throw ValidationException::withMessages(['accountsReceivable' => 'Configure an active tenant Accounts Receivable asset account before creating sales invoices.']); }

    private function pricedLines(int $tenant, array $input): array
    {
        if ($input === []) throw ValidationException::withMessages(['lines' => 'At least one product line is required.']); $rate = $this->tenantTaxRateMicro($tenant); $out = [];
        foreach ($input as $i => $line) {
            if (isset($line['inventoryItemId'])) {
                $out[] = $this->pricedInventoryLine($tenant, $line, $i, $rate);
                continue;
            }
            $product = DB::table('products')->where('tenant_id', $tenant)->where('id', (int) ($line['productId'] ?? 0))->where('is_active', true)->whereNull('deleted_at')->first(); if (! $product) throw ValidationException::withMessages(["lines.$i.productId" => 'Select an active product belonging to this tenant.']);
            $variant = $this->variant($tenant, $product, $line['variantId'] ?? null, $i); $qty = $this->quantityMilli($line['quantity'] ?? null, "lines.$i.quantity"); $base = Money::cents($variant?->base_price ?? $product->price, "lines.$i.baseUnitPrice"); $unit = array_key_exists('unitPrice', $line) ? $this->nonNegativeMoney($line['unitPrice'], "lines.$i.unitPrice") : $base; $gross = intdiv(($unit * $qty) + 500, 1000);
            [$type, $value, $discount] = $this->discount($line['discountType'] ?? null, $line['discountValue'] ?? null, $gross, "lines.$i.discount"); $net = $gross - $discount; $tax = intdiv(($net * $rate) + 500000, 1000000);
            $overrides = $this->materialOverrides($tenant, $line['materialOverrides'] ?? null, "lines.$i.materialOverrides");
            $out[] = ['product_id' => $product->id, 'product_variant_id' => $variant?->id, 'product_name' => $product->name_ar ?: $product->name, 'product_sku' => $product->sku, 'quantity' => $this->milliDecimal($qty), 'base_unit_price' => Money::decimal($base), 'unit_price' => Money::decimal($unit), 'discount_type' => $type, 'discount_value' => Money::decimal($value), 'discount_amount' => Money::decimal($discount), 'discount_total' => Money::decimal($discount), 'line_subtotal' => Money::decimal($gross), 'tax_rate' => $this->rateDecimal($rate), 'subtotal' => Money::decimal($net), 'tax_total' => Money::decimal($tax), 'total' => Money::decimal($net + $tax), '_gross' => $gross, '_discount' => $discount, '_net' => $net, '_rate' => $rate, '_materialOverrides' => $overrides];
        } return $out;
    }
    /**
     * A line's optional per-invoice replacement of its product variant's
     * default recipe (App\Models\VariantRecipeComponent) — e.g. an extra cup
     * used for one particular sale — validated the same way the recipe
     * editor validates its own components, so an invalid override never
     * reaches posting where it would otherwise fail inside the inventory
     * consumption preview instead of here at save time.
     * @return array<int, array<string, mixed>>
     */
    private function materialOverrides(int $tenant, ?array $input, string $field): array
    {
        if ($input === null) return [];
        $out = []; $seen = [];
        foreach ($input as $i => $o) {
            $id = (int) ($o['inventoryItemId'] ?? 0);
            if (! $id || isset($seen[$id])) throw ValidationException::withMessages(["$field.$i.inventoryItemId" => 'Duplicate or invalid material.']);
            $seen[$id] = true;
            $material = DB::table('inventory_items')->where('tenant_id', $tenant)->where('id', $id)->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $material || ! RecipeMaterialEligibility::allows($material)) throw ValidationException::withMessages(["$field.$i.inventoryItemId" => 'Select an active, eligible stock material.']);
            $quantity = trim((string) ($o['quantity'] ?? '')); $unitCode = (string) ($o['unitCode'] ?? '');
            // Validate only — variant_recipe_components' own convention (RecipeConfigurationService::replaceRecipe)
            // is to persist the raw input code, not resolveRecipe()'s normalized `inputUnit` (which can exceed the
            // unit_code column's varchar(8), e.g. "milliliter").
            $this->conversions->resolveRecipe($tenant, $material, $quantity, $unitCode !== '' ? $unitCode : null);
            $out[] = ['inventory_item_id' => $id, 'quantity' => $quantity, 'unit_code' => $unitCode !== '' ? $unitCode : $material->unit, 'sort_order' => $i];
        }
        return $out;
    }
    private function pricedInventoryLine(int $tenant, array $line, int $i, int $rate): array
    {
        if (isset($line['productId']) || isset($line['variantId'])) throw ValidationException::withMessages(["lines.$i" => 'Select either a product or an inventory material.']);
        if (isset($line['materialOverrides'])) throw ValidationException::withMessages(["lines.$i.materialOverrides" => 'Material overrides only apply to product lines, not a directly sold inventory material.']);
        $material = DB::table('inventory_items')->where('tenant_id', $tenant)->where('id', (int) $line['inventoryItemId'])->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $material || ! RecipeMaterialEligibility::allows($material)) throw ValidationException::withMessages(["lines.$i.inventoryItemId" => 'Select an active stock material.']);
        $qty = $this->quantityMilli($line['quantity'] ?? null, "lines.$i.quantity");
        $converted = $this->conversions->resolve($tenant, $material, (string) $line['quantity'], $line['unitCode'] ?? null);
        if ($converted['baseQuantity'] <= 0) throw ValidationException::withMessages(["lines.$i.quantity" => 'The base quantity must be positive.']);
        $unit = $this->nonNegativeMoney($line['unitPrice'] ?? null, "lines.$i.unitPrice");
        $gross = intdiv(($unit * $qty) + 500, 1000);
        [$type, $value, $discount] = $this->discount($line['discountType'] ?? null, $line['discountValue'] ?? null, $gross, "lines.$i.discount");
        $net = $gross - $discount; $tax = intdiv(($net * $rate) + 500000, 1000000);
        return ['product_id' => null, 'product_variant_id' => null, 'inventory_item_id' => $material->id, 'unit_code' => $converted['inputUnit'], 'base_quantity' => InventoryDecimal::quantity($converted['baseQuantity']), 'product_name' => $material->name_ar ?: $material->name, 'product_sku' => $material->sku, 'quantity' => $this->milliDecimal($qty), 'base_unit_price' => Money::decimal($unit), 'unit_price' => Money::decimal($unit), 'discount_type' => $type, 'discount_value' => Money::decimal($value), 'discount_amount' => Money::decimal($discount), 'discount_total' => Money::decimal($discount), 'line_subtotal' => Money::decimal($gross), 'tax_rate' => $this->rateDecimal($rate), 'subtotal' => Money::decimal($net), 'tax_total' => Money::decimal($tax), 'total' => Money::decimal($net + $tax), '_gross' => $gross, '_discount' => $discount, '_net' => $net, '_rate' => $rate];
    }
    /** Variant's own base_price is the authoritative default when a variant is selected (mirrors ProductVariantPriceResolver's fallback), never the parent product's price. */
    private function variant(int $tenant, object $p, mixed $input, int $i): ?object { if ($input !== null) { $v = DB::table('product_variants')->where('tenant_id', $tenant)->where('id', (int) $input)->where('product_id', $p->id)->where('is_active', true)->whereNull('deleted_at')->first(); if (! $v) throw ValidationException::withMessages(["lines.$i.variantId" => 'Select an active variant belonging to the selected product.']); return $v; } if ((bool) $p->is_stock_tracked || (bool) $p->inventory_controlled) { $v = DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $p->id)->where('is_active', true)->where('is_default', true)->whereNull('deleted_at')->first(); if (! $v) throw ValidationException::withMessages(["lines.$i.variantId" => 'Inventory-tracked products require an active sellable variant.']); return $v; } return null; }
    private function charges(array $input): array { $out=[]; foreach ($input as $i => $c) { $name=trim((string)($c['name']??'')); if ($name==='' || mb_strlen($name)>255) throw ValidationException::withMessages(["charges.$i.name"=>'A charge name of up to 255 characters is required.']); $out[]=['name'=>$name,'amount'=>$this->nonNegativeMoney($c['amount']??null,"charges.$i.amount"),'taxable'=>!array_key_exists('taxable',$c)||filter_var($c['taxable'],FILTER_VALIDATE_BOOLEAN)]; } return $out; }
    private function currentLines(int $id): array { return DB::table('sales_invoice_lines')->where('sales_invoice_id',$id)->orderBy('line_number')->get()->map(fn(object $l):array=>['product_id'=>$l->product_id,'product_variant_id'=>$l->product_variant_id,'inventory_item_id'=>$l->inventory_item_id,'unit_code'=>$l->unit_code,'base_quantity'=>$l->base_quantity,'product_name'=>$l->product_name,'product_sku'=>$l->product_sku,'quantity'=>$l->quantity,'base_unit_price'=>$l->base_unit_price,'unit_price'=>$l->unit_price,'discount_type'=>$l->discount_type,'discount_value'=>$l->discount_value,'discount_amount'=>$l->discount_amount,'discount_total'=>$l->discount_total,'line_subtotal'=>$l->line_subtotal,'tax_rate'=>$l->tax_rate,'subtotal'=>$l->subtotal,'tax_total'=>$l->tax_total,'total'=>$l->total,'_gross'=>Money::cents($l->line_subtotal),'_discount'=>Money::cents($l->discount_amount),'_net'=>Money::cents($l->subtotal),'_rate'=>$this->rateMicro($l->tax_rate)])->all(); }
    private function currentCharges(int $id): array { return DB::table('sales_invoice_charges')->where('sales_invoice_id',$id)->orderBy('sort_order')->get()->map(fn(object $c):array=>['name'=>$c->name,'amount'=>Money::cents($c->amount),'taxable'=>(bool)$c->taxable])->all(); }
    private function totals(array $lines, array $charges, array $data): array { $gross=array_sum(array_column($lines,'_gross')); $lineDiscount=array_sum(array_column($lines,'_discount')); $lineNet=$gross-$lineDiscount; [$type,$value,$invoiceDiscount]=$this->discount($data['invoiceDiscountType']??null,$data['invoiceDiscountValue']??null,$lineNet,'invoiceDiscount'); $netProducts=$lineNet-$invoiceDiscount; $chargesTotal=array_sum(array_column($charges,'amount')); $taxableCharges=array_sum(array_map(fn(array $c):int=>$c['taxable']?$c['amount']:0,$charges)); $rate=(int)($lines[0]['_rate']??0); $taxable=$netProducts+$taxableCharges; $tax=intdiv(($taxable*$rate)+500000,1000000); $adjustment=$this->signedMoney($data['manualAdjustment']??'0','manualAdjustment'); $total=$netProducts+$chargesTotal+$tax+$adjustment; if($total<0) throw ValidationException::withMessages(['manualAdjustment'=>'The final total cannot be negative.']); return ['gross'=>$gross,'lineDiscount'=>$lineDiscount,'invoiceDiscountType'=>$type,'invoiceDiscountValue'=>$value,'invoiceDiscount'=>$invoiceDiscount,'netProducts'=>$netProducts,'charges'=>$chargesTotal,'taxable'=>$taxable,'tax'=>$tax,'adjustment'=>$adjustment,'total'=>$total,'rate'=>$rate]; }
    private function replaceLines(int $tenant,int $invoice,array $lines):void { foreach($lines as $i=>$line){$overrides=$line['_materialOverrides']??[];unset($line['_gross'],$line['_discount'],$line['_net'],$line['_rate'],$line['_materialOverrides']);$lineId=DB::table('sales_invoice_lines')->insertGetId($line+['tenant_id'=>$tenant,'sales_invoice_id'=>$invoice,'line_number'=>$i+1,'created_at'=>now(),'updated_at'=>now()]);foreach($overrides as $o){DB::table('sales_invoice_line_material_overrides')->insert($o+['tenant_id'=>$tenant,'sales_invoice_line_id'=>$lineId,'created_at'=>now(),'updated_at'=>now()]);}} }
    private function replaceCharges(int $tenant,int $invoice,array $charges,int $rate):void { foreach($charges as $i=>$c){$tax=$c['taxable']?intdiv(($c['amount']*$rate)+500000,1000000):0;DB::table('sales_invoice_charges')->insert(['tenant_id'=>$tenant,'sales_invoice_id'=>$invoice,'name'=>$c['name'],'amount'=>Money::decimal($c['amount']),'taxable'=>$c['taxable'],'tax_total'=>Money::decimal($tax),'sort_order'=>$i+1,'created_at'=>now(),'updated_at'=>now()]);} }
    private function discount(mixed $type,mixed $value,int $base,string $field):array { $type=$type===null||$type===''?null:(string)$type; if($type===null)return[null,0,0];if(!in_array($type,['percent','fixed'],true))throw ValidationException::withMessages(["$field.type"=>'Discount type must be percent or fixed.']);$valueCents=$this->nonNegativeMoney($value??'0',"$field.value");$amount=$type==='fixed'?$valueCents:intdiv(($base*$this->rateMicro($value??'0'))+50000000,100000000);if($amount>$base)throw ValidationException::withMessages([$field=>'Discount cannot exceed its applicable amount.']);return[$type,$valueCents,$amount]; }
    private function nonNegativeMoney(mixed $v,string $field):int{$c=Money::cents($v,$field);if($c<0)throw ValidationException::withMessages([$field=>'Amount cannot be negative.']);return$c;} private function signedMoney(mixed $v,string $field):int{return Money::cents($v,$field);}
    private function quantityMilli(mixed $v,string $field):int{if(!preg_match('/^(\d+)(?:\.(\d+))?$/',trim((string)$v),$m))throw ValidationException::withMessages([$field=>'Quantity must use no more than three decimal places.']);$f=$m[2]??'';if(strlen($f)>3&&trim(substr($f,3),'0')!=='')throw ValidationException::withMessages([$field=>'Quantity must use no more than three decimal places.']);$q=((int)$m[1]*1000)+(int)str_pad(substr($f,0,3),3,'0');if($q<1)throw ValidationException::withMessages([$field=>'Quantity must be greater than zero.']);return$q;} private function milliDecimal(int $v):string{return number_format($v/1000,3,'.','');}
    private function tenantTaxRateMicro(int $tenant):int{return $this->rateMicro(DB::table('tenants')->where('id',$tenant)->value('tax_rate')??'0');} private function rateMicro(mixed $v):int{$v=trim((string)$v);if(!preg_match('/^(\d+)(?:\.(\d+))?$/',$v,$m))throw ValidationException::withMessages(['discountValue'=>'Percentage must be a non-negative decimal.']);$f=$m[2]??'';if(strlen($f)>6&&trim(substr($f,6),'0')!=='')throw ValidationException::withMessages(['discountValue'=>'Percentage must use no more than six decimal places.']);return((int)$m[1]*1000000)+(int)str_pad(substr($f,0,6),6,'0');} private function rateDecimal(int $v):string{return number_format($v/1000000,6,'.','');}
}
