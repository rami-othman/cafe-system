import 'package:equatable/equatable.dart';

/// WHAT prints on the customer receipt (section visibility, order, and
/// footer text). Kept separate from [PrinterConfig], which is HOW/WHERE a
/// receipt is printed.
enum ReceiptTemplateSection {
  header,
  orderInfo,
  items,
  totals,
  payment,
  footer;

  String get apiValue => switch (this) {
    ReceiptTemplateSection.header => 'header',
    ReceiptTemplateSection.orderInfo => 'orderInfo',
    ReceiptTemplateSection.items => 'items',
    ReceiptTemplateSection.totals => 'totals',
    ReceiptTemplateSection.payment => 'payment',
    ReceiptTemplateSection.footer => 'footer',
  };

  static ReceiptTemplateSection? fromApiValue(Object? value) => switch (value) {
    'header' => ReceiptTemplateSection.header,
    'orderInfo' => ReceiptTemplateSection.orderInfo,
    'items' => ReceiptTemplateSection.items,
    'totals' => ReceiptTemplateSection.totals,
    'payment' => ReceiptTemplateSection.payment,
    'footer' => ReceiptTemplateSection.footer,
    _ => null,
  };
}

class ReceiptTemplateHeader extends Equatable {
  const ReceiptTemplateHeader({
    this.showLogo = true,
    this.showCafeName = true,
    this.showBranchName = true,
    this.showAddress = true,
    this.showPhone = true,
  });

  factory ReceiptTemplateHeader.fromJson(Map<String, dynamic> json) =>
      ReceiptTemplateHeader(
        showLogo: json['showLogo'] != false,
        showCafeName: json['showCafeName'] != false,
        showBranchName: json['showBranchName'] != false,
        showAddress: json['showAddress'] != false,
        showPhone: json['showPhone'] != false,
      );

  final bool showLogo;
  final bool showCafeName;
  final bool showBranchName;
  final bool showAddress;
  final bool showPhone;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'showLogo': showLogo,
    'showCafeName': showCafeName,
    'showBranchName': showBranchName,
    'showAddress': showAddress,
    'showPhone': showPhone,
  };

  ReceiptTemplateHeader copyWith({
    bool? showLogo,
    bool? showCafeName,
    bool? showBranchName,
    bool? showAddress,
    bool? showPhone,
  }) => ReceiptTemplateHeader(
    showLogo: showLogo ?? this.showLogo,
    showCafeName: showCafeName ?? this.showCafeName,
    showBranchName: showBranchName ?? this.showBranchName,
    showAddress: showAddress ?? this.showAddress,
    showPhone: showPhone ?? this.showPhone,
  );

  @override
  List<Object?> get props => <Object?>[
    showLogo,
    showCafeName,
    showBranchName,
    showAddress,
    showPhone,
  ];
}

class ReceiptTemplateOrderInfo extends Equatable {
  const ReceiptTemplateOrderInfo({
    this.showOrderNumber = true,
    this.showDateTime = true,
    this.showCashier = true,
    this.showCustomer = false,
    this.showOrderType = true,
  });

  factory ReceiptTemplateOrderInfo.fromJson(Map<String, dynamic> json) =>
      ReceiptTemplateOrderInfo(
        showOrderNumber: json['showOrderNumber'] != false,
        showDateTime: json['showDateTime'] != false,
        showCashier: json['showCashier'] != false,
        showCustomer: json['showCustomer'] == true,
        showOrderType: json['showOrderType'] != false,
      );

  final bool showOrderNumber;
  final bool showDateTime;
  final bool showCashier;
  final bool showCustomer;
  final bool showOrderType;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'showOrderNumber': showOrderNumber,
    'showDateTime': showDateTime,
    'showCashier': showCashier,
    'showCustomer': showCustomer,
    'showOrderType': showOrderType,
  };

  ReceiptTemplateOrderInfo copyWith({
    bool? showOrderNumber,
    bool? showDateTime,
    bool? showCashier,
    bool? showCustomer,
    bool? showOrderType,
  }) => ReceiptTemplateOrderInfo(
    showOrderNumber: showOrderNumber ?? this.showOrderNumber,
    showDateTime: showDateTime ?? this.showDateTime,
    showCashier: showCashier ?? this.showCashier,
    showCustomer: showCustomer ?? this.showCustomer,
    showOrderType: showOrderType ?? this.showOrderType,
  );

  @override
  List<Object?> get props => <Object?>[
    showOrderNumber,
    showDateTime,
    showCashier,
    showCustomer,
    showOrderType,
  ];
}

class ReceiptTemplateItems extends Equatable {
  const ReceiptTemplateItems({
    this.showProductName = true,
    this.showQuantity = true,
    this.showUnitPrice = true,
    this.showModifiers = true,
    this.showNotes = true,
  });

  factory ReceiptTemplateItems.fromJson(Map<String, dynamic> json) =>
      ReceiptTemplateItems(
        showProductName: true,
        showQuantity: json['showQuantity'] != false,
        showUnitPrice: json['showUnitPrice'] != false,
        showModifiers: json['showModifiers'] != false,
        showNotes: json['showNotes'] != false,
      );

  /// Always true: a receipt with priced items and no names is meaningless.
  final bool showProductName;
  final bool showQuantity;
  final bool showUnitPrice;
  final bool showModifiers;
  final bool showNotes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'showProductName': showProductName,
    'showQuantity': showQuantity,
    'showUnitPrice': showUnitPrice,
    'showModifiers': showModifiers,
    'showNotes': showNotes,
  };

  ReceiptTemplateItems copyWith({
    bool? showQuantity,
    bool? showUnitPrice,
    bool? showModifiers,
    bool? showNotes,
  }) => ReceiptTemplateItems(
    showQuantity: showQuantity ?? this.showQuantity,
    showUnitPrice: showUnitPrice ?? this.showUnitPrice,
    showModifiers: showModifiers ?? this.showModifiers,
    showNotes: showNotes ?? this.showNotes,
  );

  @override
  List<Object?> get props => <Object?>[
    showProductName,
    showQuantity,
    showUnitPrice,
    showModifiers,
    showNotes,
  ];
}

class ReceiptTemplateTotals extends Equatable {
  const ReceiptTemplateTotals({
    this.showSubtotal = true,
    this.showDiscount = true,
    this.showTax = true,
    this.showTotal = true,
  });

  factory ReceiptTemplateTotals.fromJson(Map<String, dynamic> json) =>
      ReceiptTemplateTotals(
        showSubtotal: json['showSubtotal'] != false,
        showDiscount: json['showDiscount'] != false,
        showTax: json['showTax'] != false,
        showTotal: true,
      );

  final bool showSubtotal;
  final bool showDiscount;
  final bool showTax;

  /// Always true: a receipt with no total is meaningless.
  final bool showTotal;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'showSubtotal': showSubtotal,
    'showDiscount': showDiscount,
    'showTax': showTax,
    'showTotal': showTotal,
  };

  ReceiptTemplateTotals copyWith({
    bool? showSubtotal,
    bool? showDiscount,
    bool? showTax,
  }) => ReceiptTemplateTotals(
    showSubtotal: showSubtotal ?? this.showSubtotal,
    showDiscount: showDiscount ?? this.showDiscount,
    showTax: showTax ?? this.showTax,
  );

  @override
  List<Object?> get props => <Object?>[
    showSubtotal,
    showDiscount,
    showTax,
    showTotal,
  ];
}

class ReceiptTemplatePayment extends Equatable {
  const ReceiptTemplatePayment({
    this.showPaymentMethod = true,
    this.showPaidAmount = true,
    this.showChange = true,
  });

  factory ReceiptTemplatePayment.fromJson(Map<String, dynamic> json) =>
      ReceiptTemplatePayment(
        showPaymentMethod: json['showPaymentMethod'] != false,
        showPaidAmount: json['showPaidAmount'] != false,
        showChange: json['showChange'] != false,
      );

  final bool showPaymentMethod;
  final bool showPaidAmount;
  final bool showChange;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'showPaymentMethod': showPaymentMethod,
    'showPaidAmount': showPaidAmount,
    'showChange': showChange,
  };

  ReceiptTemplatePayment copyWith({
    bool? showPaymentMethod,
    bool? showPaidAmount,
    bool? showChange,
  }) => ReceiptTemplatePayment(
    showPaymentMethod: showPaymentMethod ?? this.showPaymentMethod,
    showPaidAmount: showPaidAmount ?? this.showPaidAmount,
    showChange: showChange ?? this.showChange,
  );

  @override
  List<Object?> get props => <Object?>[
    showPaymentMethod,
    showPaidAmount,
    showChange,
  ];
}

class ReceiptTemplateFooter extends Equatable {
  const ReceiptTemplateFooter({
    this.enabled = true,
    this.text = 'Thank you for visiting',
  });

  factory ReceiptTemplateFooter.fromJson(Map<String, dynamic> json) =>
      ReceiptTemplateFooter(
        enabled: json['enabled'] != false,
        text: json['text'] is String
            ? json['text'] as String
            : 'Thank you for visiting',
      );

  final bool enabled;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'text': text,
  };

  ReceiptTemplateFooter copyWith({bool? enabled, String? text}) =>
      ReceiptTemplateFooter(
        enabled: enabled ?? this.enabled,
        text: text ?? this.text,
      );

  @override
  List<Object?> get props => <Object?>[enabled, text];
}

const List<ReceiptTemplateSection> _defaultSectionOrder =
    <ReceiptTemplateSection>[
      ReceiptTemplateSection.header,
      ReceiptTemplateSection.orderInfo,
      ReceiptTemplateSection.items,
      ReceiptTemplateSection.totals,
      ReceiptTemplateSection.payment,
      ReceiptTemplateSection.footer,
    ];

class ReceiptTemplate extends Equatable {
  const ReceiptTemplate({
    this.header = const ReceiptTemplateHeader(),
    this.orderInfo = const ReceiptTemplateOrderInfo(),
    this.items = const ReceiptTemplateItems(),
    this.totals = const ReceiptTemplateTotals(),
    this.payment = const ReceiptTemplatePayment(),
    this.footer = const ReceiptTemplateFooter(),
    this.sectionOrder = _defaultSectionOrder,
  });

  /// Must match `ReceiptTemplateDefaults::array()` on the backend exactly.
  const ReceiptTemplate.defaultTemplate() : this();

  factory ReceiptTemplate.fromJson(Object? json) {
    if (json is! Map) return const ReceiptTemplate.defaultTemplate();
    final map = json.cast<String, dynamic>();
    final orderJson = map['sectionOrder'];
    final order = orderJson is List
        ? orderJson
              .map(ReceiptTemplateSection.fromApiValue)
              .whereType<ReceiptTemplateSection>()
              .toList()
        : const <ReceiptTemplateSection>[];

    return ReceiptTemplate(
      header: map['header'] is Map
          ? ReceiptTemplateHeader.fromJson((map['header'] as Map).cast())
          : const ReceiptTemplateHeader(),
      orderInfo: map['orderInfo'] is Map
          ? ReceiptTemplateOrderInfo.fromJson((map['orderInfo'] as Map).cast())
          : const ReceiptTemplateOrderInfo(),
      items: map['items'] is Map
          ? ReceiptTemplateItems.fromJson((map['items'] as Map).cast())
          : const ReceiptTemplateItems(),
      totals: map['totals'] is Map
          ? ReceiptTemplateTotals.fromJson((map['totals'] as Map).cast())
          : const ReceiptTemplateTotals(),
      payment: map['payment'] is Map
          ? ReceiptTemplatePayment.fromJson((map['payment'] as Map).cast())
          : const ReceiptTemplatePayment(),
      footer: map['footer'] is Map
          ? ReceiptTemplateFooter.fromJson((map['footer'] as Map).cast())
          : const ReceiptTemplateFooter(),
      sectionOrder: order.length == 6 ? order : _defaultSectionOrder,
    );
  }

  final ReceiptTemplateHeader header;
  final ReceiptTemplateOrderInfo orderInfo;
  final ReceiptTemplateItems items;
  final ReceiptTemplateTotals totals;
  final ReceiptTemplatePayment payment;
  final ReceiptTemplateFooter footer;
  final List<ReceiptTemplateSection> sectionOrder;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'header': header.toJson(),
    'orderInfo': orderInfo.toJson(),
    'items': items.toJson(),
    'totals': totals.toJson(),
    'payment': payment.toJson(),
    'footer': footer.toJson(),
    'sectionOrder': sectionOrder.map((s) => s.apiValue).toList(),
  };

  ReceiptTemplate copyWith({
    ReceiptTemplateHeader? header,
    ReceiptTemplateOrderInfo? orderInfo,
    ReceiptTemplateItems? items,
    ReceiptTemplateTotals? totals,
    ReceiptTemplatePayment? payment,
    ReceiptTemplateFooter? footer,
    List<ReceiptTemplateSection>? sectionOrder,
  }) => ReceiptTemplate(
    header: header ?? this.header,
    orderInfo: orderInfo ?? this.orderInfo,
    items: items ?? this.items,
    totals: totals ?? this.totals,
    payment: payment ?? this.payment,
    footer: footer ?? this.footer,
    sectionOrder: sectionOrder ?? this.sectionOrder,
  );

  /// Moves the section at [index] one place earlier/later, clamped to the
  /// list bounds. No-op if already at the edge in that direction.
  ReceiptTemplate moveSection(int index, {required bool up}) {
    final target = up ? index - 1 : index + 1;
    if (index < 0 ||
        index >= sectionOrder.length ||
        target < 0 ||
        target >= sectionOrder.length) {
      return this;
    }
    final reordered = List<ReceiptTemplateSection>.of(sectionOrder);
    final section = reordered.removeAt(index);
    reordered.insert(target, section);
    return copyWith(sectionOrder: reordered);
  }

  @override
  List<Object?> get props => <Object?>[
    header,
    orderInfo,
    items,
    totals,
    payment,
    footer,
    sectionOrder,
  ];
}
