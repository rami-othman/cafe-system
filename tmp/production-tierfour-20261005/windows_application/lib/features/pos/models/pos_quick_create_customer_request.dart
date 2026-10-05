import 'package:equatable/equatable.dart';

class PosQuickCreateCustomerRequest extends Equatable {
  const PosQuickCreateCustomerRequest({
    required this.name,
    required this.phone,
    this.notes,
    this.groupIds = const <int>{},
  });

  final String name;
  final String phone;
  final String? notes;
  final Set<int> groupIds;

  Map<String, dynamic> toJson() {
    final List<int> ids = groupIds.toList()..sort();
    return <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'groupIds': ids,
    };
  }

  @override
  List<Object?> get props => <Object?>[name, phone, notes, groupIds];
}
