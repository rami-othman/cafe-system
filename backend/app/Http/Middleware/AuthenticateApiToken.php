<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateApiToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $plainToken = $request->bearerToken();

        if (! $plainToken) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $token = DB::table('api_tokens')
            ->join('users', 'users.id', '=', 'api_tokens.user_id')
            ->where('api_tokens.token_hash', hash('sha256', $plainToken))
            ->where(fn ($query) => $query->whereNull('api_tokens.expires_at')->orWhere('api_tokens.expires_at', '>', now()))
            ->whereNull('users.deleted_at')
            ->select([
                'api_tokens.id',
                'api_tokens.tenant_id',
                'api_tokens.user_id',
                'users.name',
                'users.email',
                'users.role',
            ])
            ->first();

        if (! $token) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        DB::table('api_tokens')->where('id', $token->id)->update(['last_used_at' => now()]);

        $request->attributes->set('tenant_id', (int) $token->tenant_id);
        $request->attributes->set('auth_user', [
            'id' => (int) $token->user_id,
            'name' => $token->name,
            'email' => $token->email,
            'role' => $token->role,
        ]);

        return $next($request);
    }
}
