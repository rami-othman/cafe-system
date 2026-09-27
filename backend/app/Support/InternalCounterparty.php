<?php
namespace App\Support;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
final class InternalCounterparty {
    public static function values(Request $request, int $tenant, string $kind, ?int $owner, array $data): array {
        if (! array_key_exists('isInternal', $data) && ! array_key_exists('internalBranchId', $data)) return [];
        abort_unless(FinanceAccess::actor($request)->isOwner(), 403, 'المالك فقط يحدد الأطراف الداخلية.');
        if (! ($data['isInternal'] ?? false)) return ['is_internal' => false, 'internal_branch_id' => null];
        $branch = DB::table('branches')->where('tenant_id', $tenant)->where('id', $data['internalBranchId'] ?? 0)->whereNull('deleted_at')->first();
        $valid = $branch && ($kind === 'customer' ? $owner !== null && $branch->branch_type === 'cafe' : $owner === null && $branch->branch_type === 'factory') && (int) $branch->id !== $owner;
        if (! $valid) throw ValidationException::withMessages(['internalBranchId' => 'الطرف الداخلي يجب أن يمثل الفرع المقابل ضمن نطاقه الصحيح.']);
        return ['is_internal' => true, 'internal_branch_id' => (int) $branch->id];
    }
}
