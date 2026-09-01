<?php

namespace App\Http\Middleware;

use App\Models\ApiToken;
use App\Services\TenantOperationalPolicy;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateApiToken
{
    public function __construct(private readonly TenantOperationalPolicy $tenantPolicy) {}

    public function handle(Request $request, Closure $next): Response
    {
        $plainToken = $request->bearerToken();
        if (! $plainToken) {
            return $this->failure('AUTH_REQUIRED');
        }

        $token = ApiToken::query()->with(['user.tenant', 'user.tenantRole'])->where('token_hash', hash('sha256', $plainToken))->first();
        if (! $token || ! $token->tenant_id || ! $token->user || ! $token->user->tenant || (int) $token->tenant_id !== (int) $token->user->tenant_id) {
            return $this->failure('AUTH_REQUIRED');
        }
        if ($token->revoked_at) {
            return $this->failure('TOKEN_REVOKED');
        }
        if ($token->expires_at && $token->expires_at->isPast()) {
            return $this->failure('TOKEN_EXPIRED');
        }
        if (! $token->user->is_active || $token->user->trashed()) {
            return $this->failure('AUTH_SESSION_INVALID');
        }
        if (! $this->tenantPolicy->allowsOperationalAccess($token->user->tenant)) {
            return response()->json(['message' => 'Tenant is not operational.', 'code' => 'TENANT_NOT_OPERATIONAL'], 403);
        }

        if (! $token->last_used_at || $token->last_used_at->lt(now()->subMinutes(5))) {
            $token->forceFill(['last_used_at' => now()])->save();
        }
        $request->attributes->set('tenant_id', (int) $token->tenant_id);
        $request->attributes->set('tenant_context_protected', true);
        $request->attributes->set('auth_user', $token->user);
        $request->attributes->set('auth_tenant', $token->user->tenant);
        $request->attributes->set('auth_token', $token);

        return $next($request);
    }

    private function failure(string $code): Response
    {
        return response()->json(['message' => 'Unauthenticated.', 'code' => $code], 401);
    }
}
