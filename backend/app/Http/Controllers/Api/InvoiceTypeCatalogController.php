<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class InvoiceTypeCatalogController extends Controller
{
    public function groups(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        return response()->json(['data' => DB::table('invoice_groups')->where('tenant_id', $tenant)->orderBy('name')->get()->map(fn (object $row) => $this->group($row))->values()]);
    }

    public function storeGroup(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $this->groupData($request, $tenant);
        $id = (int) DB::table('invoice_groups')->insertGetId($data + ['tenant_id' => $tenant, 'created_at' => now(), 'updated_at' => now()]);
        return response()->json(['data' => $this->group(DB::table('invoice_groups')->find($id))], 201);
    }

    public function updateGroup(Request $request, int $group): JsonResponse
    {
        $tenant = TenantContext::id($request);
        abort_unless(DB::table('invoice_groups')->where('tenant_id', $tenant)->where('id', $group)->exists(), 404);
        DB::table('invoice_groups')->where('tenant_id', $tenant)->where('id', $group)->update($this->groupData($request, $tenant, $group) + ['updated_at' => now()]);
        return response()->json(['data' => $this->group(DB::table('invoice_groups')->find($group))]);
    }

    public function types(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $query = DB::table('invoice_types as t')->join('invoice_groups as g', 'g.id', '=', 't.invoice_group_id')
            ->where('t.tenant_id', $tenant)->where('g.tenant_id', $tenant);
        if ($request->filled('groupId')) $query->where('t.invoice_group_id', (int) $request->input('groupId'));
        if ($request->boolean('activeOnly')) $query->where('t.is_active', true)->where('g.is_active', true);
        return response()->json(['data' => $query->orderBy('g.name')->orderBy('t.name')->select('t.*', 'g.code as group_code', 'g.name as group_name', 'g.is_active as group_is_active')->get()->map(fn (object $row) => $this->type($row))->values()]);
    }

    public function storeType(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $this->typeData($request, $tenant);
        $id = (int) DB::table('invoice_types')->insertGetId($data + ['tenant_id' => $tenant, 'created_at' => now(), 'updated_at' => now()]);
        return response()->json(['data' => $this->typeRow($tenant, $id)], 201);
    }

    public function updateType(Request $request, int $type): JsonResponse
    {
        $tenant = TenantContext::id($request);
        abort_unless(DB::table('invoice_types')->where('tenant_id', $tenant)->where('id', $type)->exists(), 404);
        DB::table('invoice_types')->where('tenant_id', $tenant)->where('id', $type)->update($this->typeData($request, $tenant, $type) + ['updated_at' => now()]);
        return response()->json(['data' => $this->typeRow($tenant, $type)]);
    }

    private function groupData(Request $request, int $tenant, ?int $ignore = null): array
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'max:40', 'regex:/^[a-z0-9_-]+$/', Rule::unique('invoice_groups', 'code')->where('tenant_id', $tenant)->ignore($ignore)],
            'name' => ['required', 'string', 'max:120'], 'description' => ['nullable', 'string', 'max:1000'], 'isActive' => ['sometimes', 'boolean'],
        ]);
        $active = array_key_exists('isActive', $data)
            ? (bool) $data['isActive']
            : ($ignore ? (bool) DB::table('invoice_groups')->where('tenant_id', $tenant)->where('id', $ignore)->value('is_active') : true);
        return ['code' => $data['code'], 'name' => $data['name'], 'description' => $data['description'] ?? null, 'is_active' => $active];
    }

    private function typeData(Request $request, int $tenant, ?int $ignore = null): array
    {
        $data = $request->validate([
            'groupId' => ['required', 'integer'], 'code' => ['required', 'string', 'max:40', 'regex:/^[a-z0-9_-]+$/', Rule::unique('invoice_types', 'code')->where('tenant_id', $tenant)->ignore($ignore)],
            'name' => ['required', 'string', 'max:120'], 'postingBehavior' => ['required', Rule::in(['expense', 'inventory', 'other', 'none'])],
            'isPostable' => ['required', 'boolean'], 'isActive' => ['sometimes', 'boolean'], 'isPurchase' => ['sometimes', 'boolean'],
        ]);
        abort_unless(DB::table('invoice_groups')->where('tenant_id', $tenant)->where('id', $data['groupId'])->exists(), 422, 'Select a group belonging to this tenant.');
        if ($data['postingBehavior'] === 'none' && $data['isPostable']) abort(422, 'A non-financial invoice type cannot be postable.');
        $active = array_key_exists('isActive', $data)
            ? (bool) $data['isActive']
            : ($ignore ? (bool) DB::table('invoice_types')->where('tenant_id', $tenant)->where('id', $ignore)->value('is_active') : true);
        $isPurchase = array_key_exists('isPurchase', $data)
            ? (bool) $data['isPurchase']
            : ($ignore ? (bool) DB::table('invoice_types')->where('tenant_id', $tenant)->where('id', $ignore)->value('is_purchase') : $data['postingBehavior'] !== 'none');
        return ['invoice_group_id' => $data['groupId'], 'code' => $data['code'], 'name' => $data['name'], 'posting_behavior' => $data['postingBehavior'], 'is_postable' => $data['isPostable'], 'is_active' => $active, 'is_purchase' => $isPurchase];
    }

    private function group(object $row): array { return ['id' => (int) $row->id, 'code' => $row->code, 'name' => $row->name, 'description' => $row->description, 'isActive' => (bool) $row->is_active]; }
    private function typeRow(int $tenant, int $id): array { return $this->type(DB::table('invoice_types as t')->join('invoice_groups as g', 'g.id', '=', 't.invoice_group_id')->where('t.tenant_id', $tenant)->where('t.id', $id)->select('t.*', 'g.code as group_code', 'g.name as group_name', 'g.is_active as group_is_active')->first()); }
    private function type(object $row): array { return ['id' => (int) $row->id, 'groupId' => (int) $row->invoice_group_id, 'groupCode' => $row->group_code, 'groupName' => $row->group_name, 'code' => $row->code, 'name' => $row->name, 'postingBehavior' => $row->posting_behavior, 'isPostable' => (bool) $row->is_postable, 'isActive' => (bool) $row->is_active, 'isPurchase' => (bool) $row->is_purchase, 'groupIsActive' => (bool) $row->group_is_active]; }
}
