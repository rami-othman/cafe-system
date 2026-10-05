import 'package:equatable/equatable.dart';

import 'json_helpers.dart';
import 'modifier_option.dart';

class ModifierGroup extends Equatable {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.required,
    required this.minSelections,
    required this.maxSelections,
    required this.options,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    return ModifierGroup(
      id: readInt(json['id']) ?? 0,
      name: readString(json['name']),
      type: readString(json['type']),
      required: readBool(json['required']),
      minSelections: readInt(json['minSelections']) ?? 0,
      maxSelections: readInt(json['maxSelections']) ?? 0,
      options: readMapList(
        json['options'],
      ).map(ModifierOption.fromJson).toList(growable: false),
    );
  }

  final int id;
  final String name;
  final String type;
  final bool required;
  final int minSelections;
  final int maxSelections;
  final List<ModifierOption> options;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    type,
    required,
    minSelections,
    maxSelections,
    options,
  ];
}
