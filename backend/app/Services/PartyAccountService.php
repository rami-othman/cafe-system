<?php

namespace App\Services;

use App\Domain\Customer\CustomerNameNormalizer;
use App\Domain\Customer\CustomerNumberGenerator;
use App\Support\ArabicSearch;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

/**
 * One person record and ONE ledger account, whatever roles the person has.
 *
 * A supplier is always also a customer record (so it can be sold to from the
 * POS / sales invoices), but it never gets a second account:
 *  - a customer-only person has its account under the receivables parent (121 / 1200);
 *  - the moment a person is (or becomes) a supplier its single account lives under
 *    the suppliers parent (223 / 2000). Purchases credit it, sales to the same person
 *    debit it, so the account shows the net position (reports present a debit
 *    balance as an asset and a credit balance as a liability).
 */
final class PartyAccountService
{
    /** Receivables parents, in order of preference. */
    private const CUSTOMER_PARENTS = ['121', '1200'];

    /** Payables (suppliers) parents, in order of preference. */
    private const SUPPLIER_PARENTS = ['223', '2000'];

    public function __construct(private readonly CustomerNumberGenerator $numbers) {}

    public function ensureForCustomer(int $tenantId, int $customerId, ?int $actorId = null): int
    {
        return DB::transaction(function () use ($tenantId, $customerId, $actorId): int {
            $customer = DB::table('customers')->where('tenant_id', $tenantId)
                ->where('id', $customerId)->lockForUpdate()->first();
            abort_unless($customer, 404, 'Customer not found.');
            if ($customer->is_walk_in ?? false) {
                throw ValidationException::withMessages(['customerId' => 'العميل النقدي العام لا يحتاج إلى حساب شخصي.']);
            }
            $supplierId = $this->supplierIdForCustomer($tenantId, $customerId);
            $current = $customer->financial_account_id
                ? DB::table('financial_accounts')->where('tenant_id', $tenantId)
                    ->where('id', $customer->financial_account_id)->whereNull('deleted_at')->lockForUpdate()->first()
                : null;

            if ($current) {
                return $supplierId ? $this->homeUnderSuppliers($tenantId, $customer, $current) : (int) $current->id;
            }

            $accountId = $supplierId
                ? ($this->adoptImportedSupplierAccount($tenantId, $customer) ?? $this->createAccount(
                    $tenantId, $this->supplierParent($tenantId), 'S'.$supplierId, $customer->name, $actorId,
                ))
                : $this->createAccount($tenantId, $this->customerParent($tenantId), 'P'.$customerId, $customer->name, $actorId);
            DB::table('customers')->where('id', $customerId)->update([
                'financial_account_id' => $accountId, 'updated_at' => now(),
            ]);

            return $accountId;
        });
    }

    public function codeForCustomer(int $tenantId, int $customerId, ?int $actorId = null): string
    {
        $accountId = $this->ensureForCustomer($tenantId, $customerId, $actorId);

        return (string) DB::table('financial_accounts')->where('id', $accountId)->value('code');
    }

    /**
     * The customer's wallet: funds held for them (credit balance on their single account) plus the owner-set credit limit.
     * available = funds + limit; a wallet payment may not exceed it. A limit of 0 means unlimited.
     *
     * @return array{fundsCents:int,limitCents:int,availableCents:int}
     */
    public function walletState(int $tenantId, int $customerId, bool $lock = false): array
    {
        $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $customerId)
            ->when($lock, fn ($q) => $q->lockForUpdate())->first(['financial_account_id', 'wallet_credit_limit']);
        $net = 0;
        if ($customer && $customer->financial_account_id) {
            $row = DB::table('journal_entry_lines as l')->join('journal_entries as e', 'e.id', '=', 'l.journal_entry_id')
                ->where('l.tenant_id', $tenantId)->where('e.status', 'posted')
                ->where('l.financial_account_id', $customer->financial_account_id)
                ->selectRaw('COALESCE(SUM(l.debit),0) as debit, COALESCE(SUM(l.credit),0) as credit')->first();
            $net = \App\Support\Money::cents((string) $row->debit) - \App\Support\Money::cents((string) $row->credit);
        }
        $funds = -$net;
        $limit = $customer ? \App\Support\Money::cents((string) ($customer->wallet_credit_limit ?? '0')) : 0;

        // Limit 0 = no limit (the wallet may go as far into debt as needed). A positive limit caps the debt at that amount.
        $unlimited = $limit <= 0;

        return ['fundsCents' => $funds, 'limitCents' => $limit, 'unlimited' => $unlimited,
            'availableCents' => $unlimited ? 10_000_000_000_000 : $funds + $limit];
    }

    /**
     * Wallet funds (same derivation as walletState) for many customers in one query, for list screens.
     *
     * @param  list<int>  $customerIds
     * @return array<int,int> customer id => funds in cents (0 when the customer has no account yet)
     */
    public function walletFundsCents(int $tenantId, array $customerIds): array
    {
        $funds = array_fill_keys($customerIds, 0);
        if ($customerIds === []) {
            return $funds;
        }
        $rows = DB::table('customers as c')
            ->join('journal_entry_lines as l', 'l.financial_account_id', '=', 'c.financial_account_id')
            ->join('journal_entries as e', 'e.id', '=', 'l.journal_entry_id')
            ->where('c.tenant_id', $tenantId)->whereIn('c.id', $customerIds)
            ->where('l.tenant_id', $tenantId)->where('e.status', 'posted')
            ->groupBy('c.id')
            ->selectRaw('c.id as customer_id, COALESCE(SUM(l.debit),0) as debit, COALESCE(SUM(l.credit),0) as credit')->get();
        foreach ($rows as $row) {
            $funds[(int) $row->customer_id] = \App\Support\Money::cents((string) $row->credit) - \App\Support\Money::cents((string) $row->debit);
        }

        return $funds;
    }

    /**
     * Account code of the person on a POS order/refund, or null for anonymous / walk-in / inactive
     * customers. The sale is then also recorded on the person's own account (sale + collection)
     * so every purchase appears in that person's ledger even though it was paid at the till.
     */
    public function codeForOrderCustomer(int $tenantId, mixed $customerId, ?int $actorId = null): ?string
    {
        if (! $customerId) {
            return null;
        }
        $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $customerId)
            ->where('is_active', true)->whereNull('deleted_at')->first(['id', 'is_walk_in']);
        if (! $customer || ($customer->is_walk_in ?? false)) {
            return null;
        }

        return $this->codeForCustomer($tenantId, (int) $customer->id, $actorId);
    }

    /** The customer record behind a supplier (created on demand) — its account is created under the suppliers parent. */
    public function customerForSupplier(int $tenantId, int $supplierId, ?int $actorId = null): int
    {
        return DB::transaction(function () use ($tenantId, $supplierId, $actorId): int {
            $supplier = DB::table('suppliers')->where('tenant_id', $tenantId)->where('id', $supplierId)
                ->lockForUpdate()->first();
            abort_unless($supplier, 404, 'Supplier not found.');
            if (! $supplier->customer_id) {
                $name = CustomerNameNormalizer::normalize($supplier->name);
                $customerId = (int) DB::table('customers')->insertGetId([
                    'tenant_id' => $tenantId, 'owner_branch_id' => $supplier->owner_branch_id,
                    'customer_number' => $this->numbers->next($tenantId),
                    'name' => $name['displayName'], 'normalized_name' => $name['normalizedName'],
                    'phone' => $supplier->phone, 'email' => $supplier->email,
                    'customer_type' => 'registered', 'is_walk_in' => false,
                    'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
                ]);
                // Link first: the account is placed by the person's roles.
                DB::table('suppliers')->where('id', $supplierId)->update(['customer_id' => $customerId, 'updated_at' => now()]);
                $supplier->customer_id = $customerId;
            }
            // Also re-homes an account that was created before the person became a supplier.
            $this->ensureForCustomer($tenantId, (int) $supplier->customer_id, $actorId);

            return (int) $supplier->customer_id;
        });
    }

    public function codeForSupplier(int $tenantId, int $supplierId, ?int $actorId = null): string
    {
        return $this->codeForCustomer($tenantId, $this->customerForSupplier($tenantId, $supplierId, $actorId), $actorId);
    }

    /**
     * Data repair: give every supplier exactly one account under the suppliers
     * parent (moving old receivable-side accounts, adopting imported duplicates).
     *
     * @return int number of suppliers whose account had to be fixed
     */
    public function consolidateSuppliers(int $tenantId, bool $apply = true): int
    {
        $fixed = 0;
        $suppliers = DB::table('suppliers')->where('tenant_id', $tenantId)->whereNull('deleted_at')->get(['id', 'customer_id']);
        foreach ($suppliers as $supplier) {
            $customer = $supplier->customer_id
                ? DB::table('customers')->where('tenant_id', $tenantId)->where('id', $supplier->customer_id)->first(['financial_account_id'])
                : null;
            $account = $customer?->financial_account_id
                ? DB::table('financial_accounts')->where('id', $customer->financial_account_id)->whereNull('deleted_at')->first()
                : null;
            $parent = $this->supplierParent($tenantId);
            if ($account && $this->isDescendantOf($tenantId, $account, (int) $parent->id)) {
                continue;
            }
            $fixed++;
            if ($apply) {
                $this->customerForSupplier($tenantId, (int) $supplier->id);
            }
        }

        return $fixed;
    }

    private function supplierIdForCustomer(int $tenantId, int $customerId): ?int
    {
        $id = DB::table('suppliers')->where('tenant_id', $tenantId)->where('customer_id', $customerId)
            ->whereNull('deleted_at')->value('id');

        return $id ? (int) $id : null;
    }

    private function customerParent(int $tenantId): object
    {
        $parent = $this->firstActive($tenantId, self::CUSTOMER_PARENTS);
        if ($parent) {
            return $parent;
        }
        $id = DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $tenantId, 'code' => '1200', 'name_ar' => 'حسابات الأشخاص',
            'name_en' => 'Party accounts', 'account_group' => 'assets',
            'normal_balance' => 'debit', 'is_active' => true, 'is_system_protected' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return DB::table('financial_accounts')->where('id', $id)->first();
    }

    private function supplierParent(int $tenantId): object
    {
        $parent = $this->firstActive($tenantId, self::SUPPLIER_PARENTS);
        if ($parent) {
            return $parent;
        }
        $id = DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $tenantId, 'code' => '2000', 'name_ar' => 'الذمم الدائنة – الموردون',
            'name_en' => 'Accounts Payable', 'account_group' => 'liabilities',
            'normal_balance' => 'credit', 'is_active' => true, 'is_system_protected' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return DB::table('financial_accounts')->where('id', $id)->first();
    }

    /** @param list<string> $codes in order of preference */
    private function firstActive(int $tenantId, array $codes): ?object
    {
        $found = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereIn('code', $codes)
            ->whereNull('deleted_at')->where('is_active', true)->get()->keyBy('code');
        foreach ($codes as $code) {
            if ($found->has($code)) {
                return $found->get($code);
            }
        }

        return null;
    }

    private function createAccount(int $tenantId, object $parent, string $code, string $name, ?int $actorId): int
    {
        $payload = [
            'tenant_id' => $tenantId, 'parent_account_id' => $parent->id,
            'code' => $code, 'name_ar' => $name,
            'name_en' => $name, 'account_group' => $parent->account_group,
            'normal_balance' => $parent->normal_balance, 'is_active' => true,
            'is_system_protected' => true, 'created_by' => $actorId,
            'created_at' => now(), 'updated_at' => now(),
        ];
        if (Schema::hasColumn('financial_accounts', 'catalog_source')) {
            $payload['catalog_source'] = $parent->catalog_source;
        }

        return (int) DB::table('financial_accounts')->insertGetId($payload);
    }

    /**
     * A person that is (or just became) a supplier keeps ONE account, under the suppliers parent.
     * If an imported catalog account with the same name already sits there, that one is adopted
     * (all postings move to it) instead of leaving two accounts for one person.
     */
    private function homeUnderSuppliers(int $tenantId, object $customer, object $account): int
    {
        $parent = $this->supplierParent($tenantId);
        if ($this->isDescendantOf($tenantId, $account, (int) $parent->id)) {
            return (int) $account->id;
        }
        $adopted = $this->adoptImportedSupplierAccount($tenantId, $customer);
        if ($adopted) {
            foreach (['journal_entry_lines', 'finance_document_lines'] as $table) {
                DB::table($table)->where('tenant_id', $tenantId)->where('financial_account_id', $account->id)
                    ->update(['financial_account_id' => $adopted]);
            }
            DB::table('customers')->where('id', $customer->id)->update(['financial_account_id' => $adopted, 'updated_at' => now()]);
            DB::table('financial_accounts')->where('id', $account->id)->update([
                'is_active' => false, 'deleted_at' => now(), 'updated_at' => now(),
            ]);

            return $adopted;
        }
        // No duplicate to adopt: move the account itself. Postings stay valid — only the
        // presentation (group / normal balance) becomes the supplier one.
        $update = [
            'parent_account_id' => $parent->id, 'account_group' => $parent->account_group,
            'normal_balance' => $parent->normal_balance, 'is_active' => true, 'updated_at' => now(),
        ];
        if (Schema::hasColumn('financial_accounts', 'catalog_source')) {
            $update['catalog_source'] = $parent->catalog_source;
        }
        DB::table('financial_accounts')->where('id', $account->id)->update($update);

        return (int) $account->id;
    }

    /** An unused imported account under the suppliers parent whose (normalised) name equals the person's. */
    private function adoptImportedSupplierAccount(int $tenantId, object $customer): ?int
    {
        if (! Schema::hasColumn('financial_accounts', 'catalog_source')) {
            return null;
        }
        $parent = $this->supplierParent($tenantId);
        $wanted = ArabicSearch::normalize((string) $customer->name);
        if ($wanted === '') {
            return null;
        }
        $candidates = DB::table('financial_accounts')->where('tenant_id', $tenantId)
            ->where('parent_account_id', $parent->id)->whereNotNull('catalog_source')->whereNull('deleted_at')
            ->where('is_system_protected', false)->orderBy('id')->get(['id', 'name_ar']);
        foreach ($candidates as $candidate) {
            if (ArabicSearch::normalize((string) $candidate->name_ar) !== $wanted) {
                continue;
            }
            $used = DB::table('customers')->where('tenant_id', $tenantId)->where('financial_account_id', $candidate->id)->exists()
                || DB::table('journal_entry_lines')->where('tenant_id', $tenantId)->where('financial_account_id', $candidate->id)->exists()
                || DB::table('finance_document_lines')->where('tenant_id', $tenantId)->where('financial_account_id', $candidate->id)->exists();
            if ($used) {
                continue;
            }
            DB::table('financial_accounts')->where('id', $candidate->id)->update([
                'is_active' => true, 'is_system_protected' => true, 'updated_at' => now(),
            ]);

            return (int) $candidate->id;
        }

        return null;
    }

    private function isDescendantOf(int $tenantId, object $account, int $ancestorId): bool
    {
        $seen = [];
        $cursor = $account;
        while ($cursor && ! isset($seen[(int) $cursor->id])) {
            if ((int) $cursor->id === $ancestorId) {
                return true;
            }
            $seen[(int) $cursor->id] = true;
            $cursor = $cursor->parent_account_id
                ? DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $cursor->parent_account_id)->first()
                : null;
        }

        return false;
    }
}
