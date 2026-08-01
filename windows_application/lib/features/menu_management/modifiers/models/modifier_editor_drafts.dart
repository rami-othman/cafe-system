class ModifierGroupDraft {
  const ModifierGroupDraft({
    this.name = '',
    this.nameAr = '',
    this.nameEn = '',
    this.code = '',
    this.groupType = 'choice',
    this.selectionType = 'single',
    this.isRequired = false,
    this.minSelections = '0',
    this.maxSelections = '1',
    this.allowQuantity = false,
    this.isActive = true,
    this.sortOrder = '0',
    this.initialOptionName = '',
    this.initialOptionPriceDelta = '0',
  });
  final String name,
      nameAr,
      nameEn,
      code,
      groupType,
      selectionType,
      minSelections,
      maxSelections,
      sortOrder,
      initialOptionName,
      initialOptionPriceDelta;
  final bool isRequired, allowQuantity, isActive;
  ModifierGroupDraft copyWith({
    String? name,
    String? nameAr,
    String? nameEn,
    String? code,
    String? groupType,
    String? selectionType,
    bool? isRequired,
    String? minSelections,
    String? maxSelections,
    bool? allowQuantity,
    bool? isActive,
    String? sortOrder,
    String? initialOptionName,
    String? initialOptionPriceDelta,
  }) => ModifierGroupDraft(
    name: name ?? this.name,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    code: code ?? this.code,
    groupType: groupType ?? this.groupType,
    selectionType: selectionType ?? this.selectionType,
    isRequired: isRequired ?? this.isRequired,
    minSelections: minSelections ?? this.minSelections,
    maxSelections: maxSelections ?? this.maxSelections,
    allowQuantity: allowQuantity ?? this.allowQuantity,
    isActive: isActive ?? this.isActive,
    sortOrder: sortOrder ?? this.sortOrder,
    initialOptionName: initialOptionName ?? this.initialOptionName,
    initialOptionPriceDelta:
        initialOptionPriceDelta ?? this.initialOptionPriceDelta,
  );
  Map<String, dynamic> toCreateJson() =>
      _json()
        ..['options'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'name': initialOptionName.trim(),
            'priceDelta': initialOptionPriceDelta.trim().isEmpty
                ? '0'
                : initialOptionPriceDelta.trim(),
            'isDefault': false,
            'isActive': true,
            'isAvailable': true,
            'sortOrder': 0,
          },
        ];
  Map<String, dynamic> toUpdateJson() => _json();
  Map<String, dynamic> _json() => <String, dynamic>{
    'name': name.trim(),
    'nameAr': _nullable(nameAr),
    'nameEn': _nullable(nameEn),
    'code': _nullable(code),
    'groupType': groupType,
    'selectionType': selectionType,
    'isRequired': isRequired,
    'minSelections': int.tryParse(minSelections.trim()) ?? 0,
    'maxSelections': int.tryParse(maxSelections.trim()) ?? 1,
    'allowQuantity': allowQuantity,
    'isActive': isActive,
    'sortOrder': int.tryParse(sortOrder.trim()) ?? 0,
  };
}

class ModifierOptionDraft {
  const ModifierOptionDraft({
    this.name = '',
    this.nameAr = '',
    this.nameEn = '',
    this.priceDelta = '0',
    this.isDefault = false,
    this.isActive = true,
    this.isAvailable = true,
    this.sortOrder = '0',
  });
  final String name, nameAr, nameEn, priceDelta, sortOrder;
  final bool isDefault, isActive, isAvailable;
  ModifierOptionDraft copyWith({
    String? name,
    String? nameAr,
    String? nameEn,
    String? priceDelta,
    bool? isDefault,
    bool? isActive,
    bool? isAvailable,
    String? sortOrder,
  }) => ModifierOptionDraft(
    name: name ?? this.name,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    priceDelta: priceDelta ?? this.priceDelta,
    isDefault: isDefault ?? this.isDefault,
    isActive: isActive ?? this.isActive,
    isAvailable: isAvailable ?? this.isAvailable,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'nameAr': _nullable(nameAr),
    'nameEn': _nullable(nameEn),
    'priceDelta': priceDelta.trim().isEmpty ? '0' : priceDelta.trim(),
    'isDefault': isDefault,
    'isActive': isActive,
    'isAvailable': isAvailable,
    'sortOrder': int.tryParse(sortOrder.trim()) ?? 0,
  };
}

String? _nullable(String value) {
  final String text = value.trim();
  return text.isEmpty ? null : text;
}
