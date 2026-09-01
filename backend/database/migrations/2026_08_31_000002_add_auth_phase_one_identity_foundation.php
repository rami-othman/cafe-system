<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('username')->nullable()->after('email');
            $table->string('normalized_username')->nullable()->after('username');
            $table->boolean('must_change_password')->default(false)->after('is_active');
            $table->unique(['tenant_id', 'normalized_username'], 'users_tenant_normalized_username_unique');
        });

        Schema::table('api_tokens', function (Blueprint $table): void {
            $table->timestamp('revoked_at')->nullable()->after('expires_at');
            $table->index(['user_id', 'revoked_at']);
        });
    }

    public function down(): void
    {
        Schema::table('api_tokens', function (Blueprint $table): void {
            $table->dropIndex(['user_id', 'revoked_at']);
            $table->dropColumn('revoked_at');
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->dropUnique('users_tenant_normalized_username_unique');
            $table->dropColumn(['username', 'normalized_username', 'must_change_password']);
        });
    }
};
