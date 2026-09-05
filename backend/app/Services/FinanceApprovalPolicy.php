<?php
namespace App\Services;
use App\Support\Money; use Illuminate\Support\Facades\DB; use Illuminate\Validation\ValidationException;
final class FinanceApprovalPolicy {
 public function assertExpenseApproval(int $tenant,int $actor,object $expense): void { $role=DB::table('users')->where('tenant_id',$tenant)->where('id',$actor)->value('role'); if($role==='owner')return; if((int)$expense->created_by===$actor)throw ValidationException::withMessages(['approval'=>['SELF_APPROVAL_NOT_ALLOWED']]); $rule=DB::table('finance_approval_rules')->where('tenant_id',$tenant)->where('action_type','expense_approve')->where('is_active',true)->where('role',$role)->where(fn($q)=>$q->where('branch_id',$expense->branch_id)->orWhereNull('branch_id'))->orderByRaw('branch_id IS NULL')->first(); if(!$rule)throw ValidationException::withMessages(['approval'=>['FINANCE_APPROVAL_LIMIT_EXCEEDED']]); if($rule->max_amount!==null&&Money::cents($expense->total_amount)>Money::cents($rule->max_amount))throw ValidationException::withMessages(['approval'=>['FINANCE_APPROVAL_LIMIT_EXCEEDED']]); }
 public function canApproveExpense(int $tenant,int $actor,object $expense): bool { try{$this->assertExpenseApproval($tenant,$actor,$expense);return true;}catch(ValidationException){return false;} }
}
