import '../models/menu_activity.dart';
import '../models/menu_category.dart';
import '../models/menu_enums.dart';
import '../models/menu_kpis.dart';
import '../models/menu_product.dart';
import '../models/modifier_group.dart';
import '../models/modifier_option.dart';
import '../models/product_variant.dart';
import 'menu_repository.dart';

class MockMenuRepository implements MenuRepository {
  const MockMenuRepository();

  static const List<String> _branches = <String>['downtown', 'mall'];
  static const List<ChannelType> _channels = ChannelType.values;

  @override
  Future<List<MenuCategory>> getCategories() async => _categories;

  @override
  Future<List<MenuProduct>> getProducts() async => _products;

  @override
  Future<List<ProductVariant>> getProductVariants() async => _variants;

  @override
  Future<List<ModifierGroup>> getModifierGroups() async => _modifierGroups;

  @override
  Future<List<MenuActivity>> getRecentActivities() async => <MenuActivity>[
    MenuActivity(
      id: 'activity-1',
      activity: 'Latte price updated from \$4.50 to \$4.75',
      user: 'Sarah J.',
      dateTime: DateTime(2026, 7, 6, 9, 41),
      dateTimeLabel: 'Today, 09:41 AM',
      status: 'Applied',
    ),
    MenuActivity(
      id: 'activity-2',
      activity: 'New category: Seasonal Brews added',
      user: 'Admin',
      dateTime: DateTime(2026, 7, 5, 14, 30),
      dateTimeLabel: 'Yesterday, 14:30 PM',
      status: 'Applied',
    ),
    MenuActivity(
      id: 'activity-3',
      activity: 'Disabled item: Pumpkin Spice Muffin',
      user: 'Mike T.',
      dateTime: DateTime(2025, 10, 24, 8, 15),
      dateTimeLabel: 'Oct 24, 08:15 AM',
      status: 'Pending Sync',
    ),
    MenuActivity(
      id: 'activity-4',
      activity: 'Added modifier: Almond Milk (+\$0.50)',
      user: 'Sarah J.',
      dateTime: DateTime(2025, 10, 22, 11, 20),
      dateTimeLabel: 'Oct 22, 11:20 AM',
      status: 'Applied',
    ),
    MenuActivity(
      id: 'activity-5',
      activity: 'Image updated for: Croissant',
      user: 'Admin',
      dateTime: DateTime(2025, 10, 20, 16, 45),
      dateTimeLabel: 'Oct 20, 16:45 PM',
      status: 'Applied',
    ),
  ];

  @override
  Future<MenuKpis> getMenuKpis() async {
    return const MenuKpis(
      totalCategories: 12,
      totalProducts: 84,
      activeProducts: 78,
      inactiveProducts: 6,
      modifierGroups: 15,
    );
  }

  static const List<MenuCategory> _categories = <MenuCategory>[
    MenuCategory(
      id: 'hot-coffee',
      name: 'Hot Coffee',
      description: 'Espresso-based hot drinks',
      sortOrder: 1,
      isActive: true,
      branchIds: _branches,
      productCount: 3,
    ),
    MenuCategory(
      id: 'cold-coffee',
      name: 'Cold Coffee',
      description: 'Chilled coffee drinks',
      sortOrder: 2,
      isActive: true,
      branchIds: _branches,
      productCount: 1,
    ),
    MenuCategory(
      id: 'tea',
      name: 'Tea',
      description: 'Hot and iced tea',
      sortOrder: 3,
      isActive: true,
      branchIds: _branches,
      productCount: 0,
    ),
    MenuCategory(
      id: 'desserts',
      name: 'Desserts',
      description: 'Cakes and desserts',
      sortOrder: 4,
      isActive: true,
      branchIds: _branches,
      productCount: 1,
    ),
    MenuCategory(
      id: 'bakery',
      name: 'Bakery',
      description: 'Fresh bakery items',
      sortOrder: 5,
      isActive: true,
      branchIds: _branches,
      productCount: 1,
    ),
    MenuCategory(
      id: 'sandwiches',
      name: 'Sandwiches',
      description: 'Prepared sandwiches',
      sortOrder: 6,
      isActive: true,
      branchIds: _branches,
      productCount: 0,
    ),
    MenuCategory(
      id: 'combos',
      name: 'Combos',
      description: 'Bundled menu offers',
      sortOrder: 7,
      isActive: true,
      branchIds: _branches,
      productCount: 1,
    ),
  ];

  static const List<ProductVariant> _variants = <ProductVariant>[
    ProductVariant(
      id: 'latte-small',
      productId: 'latte',
      name: 'Small',
      sku: 'LAT-S',
      price: 4.25,
      cost: 1.20,
      isDefault: true,
      status: ProductStatus.active,
    ),
    ProductVariant(
      id: 'latte-large',
      productId: 'latte',
      name: 'Large',
      sku: 'LAT-L',
      price: 5.25,
      cost: 1.55,
      isDefault: false,
      status: ProductStatus.active,
    ),
  ];

  static const List<MenuProduct> _products = <MenuProduct>[
    MenuProduct(
      id: 'espresso',
      name: 'Espresso',
      description: 'Double espresso',
      sku: 'ESP-001',
      categoryId: 'hot-coffee',
      categoryName: 'Hot Coffee',
      type: ProductType.simple,
      status: ProductStatus.active,
      basePrice: 3.50,
      cost: 0.85,
      isTaxable: true,
      availableChannels: _channels,
      branchIds: _branches,
      variants: <ProductVariant>[],
      modifierGroupIds: <String>['extra-shot'],
    ),
    MenuProduct(
      id: 'latte',
      name: 'Caffe Latte',
      arabicName: 'كافيه لاتيه',
      description: 'Espresso with steamed milk',
      sku: 'LAT-001',
      categoryId: 'hot-coffee',
      categoryName: 'Hot Coffee',
      type: ProductType.variant,
      status: ProductStatus.active,
      basePrice: 4.25,
      cost: 1.20,
      isTaxable: true,
      availableChannels: _channels,
      branchIds: _branches,
      variants: _variants,
      modifierGroupIds: <String>['milk-options', 'extra-shot', 'syrups'],
    ),
    MenuProduct(
      id: 'cappuccino',
      name: 'Cappuccino',
      description: 'Espresso with milk foam',
      sku: 'CAP-001',
      categoryId: 'hot-coffee',
      categoryName: 'Hot Coffee',
      type: ProductType.simple,
      status: ProductStatus.active,
      basePrice: 4.50,
      isTaxable: true,
      availableChannels: _channels,
      branchIds: _branches,
      variants: <ProductVariant>[],
      modifierGroupIds: <String>['milk-options', 'extra-shot'],
    ),
    MenuProduct(
      id: 'iced-americano',
      name: 'Iced Americano',
      description: 'Espresso over ice and water',
      sku: 'ICA-001',
      categoryId: 'cold-coffee',
      categoryName: 'Cold Coffee',
      type: ProductType.simple,
      status: ProductStatus.active,
      basePrice: 4.00,
      isTaxable: true,
      availableChannels: _channels,
      branchIds: _branches,
      variants: <ProductVariant>[],
      modifierGroupIds: <String>['extra-shot', 'syrups'],
    ),
    MenuProduct(
      id: 'croissant',
      name: 'Almond Croissant',
      description: 'Butter croissant with almond filling',
      sku: 'BAK-001',
      categoryId: 'bakery',
      categoryName: 'Bakery',
      type: ProductType.simple,
      status: ProductStatus.active,
      basePrice: 3.75,
      isTaxable: true,
      availableChannels: _channels,
      branchIds: _branches,
      variants: <ProductVariant>[],
      modifierGroupIds: <String>[],
    ),
    MenuProduct(
      id: 'cheesecake',
      name: 'Cheesecake',
      description: 'Classic baked cheesecake',
      sku: 'DES-001',
      categoryId: 'desserts',
      categoryName: 'Desserts',
      type: ProductType.simple,
      status: ProductStatus.inactive,
      basePrice: 5.50,
      isTaxable: true,
      availableChannels: _channels,
      branchIds: _branches,
      variants: <ProductVariant>[],
      modifierGroupIds: <String>['toppings'],
    ),
    MenuProduct(
      id: 'morning-combo',
      name: 'Morning Start Combo',
      description: 'Coffee and bakery breakfast bundle',
      sku: 'COM-001',
      categoryId: 'combos',
      categoryName: 'Combos',
      type: ProductType.combo,
      status: ProductStatus.draft,
      basePrice: 7.50,
      isTaxable: true,
      availableChannels: _channels,
      branchIds: _branches,
      variants: <ProductVariant>[],
      modifierGroupIds: <String>[],
    ),
  ];

  static const List<ModifierGroup> _modifierGroups = <ModifierGroup>[
    ModifierGroup(
      id: 'milk-options',
      name: 'Milk Options',
      description: 'Choose a milk',
      selectionType: ModifierSelectionType.single,
      isRequired: true,
      minChoices: 1,
      maxChoices: 1,
      displayOrder: 1,
      isActive: true,
      options: <ModifierOption>[
        ModifierOption(
          id: 'whole-milk',
          groupId: 'milk-options',
          name: 'Whole Milk',
          extraPrice: 0,
          isDefault: true,
          stockStatus: StockStatus.inStock,
          isActive: true,
        ),
        ModifierOption(
          id: 'oat-milk',
          groupId: 'milk-options',
          name: 'Oat Milk',
          extraPrice: 0.75,
          isDefault: false,
          stockStatus: StockStatus.inStock,
          isActive: true,
        ),
      ],
      assignedProductIds: <String>['latte', 'cappuccino'],
    ),
    ModifierGroup(
      id: 'extra-shot',
      name: 'Extra Shot',
      description: 'Add espresso shots',
      selectionType: ModifierSelectionType.multiple,
      isRequired: false,
      minChoices: 0,
      maxChoices: 2,
      displayOrder: 2,
      isActive: true,
      options: <ModifierOption>[
        ModifierOption(
          id: 'one-shot',
          groupId: 'extra-shot',
          name: 'Extra Shot',
          extraPrice: 1,
          isDefault: false,
          stockStatus: StockStatus.inStock,
          isActive: true,
        ),
      ],
      assignedProductIds: <String>[
        'espresso',
        'latte',
        'cappuccino',
        'iced-americano',
      ],
    ),
    ModifierGroup(
      id: 'syrups',
      name: 'Syrups',
      description: 'Flavored syrups',
      selectionType: ModifierSelectionType.multiple,
      isRequired: false,
      minChoices: 0,
      maxChoices: 3,
      displayOrder: 3,
      isActive: true,
      options: <ModifierOption>[
        ModifierOption(
          id: 'vanilla',
          groupId: 'syrups',
          name: 'Vanilla',
          extraPrice: 0.50,
          isDefault: false,
          stockStatus: StockStatus.inStock,
          isActive: true,
        ),
      ],
      assignedProductIds: <String>['latte', 'iced-americano'],
    ),
    ModifierGroup(
      id: 'toppings',
      name: 'Toppings',
      description: 'Dessert toppings',
      selectionType: ModifierSelectionType.multiple,
      isRequired: false,
      minChoices: 0,
      maxChoices: 2,
      displayOrder: 4,
      isActive: true,
      options: <ModifierOption>[
        ModifierOption(
          id: 'berries',
          groupId: 'toppings',
          name: 'Fresh Berries',
          extraPrice: 1.25,
          isDefault: false,
          stockStatus: StockStatus.lowStock,
          isActive: true,
        ),
      ],
      assignedProductIds: <String>['cheesecake'],
    ),
    ModifierGroup(
      id: 'bread-type',
      name: 'Bread Type',
      description: 'Choose sandwich bread',
      selectionType: ModifierSelectionType.single,
      isRequired: true,
      minChoices: 1,
      maxChoices: 1,
      displayOrder: 5,
      isActive: true,
      options: <ModifierOption>[
        ModifierOption(
          id: 'sourdough',
          groupId: 'bread-type',
          name: 'Sourdough',
          extraPrice: 0,
          isDefault: true,
          stockStatus: StockStatus.inStock,
          isActive: true,
        ),
      ],
      assignedProductIds: <String>[],
    ),
  ];
}
