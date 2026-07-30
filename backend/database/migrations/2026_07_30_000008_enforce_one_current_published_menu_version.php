<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("CREATE UNIQUE INDEX published_menu_versions_one_current ON published_menu_versions (tenant_id, branch_id, channel) WHERE status = 'current'");
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS published_menu_versions_one_current');
    }
};
