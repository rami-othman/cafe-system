<?php

namespace Tests\Unit;

use App\Support\SalesTotals;
use PHPUnit\Framework\TestCase;

final class SalesTotalsTest extends TestCase
{
    public function test_three_sales_definitions_use_cents_and_keep_purchases_out_of_total(): void
    {
        $totals = SalesTotals::make(10000, 500, 300, 2000, 700);

        $this->assertSame('100.00', $totals['salesSum']);
        $this->assertSame('92.00', $totals['salesTotal']);
        $this->assertSame('65.00', $totals['salesNet']);
        $this->assertSame('20.00', $totals['purchasesPaid']);
        $this->assertSame('7.00', $totals['expensesPaid']);
    }
}
