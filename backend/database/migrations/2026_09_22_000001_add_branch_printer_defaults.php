<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('branches', function (Blueprint $table): void {
            $table->boolean('receipt_printing_enabled')->default(false);
            $table->string('default_paper_width', 4)->default('80mm');
            $table->boolean('auto_print_after_payment')->default(false);
            $table->string('default_printer_name')->nullable();
            $table->string('default_printer_ip')->nullable();
            $table->unsignedSmallInteger('default_printer_port')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('branches', function (Blueprint $table): void {
            $table->dropColumn([
                'receipt_printing_enabled', 'default_paper_width', 'auto_print_after_payment',
                'default_printer_name', 'default_printer_ip', 'default_printer_port',
            ]);
        });
    }
};
