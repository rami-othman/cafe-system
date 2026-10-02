<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

class FinancialAccountService
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $data, $actorId): int {
            $this->assertParent($tenantId, $data['parentAccountId'] ?? null);
            $data['code'] = $this->resolveCreateCode($tenantId, $data['code'] ?? null, $data['parentAccountId'] ?? null);
            $now = now();
            $payload = $this->payload($tenantId, $data, $actorId);
            if (Schema::hasColumn('financial_accounts', 'catalog_source')) {
                $parentId = $data['parentAccountId'] ?? null;
                $payload['catalog_source'] = $parentId
                    ? DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $parentId)->value('catalog_source')
                    : (DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('catalog_source', 'phinix')->exists() ? 'phinix' : null);
            }
            $id = (int) DB::table('financial_accounts')->insertGetId($payload + [
                'tenant_id' => $tenantId,
                'is_system_protected' => false,
                'created_by' => $actorId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $this->audit->record($request, $tenantId, 'financial_account.created', 'financial_account', $id, [], (array) $this->find($tenantId, $id), null, $actorId);

            return $id;
        });
    }

    /**
     * The code the user typed when it is free; otherwise (blank or duplicate) the next free
     * numeric code under the parent: highest sibling code + 1, or parent code + "1" for the first child.
     */
    private function resolveCreateCode(int $tenantId, ?string $requested, mixed $parentId): string
    {
        $exists = fn (string $code): bool => DB::table('financial_accounts')
            ->where('tenant_id', $tenantId)->whereRaw('UPPER(code) = ?', [strtoupper($code)])->exists();
        $requested = strtoupper(trim((string) $requested));
        if ($requested !== '' && ! $exists($requested)) {
            return $requested;
        }

        $parentCode = $parentId
            ? (string) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $parentId)->value('code')
            : '';
        $siblings = DB::table('financial_accounts')->where('tenant_id', $tenantId)
            ->when($parentId, fn ($q) => $q->where('parent_account_id', $parentId), fn ($q) => $q->whereNull('parent_account_id'))
            ->pluck('code')->filter(fn ($c) => ctype_digit((string) $c))->map(fn ($c) => (int) $c);
        $numericParent = $parentCode !== '' && ctype_digit($parentCode);

        if ($siblings->isNotEmpty()) {
            $next = $siblings->max() + 1;
        } elseif ($numericParent) {
            $next = (int) ($parentCode.'1');
        } else {
            $next = $parentCode === '' ? 1 : 1;
        }
        $prefix = ($parentCode !== '' && ! $numericParent) ? $parentCode.'-' : '';
        for ($i = 0; $i < 10000; $i++, $next++) {
            $candidate = $prefix.$next;
            if (! $exists($candidate)) {
                return $candidate;
            }
        }
        throw ValidationException::withMessages(['code' => 'تعذر توليد رمز حساب متاح.']);
    }

    public function update(Request $request, int $tenantId, int $accountId, array $data, ?int $actorId): void
    {
        $before = $this->find($tenantId, $accountId);
        if ($before->parent_account_id && (! array_key_exists('isContra', $data) || ! array_key_exists('categoryOverride', $data))) {
            $parent = $this->find($tenantId, (int) $before->parent_account_id);
            $categoryOverride = $before->account_group !== $parent->account_group;
            $baseNormal = $categoryOverride
                ? (in_array($before->account_group, ['liabilities', 'equity', 'revenue'], true) ? 'credit' : 'debit')
                : $parent->normal_balance;
            $data['isContra'] ??= $before->normal_balance !== $baseNormal;
            $data['categoryOverride'] ??= $categoryOverride;
        }
        if ($before->is_system_protected && (strtoupper($data['code']) !== $before->code || $data['accountGroup'] !== $before->account_group || $data['normalBalance'] !== $before->normal_balance)) {
            throw ValidationException::withMessages(['account' => 'لا يمكن تغيير رمز الحساب المحمي أو مجموعته أو طبيعته.']);
        }
        DB::transaction(function () use ($request, $tenantId, $accountId, $data, $actorId, $before): void {
            $this->assertParent($tenantId, $data['parentAccountId'] ?? null, $accountId);
            $payload = $this->payload($tenantId, $data, $actorId);
            if ($payload['account_group'] !== $before->account_group || $payload['normal_balance'] !== $before->normal_balance) {
                $hasChildren = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('parent_account_id', $accountId)->whereNull('deleted_at')->exists();
                $hasEntries = DB::table('journal_entry_lines')->where('tenant_id', $tenantId)->where('financial_account_id', $accountId)->exists();
                if ($hasChildren || $hasEntries) {
                    throw ValidationException::withMessages(['accountGroup' => 'لا يمكن تغيير مجموعة أو طبيعة حساب له حسابات فرعية أو قيود.']);
                }
            }
            DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->update($payload + ['updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'financial_account.updated', 'financial_account', $accountId, (array) $before, (array) $this->find($tenantId, $accountId), null, $actorId);
        });
    }

    public function setStatus(Request $request, int $tenantId, int $accountId, bool $isActive, ?int $actorId): void
    {
        $before = $this->find($tenantId, $accountId);
        if ($before->is_system_protected && ! $isActive) {
            throw ValidationException::withMessages(['isActive' => 'لا يمكن تعطيل حساب محمي.']);
        }
        DB::transaction(function () use ($request, $tenantId, $accountId, $isActive, $actorId, $before): void {
            DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->update(['is_active' => $isActive, 'updated_by' => $actorId, 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, $isActive ? 'financial_account.activated' : 'financial_account.deactivated', 'financial_account', $accountId, (array) $before, (array) $this->find($tenantId, $accountId), null, $actorId);
        });
    }

    public function find(int $tenantId, int $accountId): object
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->whereNull('deleted_at')->first();
        abort_unless($account, 404, 'الحساب المالي غير موجود.');

        return $account;
    }

    private function assertParent(int $tenantId, mixed $parentId, ?int $accountId = null): void
    {
        if (! $parentId) {
            return;
        }
        if ($accountId && (int) $parentId === $accountId) {
            throw ValidationException::withMessages(['parentAccountId' => 'لا يمكن جعل الحساب أباً لنفسه.']);
        }
        $parent = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $parentId)->whereNull('deleted_at')->first();
        if (! $parent) {
            throw ValidationException::withMessages(['parentAccountId' => 'الحساب الأب لا يتبع هذا المستأجر.']);
        }
        if (! $parent->is_active) {
            throw ValidationException::withMessages(['parentAccountId' => 'يجب أن يكون الحساب الأب نشطاً.']);
        }

        // Parent links are tenant-local and may be nested. Walk the existing
        // chain before writing so an update cannot create A -> B -> A (or a
        // longer cycle) that would make the chart hierarchy unusable.
        $visited = [];
        $cursor = (int) $parent->id;
        while ($cursor) {
            if (isset($visited[$cursor]) || ($accountId && $cursor === $accountId)) {
                throw ValidationException::withMessages(['parentAccountId' => 'اختيار هذا الحساب الأب ينشئ دورة في شجرة الحسابات.']);
            }
            $visited[$cursor] = true;
            $cursor = (int) (DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $cursor)->value('parent_account_id') ?? 0);
        }
    }

    private function payload(int $tenantId, array $data, ?int $actorId): array
    {
        $parentId = $data['parentAccountId'] ?? null;
        $parent = $parentId ? DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $parentId)->whereNull('deleted_at')->first() : null;
        if ($parentId && ! $parent) {
            throw ValidationException::withMessages(['parentAccountId' => 'الحساب الأب غير متاح.']);
        }
        if ($parent) {
            $categoryOverride = (bool) ($data['categoryOverride'] ?? false);
            if ($categoryOverride && ! isset($data['accountGroup'])) {
                throw ValidationException::withMessages(['accountGroup' => 'حدد مجموعة الحساب عند استثناء تصنيف الأب.']);
            }
            if (! $categoryOverride && isset($data['accountGroup']) && $data['accountGroup'] !== $parent->account_group) {
                throw ValidationException::withMessages(['accountGroup' => 'الحساب الفرعي يرث مجموعة الحساب الأب.']);
            }
            $isContra = (bool) ($data['isContra'] ?? false);
            $baseNormal = $categoryOverride
                ? (in_array($data['accountGroup'], ['liabilities', 'equity', 'revenue'], true) ? 'credit' : 'debit')
                : $parent->normal_balance;
            $normal = $isContra ? ($baseNormal === 'debit' ? 'credit' : 'debit') : $baseNormal;
            if (isset($data['normalBalance']) && $data['normalBalance'] !== $normal) {
                throw ValidationException::withMessages(['normalBalance' => 'طبيعة الحساب الفرعي تُشتق من الأب؛ استخدم حسابًا معاكسًا عند الحاجة.']);
            }
            $group = $categoryOverride ? $data['accountGroup'] : $parent->account_group;
        } else {
            if (! isset($data['accountGroup'], $data['normalBalance'])) {
                throw ValidationException::withMessages(['accountGroup' => 'مجموعة وطبيعة الحساب الجذري مطلوبتان.']);
            }
            if ($data['isContra'] ?? false) {
                throw ValidationException::withMessages(['isContra' => 'الحساب المعاكس يتطلب حسابًا أبًا.']);
            }
            if ($data['categoryOverride'] ?? false) {
                throw ValidationException::withMessages(['categoryOverride' => 'استثناء تصنيف الأب يتطلب حسابًا أبًا.']);
            }
            $group = $data['accountGroup'];
            $normal = $data['normalBalance'];
        }
        return [
            'parent_account_id' => $parentId,
            'code' => strtoupper($data['code']),
            'name_ar' => $data['nameAr'],
            'name_en' => $data['nameEn'],
            'account_group' => $group,
            'normal_balance' => $normal,
            'is_active' => $data['isActive'],
            'updated_by' => $actorId,
        ];
    }
}
