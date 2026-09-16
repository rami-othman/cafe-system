<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Legacy null-expiry bearer sessions are intentionally cut over to an
        // immediate re-login rather than receiving a new unbounded lifetime.
        DB::table('api_tokens')->whereNull('expires_at')->update([
            'expires_at' => now(),
            'updated_at' => now(),
        ]);

        Schema::table('api_tokens', function (Blueprint $table): void {
            $table->timestamp('expires_at')->nullable(false)->change();
        });
    }

    public function down(): void
    {
        Schema::table('api_tokens', function (Blueprint $table): void {
            $table->timestamp('expires_at')->nullable()->change();
        });
    }
};
