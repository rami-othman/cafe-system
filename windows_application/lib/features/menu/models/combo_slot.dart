import 'package:equatable/equatable.dart';

class ComboSlot extends Equatable {
  const ComboSlot({
    required this.id,
    required this.name,
    required this.allowedCategoryIds,
    required this.minSelections,
    required this.maxSelections,
    required this.isRequired,
  });

  final String id;
  final String name;
  final List<String> allowedCategoryIds;
  final int minSelections;
  final int maxSelections;
  final bool isRequired;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    allowedCategoryIds,
    minSelections,
    maxSelections,
    isRequired,
  ];
}
