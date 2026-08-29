<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE published_menu_versions DROP CONSTRAINT IF EXISTS published_menu_versions_tenant_id_branch_id_channel_checksum_un');
        DB::statement('CREATE INDEX published_menu_versions_checksum_lookup ON published_menu_versions (tenant_id, branch_id, channel, checksum)');
    }

    public function down(): void
    {
        $duplicates = DB::table('published_menu_versions')->selectRaw('1')->groupBy('tenant_id', 'branch_id', 'channel', 'checksum')->havingRaw('count(*) > 1')->exists();
        if ($duplicates) {
            throw new RuntimeException('Cannot restore unique published-menu checksum constraint while duplicate historical checksums exist.');
        }
        DB::statement('DROP INDEX IF EXISTS published_menu_versions_checksum_lookup');
        DB::statement('ALTER TABLE published_menu_versions ADD CONSTRAINT published_menu_versions_tenant_id_branch_id_channel_checksum_un UNIQUE (tenant_id, branch_id, channel, checksum)');
    }
};
