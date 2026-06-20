import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

class CafeTable extends Equatable {
  const CafeTable({
    required this.id,
    required this.branchId,
    required this.name,
    required this.code,
    required this.status,
    required this.seats,
  });

  factory CafeTable.fromJson(Map<String, dynamic> json) {
    return CafeTable(
      id: readInt(json['id']) ?? 0,
      branchId: readInt(json['branchId']) ?? 0,
      name: readString(json['name']),
      code: readString(json['code']),
      status: readString(json['status']),
      seats: readInt(json['seats']) ?? 0,
    );
  }

  final int id;
  final int branchId;
  final String name;
  final String code;
  final String status;
  final int seats;

  @override
  List<Object?> get props => <Object?>[id, branchId, name, code, status, seats];
}
