import 'package:equatable/equatable.dart';

import '../../pos/models/json_helpers.dart';
import 'bar_check_line.dart';

/// The cashier's own shift bar check (a `stock_counts` row of
/// count_type=shift_check), scoped server-side to their own open shift.
class BarCheckSession extends Equatable {
  const BarCheckSession({
    required this.id,
    required this.status,
    required this.lines,
  });

  factory BarCheckSession.fromJson(Map<String, dynamic> json) =>
      BarCheckSession(
        id: readInt(json['id']) ?? 0,
        status: readString(json['status']),
        lines: readMapList(
          json['lines'],
        ).map(BarCheckLine.fromJson).toList(growable: false),
      );

  final int id;
  final String status;
  final List<BarCheckLine> lines;

  bool get allRequiredLinesCounted =>
      lines.where((BarCheckLine line) => line.isRequired).every(
        (BarCheckLine line) => line.isCounted,
      );

  bool get hasPendingManagerReview =>
      lines.any((BarCheckLine line) => line.needsManagerReview);

  bool get isPosted => status == 'posted';

  @override
  List<Object?> get props => <Object?>[id, status, lines];
}
