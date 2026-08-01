class MenuEditorDraft {
  const MenuEditorDraft({
    this.name = '',
    this.nameAr = '',
    this.nameEn = '',
    this.description = '',
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.coverImageUrl = '',
    this.status = 'draft',
    this.priority = '0',
  });
  final String name,
      nameAr,
      nameEn,
      description,
      descriptionAr,
      descriptionEn,
      coverImageUrl,
      status,
      priority;
  MenuEditorDraft copyWith({
    String? name,
    String? nameAr,
    String? nameEn,
    String? description,
    String? descriptionAr,
    String? descriptionEn,
    String? coverImageUrl,
    String? status,
    String? priority,
  }) => MenuEditorDraft(
    name: name ?? this.name,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    description: description ?? this.description,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    descriptionEn: descriptionEn ?? this.descriptionEn,
    coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    status: status ?? this.status,
    priority: priority ?? this.priority,
  );
  Map<String, dynamic> toJson({required bool isCreate}) => <String, dynamic>{
    'name': name.trim(),
    'nameAr': _null(nameAr),
    'nameEn': _null(nameEn),
    'description': _null(description),
    'descriptionAr': _null(descriptionAr),
    'descriptionEn': _null(descriptionEn),
    'coverImageUrl': _null(coverImageUrl),
    'priority': int.tryParse(priority.trim()) ?? 0,
    if (!isCreate) 'status': status,
  };
  static String? _null(String value) =>
      value.trim().isEmpty ? null : value.trim();
}

class MenuSectionDraft {
  const MenuSectionDraft({
    this.name = '',
    this.nameAr = '',
    this.nameEn = '',
    this.description = '',
    this.imageUrl = '',
    this.isActive = true,
    this.sortOrder = '',
  });
  final String name, nameAr, nameEn, description, imageUrl, sortOrder;
  final bool isActive;
  MenuSectionDraft copyWith({
    String? name,
    String? nameAr,
    String? nameEn,
    String? description,
    String? imageUrl,
    bool? isActive,
    String? sortOrder,
  }) => MenuSectionDraft(
    name: name ?? this.name,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    isActive: isActive ?? this.isActive,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'nameAr': MenuEditorDraft._null(nameAr),
    'nameEn': MenuEditorDraft._null(nameEn),
    'description': MenuEditorDraft._null(description),
    'imageUrl': MenuEditorDraft._null(imageUrl),
    'isActive': isActive,
    if (sortOrder.trim().isNotEmpty)
      'sortOrder': int.tryParse(sortOrder.trim()),
  };
}
