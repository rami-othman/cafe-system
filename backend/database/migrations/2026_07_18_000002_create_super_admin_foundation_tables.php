<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('platform_roles', function (Blueprint $table): void {
            $table->id();
            $table->string('code')->unique();
            $table->string('name');
            $table->boolean('is_root')->default(false);
            $table->timestamps();
        });
        Schema::create('platform_permissions', function (Blueprint $table): void {
            $table->id();
            $table->string('key')->unique();
            $table->string('name');
            $table->timestamps();
        });
        Schema::create('platform_role_user', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('platform_role_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['platform_role_id', 'user_id']);
        });
        Schema::create('platform_permission_role', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('platform_permission_id')->constrained()->cascadeOnDelete();
            $table->foreignId('platform_role_id')->constrained()->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['platform_permission_id', 'platform_role_id']);
        });
        Schema::create('plans', function (Blueprint $table): void {
            $table->id();
            $table->string('code')->unique();
            $table->string('name');
            $table->text('description')->nullable();
            $table->decimal('monthly_price', 12, 2)->default(0);
            $table->decimal('yearly_price', 12, 2)->default(0);
            $table->string('currency', 3)->default('USD');
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('display_order')->default(0);
            $table->json('metadata')->nullable();
            $table->timestamps();
        });
        Schema::create('plan_features', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('plan_id')->constrained()->cascadeOnDelete();
            $table->string('feature_key');
            $table->boolean('is_enabled')->default(false);
            $table->unsignedInteger('limit_value')->nullable();
            $table->timestamps();
            $table->unique(['plan_id', 'feature_key']);
        });
        Schema::create('subscriptions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('plan_id')->constrained();
            $table->string('status')->default('trialing');
            $table->string('billing_cycle')->default('monthly');
            $table->timestamp('trial_starts_at')->nullable();
            $table->timestamp('trial_ends_at')->nullable();
            $table->timestamp('current_period_starts_at')->nullable();
            $table->timestamp('current_period_ends_at')->nullable();
            $table->boolean('cancel_at_period_end')->default(false);
            $table->timestamp('cancelled_at')->nullable();
            $table->string('provider')->default('manual');
            $table->string('external_customer_id')->nullable();
            $table->string('external_subscription_id')->nullable();
            $table->text('admin_notes')->nullable();
            $table->timestamps();
            $table->index(['status', 'current_period_ends_at']);
            $table->unique(['tenant_id', 'provider']);
        });
        Schema::create('subscription_events', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('subscription_id')->constrained()->cascadeOnDelete();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('event');
            $table->json('payload')->nullable();
            $table->text('reason')->nullable();
            $table->timestamp('occurred_at');
            $table->timestamps();
            $table->index(['subscription_id', 'occurred_at']);
        });
        Schema::create('tenant_settings', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->json('settings')->nullable();
            $table->timestamps();
            $table->unique('tenant_id');
        });
        Schema::create('platform_audit_logs', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('action');
            $table->string('target_type')->nullable();
            $table->unsignedBigInteger('target_id')->nullable();
            $table->foreignId('tenant_id')->nullable()->constrained()->nullOnDelete();
            $table->json('before_state')->nullable();
            $table->json('after_state')->nullable();
            $table->text('reason')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->uuid('request_id')->nullable();
            $table->timestamps();
            $table->index(['tenant_id', 'created_at']);
            $table->index(['actor_id', 'created_at']);
            $table->index(['action', 'created_at']);
        });
        Schema::create('platform_settings', function (Blueprint $table): void {
            $table->id();
            $table->string('key')->unique();
            $table->json('value');
            $table->timestamps();
        });
        Schema::create('announcements', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('title');
            $table->text('message');
            $table->string('severity')->default('information');
            $table->string('status')->default('draft');
            $table->json('audience')->nullable();
            $table->timestamp('published_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();
        });
        Schema::create('password_reset_tokens', function (Blueprint $table): void {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('announcements');
        Schema::dropIfExists('platform_settings');
        Schema::dropIfExists('platform_audit_logs');
        Schema::dropIfExists('tenant_settings');
        Schema::dropIfExists('subscription_events');
        Schema::dropIfExists('subscriptions');
        Schema::dropIfExists('plan_features');
        Schema::dropIfExists('plans');
        Schema::dropIfExists('platform_permission_role');
        Schema::dropIfExists('platform_role_user');
        Schema::dropIfExists('platform_permissions');
        Schema::dropIfExists('platform_roles');
    }
};
