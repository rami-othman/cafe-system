import 'package:equatable/equatable.dart';

import 'menu_enums.dart';
import 'modifier_option.dart';

class ModifierGroup extends Equatable {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.selectionType,
    required this.isRequired,
    required this.minChoices,
    required this.maxChoices,
    required this.displayOrder,
    required this.isActive,
    required this.options,
    required this.assignedProductIds,
  });

  final String id;
  final String name;
  final String description;
  final ModifierSelectionType selectionType;
  final bool isRequired;
  final int minChoices;
  final int maxChoices;
  final int displayOrder;
  final bool isActive;
  final List<ModifierOption> options;
  final List<String> assignedProductIds;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    description,
    selectionType,
    isRequired,
    minChoices,
    maxChoices,
    displayOrder,
    isActive,
    options,
    assignedProductIds,
  ];
}
