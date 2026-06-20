enum RefundReason {
  customerRequest,
  wrongItem,
  itemQualityIssue,
  duplicateCharge,
  orderCancelled,
  managerApproved,
  other,
}

extension RefundReasonLabel on RefundReason {
  String get label {
    return switch (this) {
      RefundReason.customerRequest => 'Customer Request',
      RefundReason.wrongItem => 'Wrong Item',
      RefundReason.itemQualityIssue => 'Item Quality Issue',
      RefundReason.duplicateCharge => 'Duplicate Charge',
      RefundReason.orderCancelled => 'Order Cancelled',
      RefundReason.managerApproved => 'Manager Approved',
      RefundReason.other => 'Other',
    };
  }
}
