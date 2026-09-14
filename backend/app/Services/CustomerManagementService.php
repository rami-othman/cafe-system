<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class CustomerManagementService
{
    public function create(int $tenantId, int $actorId, array $data): object
    {
        return DB::transaction(function () use ($tenantId, $actorId, $data): object {
            DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->first();
            $next = (int) DB::table('customers')->where('tenant_id', $tenantId)->count() + 1;
            $id = DB::table('customers')->insertGetId([
                'tenant_id' => $tenantId,
                'customer_number' => sprintf('CUS-%06d', $next),
                'name' => $data['name'], 'customer_type' => 'registered',
                'phone' => $data['phone'] ?? null, 'email' => $data['email'] ?? null,
                'tax_number' => $data['taxNumber'] ?? null,
                'default_credit_terms_days' => $data['defaultCreditTermsDays'] ?? 0,
                'notes' => $data['notes'] ?? null, 'total_spent' => 0, 'visits_count' => 0,
                'is_active' => true, 'is_walk_in' => false, 'is_system_protected' => false,
                'created_by' => $actorId, 'updated_by' => $actorId, 'created_at' => now(), 'updated_at' => now(),
            ]);
            return $this->find($tenantId, $id);
        });
    }

    public function update(int $tenantId, int $customerId, int $actorId, array $data): object
    {
        $customer = $this->find($tenantId, $customerId);
        if ($customer->is_system_protected && array_key_exists('isActive', $data) && ! $data['isActive']) {
            throw ValidationException::withMessages(['isActive' => 'The protected walk-in customer must remain active.']);
        }
        $values = [];
        foreach (['name' => 'name', 'phone' => 'phone', 'email' => 'email', 'taxNumber' => 'tax_number', 'notes' => 'notes', 'defaultCreditTermsDays' => 'default_credit_terms_days', 'isActive' => 'is_active'] as $input => $column) {
            if (array_key_exists($input, $data)) $values[$column] = $data[$input];
        }
        if ($values !== []) DB::table('customers')->where('tenant_id', $tenantId)->where('id', $customerId)->update($values + ['updated_by' => $actorId, 'updated_at' => now()]);
        return $this->find($tenantId, $customerId);
    }

    public function find(int $tenantId, int $customerId): object
    {
        $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $customerId)->whereNull('deleted_at')->first();
        abort_unless($customer, 404, 'Customer not found.');
        return $customer;
    }
}
