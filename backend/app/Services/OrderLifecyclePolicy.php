<?php

namespace App\Services;

use App\Exceptions\OrderLifecycleException;

/**
 * The authoritative state rules for POS order mutations.  Callers must pass
 * an order read inside their transaction when the operation is financial.
 */
class OrderLifecyclePolicy
{
    public function canMutateItems(object $order): bool
    {
        return in_array($order->status, ['draft', 'held'], true) && $order->payment_status === 'unpaid';
    }

    public function canApplyDiscount(object $order): bool
    {
        return $this->canMutateItems($order);
    }

    public function canHold(object $order): bool
    {
        return $order->status === 'draft' && $order->payment_status === 'unpaid';
    }

    public function canCancel(object $order): bool
    {
        return in_array($order->status, ['draft', 'held'], true) && $order->payment_status === 'unpaid';
    }

    public function canPay(object $order): bool
    {
        return in_array($order->status, ['draft', 'held'], true) && $order->payment_status === 'unpaid';
    }

    public function canRefund(object $order): bool
    {
        return $order->status === 'paid' && in_array($order->payment_status, ['paid', 'partially_refunded'], true);
    }

    public function assertMutable(object $order): void
    {
        if (! $this->canMutateItems($order)) {
            throw new OrderLifecycleException('ORDER_NOT_EDITABLE', 'This order can no longer be edited.');
        }
    }

    public function assertDiscountable(object $order): void
    {
        if (! $this->canApplyDiscount($order)) {
            throw new OrderLifecycleException('ORDER_NOT_EDITABLE', 'Discounts cannot be changed for this order.');
        }
    }

    public function assertHoldable(object $order): void
    {
        if (! $this->canHold($order)) {
            throw new OrderLifecycleException('ORDER_NOT_EDITABLE', 'This order cannot be held.');
        }
    }

    public function assertCancellable(object $order): void
    {
        if (! $this->canCancel($order)) {
            throw new OrderLifecycleException('ORDER_NOT_EDITABLE', 'Paid or closed orders cannot be cancelled.');
        }
    }

    public function assertPayable(object $order): void
    {
        if (! $this->canPay($order)) {
            throw new OrderLifecycleException(
                $order->payment_status === 'paid' ? 'ORDER_ALREADY_PAID' : 'ORDER_NOT_PAYABLE',
                'This order cannot be paid in its current state.',
            );
        }
    }

    public function assertRefundable(object $order): void
    {
        if (! $this->canRefund($order)) {
            throw new OrderLifecycleException('REFUND_NOT_ALLOWED', 'This order is not eligible for a refund.');
        }
    }
}
