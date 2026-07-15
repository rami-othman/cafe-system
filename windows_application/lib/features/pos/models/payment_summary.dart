import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

class PaymentSummary extends Equatable {
  const PaymentSummary({
    required this.orderId,
    required this.orderNumber,
    required this.totalDue,
    required this.itemCount,
    required this.amountReceived,
    required this.changeDue,
    required this.methods,
    required this.quickAmounts,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      orderId: readInt(json['orderId']) ?? 0,
      orderNumber: readString(json['orderNumber']),
      totalDue: readDouble(json['totalDue']),
      itemCount: readDouble(json['itemCount']).round(),
      amountReceived: readDouble(json['amountReceived']),
      changeDue: readDouble(json['changeDue']),
      methods: (json['methods'] as List? ?? const <Object?>[])
          .map((dynamic value) => value.toString())
          .toList(growable: false),
      quickAmounts: (json['quickAmounts'] as List? ?? const <Object?>[])
          .map(readDouble)
          .toList(growable: false),
    );
  }

  final int orderId;
  final String orderNumber;
  final double totalDue;
  final int itemCount;
  final double amountReceived;
  final double changeDue;
  final List<String> methods;
  final List<double> quickAmounts;

  @override
  List<Object?> get props => <Object?>[
    orderId,
    orderNumber,
    totalDue,
    itemCount,
    amountReceived,
    changeDue,
    methods,
    quickAmounts,
  ];
}
