import 'json_helpers.dart';
import 'payment_method.dart';
import 'payment_result.dart';

PaymentResult paymentResultFromJson(
  Map<String, dynamic> json, {
  required double totalDue,
}) {
  final Map<String, dynamic> payment = Map<String, dynamic>.from(
    json['payment'] as Map? ?? <String, dynamic>{},
  );
  final double amount = readDouble(
    payment['amountReceived'],
    fallback: readDouble(payment['amount'], fallback: totalDue),
  );

  return PaymentResult(
    method: paymentMethodFromApi(readString(payment['method'])),
    totalDue: totalDue,
    amountReceived: amount,
    changeDue: readDouble(
      json['changeDue'],
      fallback: readDouble(payment['changeDue']),
    ),
    status:
        readString(
          payment['status'],
          fallback: readString(json['paymentStatus']),
        ).trim().isEmpty
        ? null
        : readString(
            payment['status'],
            fallback: readString(json['paymentStatus']),
          ).trim(),
    paymentId: readInt(payment['id']) ?? readInt(json['paymentId']),
  );
}
