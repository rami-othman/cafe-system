<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::connection()->getDriverName() === 'sqlite') {
            return;
        }

        DB::statement('ALTER TABLE api_tokens ALTER COLUMN tenant_id DROP NOT NULL');
    }

    public function down(): void
    {
        if (DB::connection()->getDriverName() === 'sqlite') {
            return;
        }

        DB::statement('DELETE FROM api_tokens WHERE tenant_id IS NULL');
        DB::statement('ALTER TABLE api_tokens ALTER COLUMN tenant_id SET NOT NULL');
    }
};
