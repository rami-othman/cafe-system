<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // The shift's float (عهدة): physical cash left in the drawer for change. It is deliberately OFF the
        // books — never in the drawer ledger, sales, or the close transfer. NULL on shifts opened before this
        // column existed, so they fall back to the branch default instead of silently carrying 0.
        Schema::table('shifts', function (Blueprint $table): void {
            $table->decimal('float_amount', 14, 2)->nullable()->after('closing_float_amount');
        });
    }

    public function down(): void
    {
        Schema::table('shifts', fn (Blueprint $table) => $table->dropColumn('float_amount'));
    }
};
