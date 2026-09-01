<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use App\Support\FinanceAccess;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'deviceName' => ['nullable', 'string', 'max:100'],
        ]);

        $user = DB::table('users')
            ->where('email', $data['email'])
            ->whereNull('deleted_at')
            ->first();

        if (! $user || ! $user->is_active || ! Hash::check($data['password'], $user->password)) {
            return response()->json(['message' => 'Invalid credentials.'], 401);
        }

        $plainToken = Str::random(80);
        $expiresAt = now()->addDays(30);

        DB::table('api_tokens')->insert([
            'tenant_id' => $user->tenant_id,
            'user_id' => $user->id,
            'name' => $data['deviceName'] ?? 'frontend',
            'token_hash' => hash('sha256', $plainToken),
            'expires_at' => $expiresAt,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('users')->where('id', $user->id)->update(['last_login_at' => now()]);

        return response()->json([
            'data' => [
                'token' => $plainToken,
                'tokenType' => 'Bearer',
                'expiresAt' => $expiresAt->toISOString(),
                'user' => $this->userPayload($user),
            ],
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'data' => [
                'tenantId' => TenantContext::id($request),
                'user' => $request->attributes->get('auth_user'),
                'financeCapabilities' => FinanceAccess::capabilities($request),
            ],
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $plainToken = $request->bearerToken();

        if ($plainToken) {
            DB::table('api_tokens')->where('token_hash', hash('sha256', $plainToken))->delete();
        }

        return response()->json(null, 204);
    }

    private function userPayload(object $user): array
    {
        return [
            'id' => $user->id,
            'tenantId' => $user->tenant_id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
        ];
    }
}
