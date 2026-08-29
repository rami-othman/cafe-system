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

  /// The API has one canonical value as well as optional translations.  The
  /// editor deliberately derives that canonical value from the manager-facing
  /// localized inputs so it never asks for the same name or description twice.
  MenuEditorDraft withLocalizedNames({
    required String english,
    required String arabic,
  }) {
    final String canonical = english.trim().isNotEmpty ? english : arabic;
    return copyWith(name: canonical, nameEn: english, nameAr: arabic);
  }

  MenuEditorDraft withLocalizedDescriptions({
    required String english,
    required String arabic,
  }) {
    final String canonical = english.trim().isNotEmpty ? english : arabic;
    return copyWith(
      description: canonical,
      descriptionEn: english,
      descriptionAr: arabic,
    );
  }

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

  /// Sections use the same canonical-name convention as menus: managers
  /// enter localized names while the API receives one derived canonical name.
  MenuSectionDraft withLocalizedNames({
    required String english,
    required String arabic,
  }) {
    final String canonical = english.trim().isNotEmpty ? english : arabic;
    return copyWith(name: canonical, nameEn: english, nameAr: arabic);
  }

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
