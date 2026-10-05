import 'package:equatable/equatable.dart';

class PosPrintState extends Equatable {
  const PosPrintState({this.isPrinting = false, this.failure});

  final bool isPrinting;
  final PosPrintFailure? failure;

  PosPrintState copyWith({
    bool? isPrinting,
    PosPrintFailure? failure,
    bool clearFailure = false,
  }) => PosPrintState(
    isPrinting: isPrinting ?? this.isPrinting,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => <Object?>[isPrinting, failure];
}

enum PosPrintFailure {
  orderRequired,
  itemsRequired,
  preBillUnavailable,
  printerNotConfigured,
  invalidConfiguration,
  configurationUnavailable,
  receiptUnavailable,
  renderingFailed,
  printerUnreachable,
  printerTimeout,
  printerUnsupported,
  printerFailed,
}

enum PosPrintDocumentType {
  receipt('receipt'),
  preBill('pre_bill');

  const PosPrintDocumentType(this.apiValue);
  final String apiValue;
}

class PosPrintOutcome {
  const PosPrintOutcome.success() : failure = null, isSkipped = false;
  const PosPrintOutcome.skipped() : failure = null, isSkipped = true;
  const PosPrintOutcome.failed(this.failure) : isSkipped = false;

  final PosPrintFailure? failure;
  final bool isSkipped;

  bool get isSuccess => failure == null && !isSkipped;
}
