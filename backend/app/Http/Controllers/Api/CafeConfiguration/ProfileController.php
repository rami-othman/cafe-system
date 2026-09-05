<?php

namespace App\Http\Controllers\Api\CafeConfiguration;

use App\Http\Controllers\Controller;
use App\Http\Requests\CafeConfiguration\UpdateProfileRequest;
use App\Http\Resources\CafeConfiguration\ProfileResource;
use App\Models\Tenant;
use App\Support\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;

class ProfileController extends Controller
{
    public function show(Request $request): ProfileResource
    {
        return new ProfileResource($this->tenant($request));
    }

    public function update(UpdateProfileRequest $request): ProfileResource
    {
        $tenant = $this->tenant($request);
        // Tenant is intentionally unguarded for legacy reasons. Keep this
        // explicit allowlist at the API boundary instead of mass assigning.
        DB::transaction(function () use ($tenant, $request): void {
            $tenant->update([
                'name' => $request->validated('name'),
                'timezone' => $request->validated('timezone'),
                ...Arr::only($request->validated(), ['email', 'phone']),
            ]);
        });

        return new ProfileResource($tenant->fresh());
    }

    private function tenant(Request $request): Tenant
    {
        return Tenant::query()->findOrFail(TenantContext::id($request));
    }
}
