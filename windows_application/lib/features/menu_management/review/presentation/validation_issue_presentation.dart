import '../models/review_models.dart';

/// Presentation-only metadata for the backend validation contract.
///
/// This deliberately does not decide severity, publishability, or rewrite the
/// backend message. Unknown backend codes remain safely visible under Other.
enum ReadinessIssueCategory {
  menus,
  sections,
  products,
  variants,
  recipesMaterials,
  modifiers,
  pricing,
  availability,
  assignmentsScope,
  other,
}

enum ReadinessIssueAction {
  none,
  openMenu,
  openProduct,
  openSections,
  reviewMenu,
  goToAssignments,
}

class ValidationIssuePresentation {
  const ValidationIssuePresentation._();

  static ReadinessIssueCategory categoryFor(ValidationIssue issue) =>
      _categories[issue.code] ?? ReadinessIssueCategory.other;

  static bool isKnown(ValidationIssue issue) =>
      _categories.containsKey(issue.code);

  /// Only returns a destination when the current route can honestly provide
  /// it from fields supplied by the backend issue itself.
  static ReadinessIssueAction actionFor(ValidationIssue issue) {
    if (issue.code == 'NO_ASSIGNED_MENU' ||
        issue.code == 'MENU_MISSING_ASSIGNMENT' ||
        issue.code == 'DUPLICATE_MENU_ASSIGNMENT') {
      return ReadinessIssueAction.goToAssignments;
    }
    if (!isKnown(issue)) return ReadinessIssueAction.none;

    if (issue.entityType == 'product' && _positive(issue.entityId)) {
      return ReadinessIssueAction.openProduct;
    }
    if (!_positive(issue.menuId)) return ReadinessIssueAction.none;

    if (issue.entityType == 'menu') return ReadinessIssueAction.openMenu;
    if (categoryFor(issue) == ReadinessIssueCategory.sections) {
      return ReadinessIssueAction.openSections;
    }
    // Product placements, variants, modifiers, and recipes cannot always be
    // focused exactly. Their supplied menu context can still open the real
    // Menu workspace without claiming an unsupported deep link.
    return ReadinessIssueAction.reviewMenu;
  }

  static bool _positive(int? value) => value != null && value > 0;

  static const Map<String, ReadinessIssueCategory>
  _categories = <String, ReadinessIssueCategory>{
    'MENU_ARCHIVED': ReadinessIssueCategory.menus,
    'MENU_MISSING_ASSIGNMENT': ReadinessIssueCategory.assignmentsScope,
    'DUPLICATE_MENU_ASSIGNMENT': ReadinessIssueCategory.assignmentsScope,
    'MENU_NO_ACTIVE_SECTION': ReadinessIssueCategory.sections,
    'MENU_NO_VISIBLE_PLACEMENT': ReadinessIssueCategory.menus,
    'SECTION_INVALID_OWNERSHIP': ReadinessIssueCategory.sections,
    'DUPLICATE_PRODUCT_PLACEMENT': ReadinessIssueCategory.products,
    'PLACEMENT_PRODUCT_MISSING': ReadinessIssueCategory.products,
    'PRODUCT_TENANT_MISMATCH': ReadinessIssueCategory.products,
    'PLACEMENT_PRODUCT_ARCHIVED': ReadinessIssueCategory.products,
    'PRODUCT_CATEGORY_MISSING_OR_ARCHIVED': ReadinessIssueCategory.products,
    'PRODUCT_MISSING_ACTIVE_VARIANT': ReadinessIssueCategory.variants,
    'PRODUCT_MISSING_ACTIVE_DEFAULT_VARIANT': ReadinessIssueCategory.variants,
    'PRODUCT_MULTIPLE_ACTIVE_DEFAULT_VARIANTS': ReadinessIssueCategory.variants,
    'DEFAULT_VARIANT_INACTIVE': ReadinessIssueCategory.variants,
    'VARIANT_TENANT_MISMATCH': ReadinessIssueCategory.variants,
    'VARIANT_NEGATIVE_PRICE_OR_COST': ReadinessIssueCategory.pricing,
    'VARIANT_DUPLICATE_ACTIVE_SKU': ReadinessIssueCategory.variants,
    'VARIANT_DUPLICATE_ACTIVE_BARCODE': ReadinessIssueCategory.variants,
    'VARIANT_INVALID_EFFECTIVE_PRICE': ReadinessIssueCategory.pricing,
    'VARIANT_RECIPE_MISSING': ReadinessIssueCategory.recipesMaterials,
    'VARIANT_RECIPE_EMPTY': ReadinessIssueCategory.recipesMaterials,
    'RECIPE_COMPONENT_MATERIAL_UNAVAILABLE':
        ReadinessIssueCategory.recipesMaterials,
    'RECIPE_COMPONENT_MATERIAL_UNIT_UNMAPPED':
        ReadinessIssueCategory.recipesMaterials,
    'RECIPE_COMPONENT_QUANTITY_INVALID':
        ReadinessIssueCategory.recipesMaterials,
    'RECIPE_COMPONENT_UNIT_INVALID': ReadinessIssueCategory.recipesMaterials,
    'MODIFIER_GROUP_TENANT_MISMATCH': ReadinessIssueCategory.modifiers,
    'MODIFIER_GROUP_ARCHIVED': ReadinessIssueCategory.modifiers,
    'MODIFIER_GROUP_NO_ACTIVE_OPTION': ReadinessIssueCategory.modifiers,
    'MODIFIER_REQUIRED_MINIMUM_INVALID': ReadinessIssueCategory.modifiers,
    'MODIFIER_MINIMUM_EXCEEDS_MAXIMUM': ReadinessIssueCategory.modifiers,
    'MODIFIER_MAXIMUM_EXCEEDS_OPTIONS': ReadinessIssueCategory.modifiers,
    'MODIFIER_SINGLE_MAXIMUM_INVALID': ReadinessIssueCategory.modifiers,
    'MODIFIER_DEFAULTS_EXCEED_MAXIMUM': ReadinessIssueCategory.modifiers,
    'MODIFIER_RECIPE_PROFILE_INVALID': ReadinessIssueCategory.modifiers,
    'MODIFIER_RECIPE_QUANTITY_REMOVE_INVALID': ReadinessIssueCategory.modifiers,
    'MODIFIER_RECIPE_REMOVE_EXCEEDS_BASE': ReadinessIssueCategory.modifiers,
    'MODIFIER_RECIPE_COMBINED_REMOVE_EXCEEDS_BASE':
        ReadinessIssueCategory.modifiers,
    'NO_ASSIGNED_MENU': ReadinessIssueCategory.assignmentsScope,
    'MENU_UNRESTRICTED_SCHEDULE': ReadinessIssueCategory.availability,
    'SECTION_EMPTY': ReadinessIssueCategory.sections,
    'PRODUCT_HIDDEN_PLACEMENT': ReadinessIssueCategory.products,
    'PRODUCT_REPORTING_CATEGORY_UNAVAILABLE': ReadinessIssueCategory.products,
    'PRODUCT_KITCHEN_STATION_UNAVAILABLE': ReadinessIssueCategory.products,
    'PRODUCT_KITCHEN_STATION_SCOPE_INVALID': ReadinessIssueCategory.products,
    'PRODUCT_MISSING_IMAGE': ReadinessIssueCategory.products,
    'PRODUCT_MISSING_PREPARATION_TIME': ReadinessIssueCategory.products,
    'PRODUCT_OPEN_PRICE': ReadinessIssueCategory.pricing,
    'VARIANT_BASE_PRICE_FALLBACK': ReadinessIssueCategory.pricing,
    'PRODUCT_OUTSIDE_SCHEDULE': ReadinessIssueCategory.availability,
    'PRODUCT_OPERATIONALLY_UNAVAILABLE': ReadinessIssueCategory.availability,
    'LEGACY_SIZE_MODIFIER_GROUP': ReadinessIssueCategory.modifiers,
  };
}
