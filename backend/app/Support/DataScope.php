<?php

namespace App\Support;

use App\Models\User;
use App\Services\BranchAccessService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class DataScope
{
    public static function resolve(Request $request): ?int
    {
        $user = $request->attributes->get('auth_user');
        abort_unless($user instanceof User, 401);
        if ($user->effectiveRoleCode() === 'factory_manager') {
            $ids = app(BranchAccessService::class)->accessibleBranchIds($user);
            $branches = DB::table('branches')->whereIn('id', $ids)->where('branch_type', 'factory')->orderBy('id')->pluck('id');
            abort_if($branches->isEmpty(), 403, 'لا يوجد فرع معمل مسند لهذا المستخدم.');
            $requested = (int) $request->input('scopeBranchId', $request->input('branchId', 0));
            return $branches->contains($requested) ? $requested : (int) $branches->first();
        }
        if (! $user->isOwner()) return null;
        $id = $request->input('scopeBranchId', $request->input('ownerBranchId', $request->input('branchId')));
        if (! $id) return null;
        $branch = app(BranchAccessService::class)->authorize($user, (int) $id);
        return $branch->branch_type === 'factory' ? (int) $id : null;
    }

    public static function apply($query, string $column, ?int $scope): void
    {
        $scope === null ? $query->whereNull($column) : $query->where($column, $scope);
    }

    public static function assertOwned(object $row, ?int $scope): void
    {
        $owner = $row->owner_branch_id === null ? null : (int) $row->owner_branch_id;
        abort_unless($owner === $scope, 404, 'السجل غير موجود.');
    }

    public static function stamp(array $data, ?int $scope): array
    {
        $data['owner_branch_id'] = $scope;
        return $data;
    }

    public static function forBranch(int $tenant, ?int $branch): ?int
    {
        if (! $branch) return null;
        $row = DB::table('branches')->where('tenant_id', $tenant)->where('id', $branch)->whereNull('deleted_at')->first();
        abort_unless($row, 422, 'الفرع غير موجود.');
        return $row->branch_type === 'factory' ? $branch : null;
    }

    public static function assertReference(int $tenant, string $table, int $id, ?int $branch): void
    {
        $row = DB::table($table)->where('tenant_id', $tenant)->where('id', $id)->first();
        $scope = self::forBranch($tenant, $branch);
        if (! $row || ($row->owner_branch_id === null ? null : (int) $row->owner_branch_id) !== $scope) {
            throw \Illuminate\Validation\ValidationException::withMessages(['scope' => 'هذا السجل يتبع نطاقاً آخر (المعمل/المقهى).']);
        }
    }

    public static function find(Request $request, int $tenant, string $table, int $id): object
    {
        $row = DB::table($table)->where('tenant_id', $tenant)->where('id', $id)->first();
        abort_unless($row, 404, 'السجل غير موجود.');
        self::assertOwned($row, self::resolve($request));
        return $row;
    }

    public static function documentNumber(int $tenant, ?int $branch, string $number): string
    {
        return self::forBranch($tenant, $branch) === null ? $number : 'F'.$branch.'-'.$number;
    }
}
