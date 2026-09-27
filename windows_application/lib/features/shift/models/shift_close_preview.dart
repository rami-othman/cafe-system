import 'package:equatable/equatable.dart';

import 'shift_models.dart';

enum ShiftCountBasis { periodRecorded, current }

extension ShiftCountBasisApi on ShiftCountBasis {
  String get apiValue => switch (this) {
    ShiftCountBasis.periodRecorded => 'period_recorded',
    ShiftCountBasis.current => 'current',
  };
}

class ShiftClosePreview extends Equatable {
  const ShiftClosePreview({
    required this.snapshot,
    required this.date,
    required this.timezone,
    required this.endExclusive,
    required this.historical,
    required this.version,
    required this.currentLedgerCash,
    required this.laterNetCash,
    required this.transferAmount,
    required this.continuationCashAfterTransfer,
    required this.willContinue,
    required this.laterRecordCount,
    required this.issues,
    required this.openingDate,
    required this.today,
  });

  final ShiftSnapshot snapshot;
  final DateTime date;
  final String timezone;
  final DateTime endExclusive;
  final bool historical;
  final String version;
  final double currentLedgerCash;
  final double laterNetCash;
  final double transferAmount;
  final double continuationCashAfterTransfer;
  final bool willContinue;
  final int laterRecordCount;
  final List<String> issues;
  final DateTime openingDate;
  final DateTime today;

  bool get canClose => issues.isEmpty;

  @override
  List<Object?> get props => <Object?>[
    snapshot,
    date,
    timezone,
    endExclusive,
    historical,
    version,
    currentLedgerCash,
    laterNetCash,
    transferAmount,
    continuationCashAfterTransfer,
    willContinue,
    laterRecordCount,
    issues,
    openingDate,
    today,
  ];
}
