<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
return new class extends Migration {
    public function up(): void {
        if (DB::table('manufacturing_recipes')->whereNull('branch_id')->exists()) throw new RuntimeException('Run factory:backfill-recipes before requiring recipe branches.');
        DB::statement('ALTER TABLE manufacturing_recipes ALTER COLUMN branch_id SET NOT NULL');
    }
    public function down(): void { DB::statement('ALTER TABLE manufacturing_recipes ALTER COLUMN branch_id DROP NOT NULL'); }
};
