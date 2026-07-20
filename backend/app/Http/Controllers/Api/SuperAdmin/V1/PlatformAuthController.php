<?php

namespace App\Http\Controllers\Api\SuperAdmin\V1;

use App\Http\Controllers\Controller;
use App\Services\SuperAdmin\PlatformAccessService;
use App\Services\SuperAdmin\PlatformAuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;

class PlatformAuthController extends Controller
{
    public function csrf(Request $request): JsonResponse
    {
        $request->session()->regenerateToken();

        return response()->json(['data' => ['csrfToken' => csrf_token()]]);
    }

    public function login(Request $request, PlatformAccessService $access, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['email' => ['required', 'email'], 'password' => ['required', 'string']]);
        $key = 'super-admin-login:'.$request->ip().':'.mb_strtolower($data['email']);
        if (RateLimiter::tooManyAttempts($key, 5)) {
            return response()->json(['message' => 'Invalid credentials.'], 429);
        }
        if (! Auth::attempt(['email' => $data['email'], 'password' => $data['password'], 'is_active' => true])) {
            RateLimiter::hit($key, 60);
            $audit->record($request, 'platform.login.failed');

            return response()->json(['message' => 'Invalid credentials.'], 401);
        }
        $request->session()->regenerate();
        $user = $request->user();
        if (! $access->isPlatformAdmin($user)) {
            Auth::logout();
            $request->session()->invalidate();
            RateLimiter::hit($key, 60);

            return response()->json(['message' => 'Invalid credentials.'], 401);
        }
        RateLimiter::clear($key);
        $user->forceFill(['last_login_at' => now()])->save();
        $audit->record($request, 'platform.login.success', 'user', $user->id);

        return response()->json(['data' => $this->user($user, $access)]);
    }

    public function me(Request $request, PlatformAccessService $access): JsonResponse
    {
        return response()->json(['data' => $this->user($request->user(), $access)]);
    }

    public function logout(Request $request, PlatformAuditService $audit): JsonResponse
    {
        $audit->record($request, 'platform.logout', 'user', $request->user()->id);
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return response()->json(['data' => null]);
    }

    private function user($user, PlatformAccessService $access): array
    {
        return ['id' => $user->id, 'name' => $user->name, 'email' => $user->email, 'roles' => DB::table('platform_role_user')->join('platform_roles', 'platform_roles.id', '=', 'platform_role_user.platform_role_id')->where('platform_role_user.user_id', $user->id)->pluck('platform_roles.code')->values(), 'permissions' => collect(DB::table('platform_permissions')->pluck('key'))->filter(fn ($key) => $access->hasPermission($user, $key))->values()];
    }
}
