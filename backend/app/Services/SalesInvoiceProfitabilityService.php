<?php

namespace App\Services;

use App\Support\Money;
use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use Illuminate\Support\Facades\DB;

/** Reads immutable posting snapshots; never uses today's item costs. */
final class SalesInvoiceProfitabilityService
{
    public function forInvoice(int $tenantId, object $invoice): ?array
    {
        if ($invoice->status !== 'posted') {
            return null;
        }
        $revenue = Money::cents($invoice->total) - Money::cents($invoice->tax_total);
        $cost = Money::cents(DB::table('sales_invoice_lines')->where('tenant_id', $tenantId)->where('sales_invoice_id', $invoice->id)->sum('cogs_total'));
        $notes = DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('original_sales_invoice_id', $invoice->id)->where('status', 'posted')->get(['id', 'total', 'tax_total']);
        $creditedRevenue = $notes->sum(fn ($note) => Money::cents($note->total) - Money::cents($note->tax_total));
        $reversedCost = Money::cents(DB::table('sales_credit_note_lines')->where('tenant_id', $tenantId)->whereIn('sales_credit_note_id', $notes->pluck('id'))->sum('cogs_total'));
        $netRevenue = $revenue - $creditedRevenue;
        $netCost = $cost - $reversedCost;
        $profit = $netRevenue - $netCost;

        return [
            'revenueBeforeReturns' => Money::decimal($revenue), 'costBeforeReturns' => Money::decimal($cost),
            'creditedRevenue' => Money::decimal($creditedRevenue), 'costReversed' => Money::decimal($reversedCost),
            'netRevenue' => Money::decimal($netRevenue), 'netCogs' => Money::decimal($netCost),
            'grossProfit' => Money::decimal($profit),
            'grossMarginPercent' => $netRevenue > 0 ? (string) BigDecimal::of($profit)->multipliedBy(100)->dividedBy($netRevenue, 2, RoundingMode::HALF_UP) : null,
            'basis' => 'posted_inventory_cost_excluding_operating_costs',
        ];
    }
}
