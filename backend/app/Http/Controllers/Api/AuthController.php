<?php

namespace App\Http\Controllers\Api;

use App\Domain\Customer\CustomerAccess;
use App\Http\Controllers\Controller;
use App\Models\ApiToken;
use App\Models\Tenant;
use App\Models\User;
use App\Services\TenantOperationalPolicy;
use App\Services\UserLifecycleService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    private const OFFLINE_SESSION_MAX_AGE_SECONDS = 43200;

    public function __construct(private readonly CustomerAccess $customerAccess) {}

    public function login(Request $request, TenantOperationalPolicy $tenantPolicy): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'email' => ['nullable', 'email'],
            'username' => ['nullable', 'string', 'max:100'],
            'password' => ['required', 'string'],
            'deviceName' => ['nullable', 'string', 'max:100'],
        ]);
        if ($validator->fails()) {
            return $this->validationFailure('AUTH_LOGIN_VALIDATION_FAILED', $validator->errors()->keys());
        }
        $data = $validator->validated();
        $hasEmail = filled($data['email'] ?? null);
        $hasUsername = filled($data['username'] ?? null);
        if ($hasEmail === $hasUsername) {
            return $this->validationFailure('AUTH_LOGIN_VALIDATION_FAILED', ['identifier']);
        }

        $identifier = $hasEmail ? mb_strtolower(trim($data['email'])) : User::normalizeUsername($data['username']);
        $rateKey = 'tenant-login:'.$request->ip().':'.$identifier;
        if (RateLimiter::tooManyAttempts($rateKey, 5)) {
            return $this->failure('LOGIN_RATE_LIMITED', 429);
        }

        $user = $hasEmail ? $this->findByEmail($identifier) : $this->findByUsername($identifier);
        if (! $user || $user->usesEmailLogin() !== $hasEmail || ! $user->is_active || $user->trashed() || ! $user->tenant || ! $tenantPolicy->allowsOperationalAccess($user->tenant) || ! Hash::check($data['password'], $user->password)) {
            RateLimiter::hit($rateKey, 60);

            return $this->failure('INVALID_CREDENTIALS', 401);
        }

        RateLimiter::clear($rateKey);
        $token = $this->issueToken(
            $user,
            filled($data['deviceName'] ?? null) ? trim($data['deviceName']) : 'frontend',
        );
        $user->forceFill(['last_login_at' => now()])->save();

        return response()->json(['data' => $this->sessionPayload($user, $user->tenant, $token)]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->sessionPayload(
            $request->attributes->get('auth_user'),
            $request->attributes->get('auth_tenant'),
            $request->attributes->get('auth_token'),
            false,
        )]);
    }

    public function changePassword(Request $request, UserLifecycleService $lifecycle): JsonResponse
    {
        /** @var User $user */
        $user = $request->attributes->get('auth_user');
        $minimum = $user->usesEmailLogin() ? 10 : 8;
        $validator = Validator::make($request->all(), [
            'currentPassword' => ['required', 'string'],
            'newPassword' => ['required', 'string', 'min:'.$minimum, 'confirmed'],
        ]);
        if ($validator->fails()) {
            return $this->validationFailure('PASSWORD_CHANGE_VALIDATION_FAILED', $validator->errors()->keys());
        }
        $data = $validator->validated();
        if (! Hash::check($data['currentPassword'], $user->password)) {
            return $this->validationFailure('INCORRECT_CURRENT_PASSWORD', ['currentPassword']);
        }

        // Preserve the Phase 1 first-password-change flow for this device, but
        // atomically revoke every other session whose password authority is
        // now stale.
        $lifecycle->changePassword(
            $user,
            $data['newPassword'],
            $request->attributes->get('auth_token'),
        );

        return response()->json(['data' => ['mustChangePassword' => false]]);
    }

    public function logout(Request $request): JsonResponse
    {
        ApiToken::query()
            ->whereKey($request->attributes->get('auth_token')->id)
            ->whereNull('revoked_at')
            ->update(['revoked_at' => now(), 'updated_at' => now()]);

        return response()->json(null, 204);
    }

    private function findByEmail(string $email): ?User
    {
        return User::query()->with(['tenant', 'tenantRole'])->whereNotNull('tenant_id')->whereRaw('LOWER(email) = ?', [$email])->first();
    }

    private function findByUsername(string $username): ?User
    {
        $users = User::query()->with(['tenant', 'tenantRole'])->whereNotNull('tenant_id')->where('normalized_username', $username)->limit(2)->get();

        // Username login is deliberately only unambiguous in today's one-cafe
        // deployment. A future Cafe Code/Tenant bootstrap will select its tenant.
        return $users->count() === 1 ? $users->first() : null;
    }

    private function issueToken(User $user, string $deviceName): ApiToken
    {
        $plainToken = rtrim(strtr(base64_encode(random_bytes(48)), '+/', '-_'), '=');
        $token = ApiToken::query()->create([
            'tenant_id' => $user->tenant_id,
            'user_id' => $user->id,
            'name' => $deviceName,
            'token_hash' => hash('sha256', $plainToken),
            'expires_at' => now()->addDays(max(1, (int) config('auth.tenant_token_ttl_days', 30))),
        ]);
        $token->setAttribute('plain_text_token', $plainToken);

        return $token;
    }

    private function sessionPayload(User $user, Tenant $tenant, ApiToken $token, bool $includeAccessToken = true): array
    {
        $data = [
            'tokenType' => 'Bearer',
            'expiresAt' => $token->expires_at?->toIso8601String(),
            'mustChangePassword' => $user->must_change_password,
            'user' => ['id' => $user->id, 'name' => $user->name, 'email' => $user->email, 'username' => $user->username, 'status' => $user->is_active ? 'active' : 'deactivated', 'role' => $user->effectiveRoleCode()],
            'tenant' => ['id' => $tenant->id, 'name' => $tenant->name, 'status' => $tenant->status],
            'capabilities' => ['customer' => ['manage' => $this->customerAccess->allowsUser($user, 'customer.manage')]],
            'session' => ['id' => $token->id, 'deviceName' => $token->name, 'authenticatedAt' => $token->created_at?->toIso8601String(), 'lastValidatedAt' => now()->toIso8601String(), 'expiresAt' => $token->expires_at?->toIso8601String(), 'offlineSessionMaxAgeSeconds' => self::OFFLINE_SESSION_MAX_AGE_SECONDS],
            'branchAccess' => ['allBranches' => $user->isOwner(), 'branchIds' => $user->isOwner() ? [] : $user->branches()->pluck('branches.id')->values()],
        ];
        if ($includeAccessToken) {
            $data['accessToken'] = $token->getAttribute('plain_text_token');
        }

        return $data;
    }

    /** @param iterable<string> $fields */
    private function validationFailure(string $code, iterable $fields): JsonResponse
    {
        $errors = [];
        foreach ($fields as $field) {
            $errors[$field] = ['Invalid authentication request.'];
        }

        return response()->json([
            'message' => 'Invalid authentication request.',
            'code' => $code,
            'errors' => $errors,
        ], 422);
    }

    private function failure(string $code, int $status): JsonResponse
    {
        return response()->json([
            'message' => $code === 'LOGIN_RATE_LIMITED' ? 'Too many login attempts.' : 'Invalid credentials.',
            'code' => $code,
        ], $status);
    }
}
