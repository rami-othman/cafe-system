import 'package:equatable/equatable.dart';

class PosCustomerGroup extends Equatable {
  const PosCustomerGroup({required this.id, required this.name});

  factory PosCustomerGroup.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'];
    final int? id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
    final String name = json['name'] is String ? json['name'] as String : '';
    if (id == null || id <= 0 || name.trim().isEmpty) {
      throw const FormatException('Customer group response is invalid.');
    }
    return PosCustomerGroup(id: id, name: name);
  }

  final int id;
  final String name;

  @override
  List<Object> get props => <Object>[id, name];
}
