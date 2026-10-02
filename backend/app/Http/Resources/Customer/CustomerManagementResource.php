<?php

namespace App\Http\Resources\Customer;

use Illuminate\Http\Resources\Json\JsonResource;

class CustomerManagementResource extends JsonResource
{
    public function toArray($request): array
    {
        $phones = $this->relationLoaded('phones') ? $this->phones : collect();
        $groups = $this->relationLoaded('groups') ? $this->groups : collect();

        // The wallet card is only needed on a single customer (show/update), not for every row of a list.
        $wallet = [];
        if ($request->route('customer') !== null && $this->deleted_at === null) {
            $state = app(\App\Services\PartyAccountService::class)->walletState((int) $this->tenant_id, (int) $this->id);
            $wallet = [
                'walletBalance' => \App\Support\Money::decimal($state['fundsCents']),
                'walletCreditLimit' => \App\Support\Money::decimal($state['limitCents']),
                'walletAvailable' => \App\Support\Money::decimal($state['availableCents']),
            ];
        }

        return $wallet + [
            'id' => (int) $this->id,
            'customerNumber' => $this->customer_number,
            'financialAccountId' => $this->financial_account_id ? (int) $this->financial_account_id : null,
            'isInternal' => (bool) $this->is_internal,
            'internalBranchId' => $this->internal_branch_id ? (int) $this->internal_branch_id : null,
            'name' => $this->name,
            'email' => $this->email,
            'birthDate' => $this->birth_date?->format('Y-m-d'),
            'notes' => $this->notes,
            'status' => $this->lifecycleState(),
            'isActive' => (bool) $this->is_active,
            'phones' => $phones->map(fn ($phone): array => ['id' => (int) $phone->id, 'rawNumber' => $phone->raw_number, 'normalizedNumber' => $phone->normalized_number, 'type' => $phone->type, 'isPrimary' => (bool) $phone->is_primary, 'validationStatus' => $phone->validation_status])->values()->all(),
            'groups' => $groups->map(fn ($group): array => ['id' => (int) $group->id, 'name' => $group->name, 'status' => $group->lifecycleState()])->values()->all(),
            'allowedActions' => $this->deleted_at !== null ? ['restore'] : ['update', 'deactivate', 'activate', 'archive'],
            'createdAt' => $this->created_at?->toISOString(),
            'updatedAt' => $this->updated_at?->toISOString(),
        ];
    }
}
