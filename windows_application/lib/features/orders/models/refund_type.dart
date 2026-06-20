enum RefundType { full, partial }

extension RefundTypeLabel on RefundType {
  String get label {
    return switch (this) {
      RefundType.full => 'Full Refund',
      RefundType.partial => 'Partial Refund',
    };
  }
}
