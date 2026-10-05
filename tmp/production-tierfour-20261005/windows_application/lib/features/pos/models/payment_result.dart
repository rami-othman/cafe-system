import 'package:equatable/equatable.dart';

import 'order_type.dart';
import 'payment_method.dart';

class PaymentResult extends Equatable {
  const PaymentResult({
    required this.method,
    required this.totalDue,
    required this.amountReceived,
    required this.changeDue,
    this.status,
    this.paymentId,
    this.reference,
    this.orderType,
    this.deliveryCompanyId,
    this.onDeliveryAccount = false,
  });

  final PaymentMethod method;
  final double totalDue;
  final double amountReceived;
  final double changeDue;
  final String? status;
  final int? paymentId;
  final String? reference;

  /// Chosen in the payment dialog (null when the dialog does not ask for it).
  final OrderType? orderType;

  /// Set only for delivery orders: the delivery company the sale is settled through.
  final int? deliveryCompanyId;

  /// Delivery only: leave the amount on the delivery company's account (settled
  /// later) instead of collecting cash now.
  final bool onDeliveryAccount;

  @override
  List<Object?> get props => <Object?>[
    method,
    totalDue,
    amountReceived,
    changeDue,
    status,
    paymentId,
    reference,
    orderType,
    deliveryCompanyId,
    onDeliveryAccount,
  ];
}
