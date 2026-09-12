<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        try {
            DB::statement('CREATE EXTENSION IF NOT EXISTS pg_trgm');
        } catch (Throwable $exception) {
            throw new RuntimeException('Customer domain requires the PostgreSQL pg_trgm extension.', 0, $exception);
        }

        if (! Schema::hasColumn('customers', 'customer_number')) {
            Schema::table('customers', fn (Blueprint $table) => $table->string('customer_number', 32)->nullable());
        }
        if (! Schema::hasColumn('customers', 'normalized_name')) {
            Schema::table('customers', fn (Blueprint $table) => $table->string('normalized_name')->nullable());
        }

        if (! $this->indexExists('customers_tenant_id_id_unique')) {
            Schema::table('customers', fn (Blueprint $table) => $table->unique(['tenant_id', 'id'], 'customers_tenant_id_id_unique'));
        }

        if (! Schema::hasTable('customer_number_counters')) {
            Schema::create('customer_number_counters', function (Blueprint $table): void {
                $table->id();
                $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
                $table->unsignedBigInteger('next_value')->default(1);
                $table->timestamps();
                $table->unique('tenant_id');
            });
        }

        if (! Schema::hasTable('customer_phones')) {
            Schema::create('customer_phones', function (Blueprint $table): void {
                $table->id();
                $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
                $table->unsignedBigInteger('customer_id');
                $table->string('raw_number', 50);
                $table->string('normalized_number', 32)->nullable();
                $table->string('type', 30)->default('mobile');
                $table->boolean('is_primary')->default(false);
                $table->string('validation_status', 20);
                $table->timestamps();
                $table->foreign(['tenant_id', 'customer_id'], 'customer_phones_tenant_customer_fk')
                    ->references(['tenant_id', 'id'])->on('customers')->cascadeOnDelete();
                $table->unique(['customer_id', 'normalized_number'], 'customer_phones_customer_normalized_unique');
                $table->index(['tenant_id', 'customer_id', 'is_primary'], 'customer_phones_tenant_customer_primary_idx');
            });
        }

        if (! Schema::hasTable('customer_groups')) {
            Schema::create('customer_groups', function (Blueprint $table): void {
                $table->id();
                $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
                $table->string('name');
                $table->string('normalized_name');
                $table->boolean('is_active')->default(true);
                $table->timestamps();
                $table->softDeletes();
                $table->unique(['tenant_id', 'normalized_name'], 'customer_groups_tenant_normalized_name_unique');
                $table->unique(['tenant_id', 'id'], 'customer_groups_tenant_id_unique');
                $table->index(['tenant_id', 'is_active', 'deleted_at'], 'customer_groups_tenant_lifecycle_idx');
            });
        }

        if (! Schema::hasTable('customer_group_memberships')) {
            Schema::create('customer_group_memberships', function (Blueprint $table): void {
                $table->id();
                $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
                $table->unsignedBigInteger('customer_id');
                $table->unsignedBigInteger('customer_group_id');
                $table->timestamps();
                $table->foreign(['tenant_id', 'customer_id'], 'customer_memberships_tenant_customer_fk')
                    ->references(['tenant_id', 'id'])->on('customers')->cascadeOnDelete();
                $table->foreign(['tenant_id', 'customer_group_id'], 'customer_memberships_tenant_group_fk')
                    ->references(['tenant_id', 'id'])->on('customer_groups')->cascadeOnDelete();
                $table->unique(['tenant_id', 'customer_id', 'customer_group_id'], 'customer_memberships_identity_unique');
                $table->index(['tenant_id', 'customer_group_id', 'customer_id'], 'customer_memberships_group_lookup_idx');
            });
        }

        if (! Schema::hasTable('customer_role_permissions')) {
            Schema::create('customer_role_permissions', function (Blueprint $table): void {
                $table->id();
                $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
                $table->string('role', 40);
                $table->string('permission', 100);
                $table->timestamps();
                $table->unique(['tenant_id', 'role', 'permission']);
                $table->index(['tenant_id', 'role']);
            });
            DB::statement("ALTER TABLE customer_role_permissions ADD CONSTRAINT customer_role_permissions_allowlist CHECK (role = 'manager' AND permission = 'customer.manage')");
        }

        $this->createIndexIfMissing('customers_tenant_lifecycle_idx', 'CREATE INDEX customers_tenant_lifecycle_idx ON customers (tenant_id, is_active, deleted_at, id)');
        $this->createIndexIfMissing('customers_tenant_number_idx', 'CREATE INDEX customers_tenant_number_idx ON customers (tenant_id, customer_number)');
        $this->createIndexIfMissing('customers_tenant_normalized_name_idx', 'CREATE INDEX customers_tenant_normalized_name_idx ON customers (tenant_id, normalized_name, id)');
        $this->createIndexIfMissing('customer_phones_tenant_normalized_idx', 'CREATE INDEX customer_phones_tenant_normalized_idx ON customer_phones (tenant_id, normalized_number)');
        $this->createIndexIfMissing('customer_phones_tenant_raw_idx', 'CREATE INDEX customer_phones_tenant_raw_idx ON customer_phones (tenant_id, raw_number)');
        $this->createIndexIfMissing('customers_normalized_name_trgm_idx', 'CREATE INDEX customers_normalized_name_trgm_idx ON customers USING gin (normalized_name gin_trgm_ops)');
        $this->createIndexIfMissing('customers_number_trgm_idx', 'CREATE INDEX customers_number_trgm_idx ON customers USING gin (customer_number gin_trgm_ops)');
        $this->createIndexIfMissing('customers_email_trgm_idx', 'CREATE INDEX customers_email_trgm_idx ON customers USING gin (email gin_trgm_ops)');
        $this->createIndexIfMissing('customer_phones_normalized_trgm_idx', 'CREATE INDEX customer_phones_normalized_trgm_idx ON customer_phones USING gin (normalized_number gin_trgm_ops)');
    }

    public function down(): void
    {
        // Customer writes are additive and may exist in production; rollback is roll-forward.
        // DatabaseMigrations tests need the newly-created child tables removed before
        // Laravel rolls back the legacy customers table in the next migration.
        if (! app()->environment('testing')) {
            return;
        }

        Schema::dropIfExists('customer_role_permissions');
        Schema::dropIfExists('customer_group_memberships');
        Schema::dropIfExists('customer_groups');
        Schema::dropIfExists('customer_phones');
        Schema::dropIfExists('customer_number_counters');
    }

    private function indexExists(string $name): bool
    {
        return DB::table('pg_indexes')->where('indexname', $name)->exists();
    }

    private function createIndexIfMissing(string $name, string $sql): void
    {
        if (! $this->indexExists($name)) {
            DB::statement($sql);
        }
    }
};
