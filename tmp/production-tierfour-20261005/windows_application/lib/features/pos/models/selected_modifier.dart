import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

class SelectedModifier extends Equatable {
  const SelectedModifier({required this.groupId, required this.optionId});

  factory SelectedModifier.fromJson(Map<String, dynamic> json) {
    return SelectedModifier(
      groupId: readInt(json['groupId']) ?? 0,
      optionId: readInt(json['optionId']) ?? 0,
    );
  }

  final int groupId;
  final int optionId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'groupId': groupId, 'optionId': optionId};
  }

  @override
  List<Object?> get props => <Object?>[groupId, optionId];
}
