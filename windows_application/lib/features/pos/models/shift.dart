import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

class Shift extends Equatable {
  const Shift({
    required this.id,
    required this.branchId,
    required this.status,
    this.userId,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: readInt(json['id']) ?? 0,
      branchId: readInt(json['branchId']) ?? 0,
      userId: readInt(json['userId']),
      status: readString(json['status']),
    );
  }

  final int id;
  final int branchId;
  final int? userId;
  final String status;

  bool get isOpen => status == 'open';

  @override
  List<Object?> get props => <Object?>[id, branchId, userId, status];
}
