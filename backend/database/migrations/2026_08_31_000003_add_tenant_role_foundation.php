<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_roles', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->string('code', 50);
            $table->string('name', 100);
            $table->boolean('is_system')->default(true);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->unique(['tenant_id', 'code']);
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->foreignId('tenant_role_id')->nullable()->after('tenant_id')->constrained('tenant_roles')->nullOnDelete();
            $table->index(['tenant_id', 'tenant_role_id']);
        });

        $now = now();
        foreach (DB::table('tenants')->orderBy('id')->pluck('id') as $tenantId) {
            foreach ([
                'owner' => 'Owner',
                'manager' => 'Manager',
                'employee' => 'Employee',
            ] as $code => $name) {
                DB::table('tenant_roles')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'code' => $code],
                    ['name' => $name, 'is_system' => true, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now],
                );
            }

            $roles = DB::table('tenant_roles')->where('tenant_id', $tenantId)->pluck('id', 'code');
            DB::table('users')->where('tenant_id', $tenantId)->orderBy('id')->get(['id', 'role'])->each(function (object $user) use ($roles): void {
                $code = match ($user->role) {
                    'owner' => 'owner',
                    'manager' => 'manager',
                    default => 'employee',
                };
                DB::table('users')->where('id', $user->id)->update(['tenant_role_id' => $roles[$code], 'updated_at' => now()]);
            });
        }
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'tenant_role_id']);
            $table->dropConstrainedForeignId('tenant_role_id');
        });

        Schema::dropIfExists('tenant_roles');
    }
};
