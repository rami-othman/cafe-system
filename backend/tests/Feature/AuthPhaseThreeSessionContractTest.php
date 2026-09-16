<?php

namespace Tests\Feature;

use App\Models\ApiToken;
use App\Models\Tenant;
use App\Models\User;
use App\Services\UserLifecycleService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use RuntimeException;
use Tests\TestCase;

class AuthPhaseThreeSessionContractTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_and_me_share_the_strict_session_contract_without_repeating_the_access_token(): void
    {
        $user = $this->user();
        $login = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'OwnerPassword',
            'deviceName' => 'Phase 3 test',
        ])->assertOk()->assertJsonStructure([
            'data' => [
                'accessToken', 'tokenType', 'expiresAt', 'mustChangePassword',
                'user' => ['id', 'name', 'email', 'username', 'status', 'role'],
                'tenant' => ['id', 'name', 'status'],
                'capabilities' => ['customer' => ['manage']],
                'session' => ['id', 'deviceName', 'authenticatedAt', 'lastValidatedAt', 'expiresAt', 'offlineSessionMaxAgeSeconds'],
                'branchAccess' => ['allBranches', 'branchIds'],
            ],
        ]);

        $token = $login->json('data.accessToken');
        $me = $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk()
            ->assertJsonPath('data.tokenType', 'Bearer')
            ->assertJsonPath('data.user.id', $user->id)
            ->assertJsonPath('data.session.expiresAt', $login->json('data.expiresAt'))
            ->assertJsonPath('data.expiresAt', $login->json('data.expiresAt'));

        $this->assertArrayNotHasKey('accessToken', $me->json('data'));
        $this->assertIsInt($me->json('data.user.id'));
        $this->assertIsBool($me->json('data.mustChangePassword'));
        $this->assertIsInt($me->json('data.session.offlineSessionMaxAgeSeconds'));
        $this->assertTrue($me->json('data.session.offlineSessionMaxAgeSeconds') > 0);
    }

    public function test_invalid_bearer_forms_share_the_safe_session_invalid_response(): void
    {
        $user = $this->user();
        $valid = $this->login($user);
        $expired = $this->login($user);
        $revoked = $this->login($user);
        ApiToken::query()->where('token_hash', hash('sha256', $expired))->update(['expires_at' => now()->subSecond()]);
        ApiToken::query()->where('token_hash', hash('sha256', $revoked))->update(['revoked_at' => now()]);

        $this->withToken($valid)->getJson('/api/v1/auth/me')->assertOk();
        foreach ([$expired, $revoked, 'malformed-bearer-token', 'unknown-bearer-token'] as $token) {
            $this->withToken($token)->getJson('/api/v1/auth/me')
                ->assertUnauthorized()
                ->assertExactJson([
                    'message' => 'Unauthenticated.',
                    'code' => 'AUTH_SESSION_INVALID',
                ]);
        }
        $this->flushHeaders()->getJson('/api/v1/auth/me')
            ->assertUnauthorized()
            ->assertJsonPath('code', 'AUTH_REQUIRED');
    }

    public function test_logout_is_idempotent_for_the_current_revoked_token(): void
    {
        $token = $this->login($this->user());

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();
        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();
        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertUnauthorized()
            ->assertJsonPath('code', 'AUTH_SESSION_INVALID');
    }

    public function test_tenant_and_employee_lifecycle_remain_server_authoritative(): void
    {
        $user = $this->user();
        $token = $this->login($user);
        $user->tenant->update(['status' => 'suspended']);
        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertForbidden()
            ->assertExactJson([
                'message' => 'Tenant access is unavailable.',
                'code' => 'TENANT_NOT_OPERATIONAL',
            ]);
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'OwnerPassword'])
            ->assertUnauthorized()
            ->assertJsonPath('code', 'INVALID_CREDENTIALS');

        $user->tenant->update(['status' => 'active']);
        app(UserLifecycleService::class)->deactivate($user);
        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertUnauthorized()
            ->assertJsonPath('code', 'AUTH_SESSION_INVALID');
    }

    public function test_password_change_preserves_the_current_session_and_revokes_other_sessions(): void
    {
        $user = $this->user();
        $user->forceFill(['must_change_password' => true])->save();
        $current = $this->login($user);
        $other = $this->login($user);
        $currentToken = ApiToken::query()->where('token_hash', hash('sha256', $current))->firstOrFail();
        $otherToken = ApiToken::query()->where('token_hash', hash('sha256', $other))->firstOrFail();

        $this->withToken($current)->postJson('/api/v1/auth/change-password', [
            'currentPassword' => 'OwnerPassword',
            'newPassword' => 'ChangedOwner',
            'newPassword_confirmation' => 'ChangedOwner',
        ])->assertOk()->assertJsonPath('data.mustChangePassword', false);

        $user->refresh();
        $this->assertFalse($user->must_change_password);
        $this->assertTrue(Hash::check('ChangedOwner', $user->password));
        $this->assertNull($currentToken->fresh()->revoked_at);
        $this->assertNotNull($otherToken->fresh()->revoked_at);
        $this->withToken($current)->getJson('/api/v1/auth/me')->assertOk();
        $this->withToken($other)->getJson('/api/v1/auth/me')
            ->assertUnauthorized()
            ->assertJsonPath('code', 'AUTH_SESSION_INVALID');
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'OwnerPassword'])
            ->assertUnauthorized()
            ->assertJsonPath('code', 'INVALID_CREDENTIALS');
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'ChangedOwner'])->assertOk();
    }

    public function test_password_change_rolls_back_when_other_session_revocation_fails(): void
    {
        $user = $this->user();
        $user->forceFill(['must_change_password' => true])->save();
        $current = $this->login($user);
        $other = $this->login($user);
        $currentToken = ApiToken::query()->where('token_hash', hash('sha256', $current))->firstOrFail();
        $otherToken = ApiToken::query()->where('token_hash', hash('sha256', $other))->firstOrFail();

        $this->app->instance(UserLifecycleService::class, new class extends UserLifecycleService
        {
            public function revokeAllUserTokensExcept(User $user, ApiToken $currentToken): void
            {
                throw new RuntimeException('Forced token revocation failure.');
            }
        });

        try {
            $this->withoutExceptionHandling();
            $this->withToken($current)->postJson('/api/v1/auth/change-password', [
                'currentPassword' => 'OwnerPassword',
                'newPassword' => 'ChangedOwner',
                'newPassword_confirmation' => 'ChangedOwner',
            ]);
            $this->fail('The forced revocation failure was not propagated.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Forced token revocation failure.', $exception->getMessage());
        }

        $user->refresh();
        $this->assertTrue($user->must_change_password);
        $this->assertTrue(Hash::check('OwnerPassword', $user->password));
        $this->assertFalse(Hash::check('ChangedOwner', $user->password));
        $this->assertNull($currentToken->fresh()->revoked_at);
        $this->assertNull($otherToken->fresh()->revoked_at);
    }

    public function test_auth_failures_have_stable_safe_codes_without_sensitive_details(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'not-an-email',
            'username' => 'also-supplied',
        ])->assertUnprocessable()->assertExactJson([
            'message' => 'Invalid authentication request.',
            'code' => 'AUTH_LOGIN_VALIDATION_FAILED',
            'errors' => [
                'email' => ['Invalid authentication request.'],
                'password' => ['Invalid authentication request.'],
            ],
        ]);

        $this->assertStringNotContainsString('exception', strtolower($response->getContent()));
        $this->assertStringNotContainsString('sql', strtolower($response->getContent()));
    }

    private function user(): User
    {
        $tenant = Tenant::query()->create([
            'name' => 'Phase 3 Cafe',
            'slug' => 'phase-3-'.uniqid(),
            'status' => 'active',
        ]);

        return User::query()->create([
            'tenant_id' => $tenant->id,
            'name' => 'Phase 3 Manager',
            'email' => 'manager-'.uniqid().'@example.test',
            'password' => Hash::make('OwnerPassword'),
            'role' => 'manager',
            'is_active' => true,
            'must_change_password' => false,
        ]);
    }

    private function login(User $user): string
    {
        return $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'OwnerPassword',
        ])->assertOk()->json('data.accessToken');
    }
}
