import '../../pos/models/json_helpers.dart';
import '../../../core/utils/backend_datetime.dart';

/// Whether a figure describes the Cashier's own open shift or only their
/// branch. Every card on the dashboard labels its scope from this, so a
/// shift number is never shown beside a branch-wide one without saying so.
enum CashierScopeKind { currentShift, branchOnly }

class CashierScope {
  const CashierScope({
    required this.kind,
    required this.branchId,
    required this.branchName,
    required this.cashierId,
    required this.cashierName,
    required this.currency,
  });

  final CashierScopeKind kind;
  final int? branchId;
  final String branchName;
  final int cashierId;
  final String cashierName;
  final String currency;

  factory CashierScope.fromJson(Map<String, dynamic> json) => CashierScope(
    kind: readString(json['kind']) == 'current_shift'
        ? CashierScopeKind.currentShift
        : CashierScopeKind.branchOnly,
    branchId: readInt(json['branchId']),
    branchName: readString(json['branchName']),
    cashierId: readInt(json['cashierId']) ?? 0,
    cashierName: readString(json['cashierName']),
    currency: readString(json['currency'], fallback: 'SYP'),
  );

  static const CashierScope empty = CashierScope(
    kind: CashierScopeKind.branchOnly,
    branchId: null,
    branchName: '',
    cashierId: 0,
    cashierName: '',
    currency: 'SYP',
  );
}

class CashierShift {
  const CashierShift({
    required this.id,
    required this.status,
    required this.openedAt,
    required this.durationSeconds,
  });

  final int id;
  final String status;
  final DateTime? openedAt;
  final int durationSeconds;

  factory CashierShift.fromJson(Map<String, dynamic> json) => CashierShift(
    id: readInt(json['id']) ?? 0,
    status: readString(json['status']),
    openedAt: parseBackendDateTime(readString(json['openedAt'])),
    durationSeconds: readInt(json['durationSeconds']) ?? 0,
  );
}

/// Expected drawer cash only. The physically counted amount is deliberately
/// absent from this model: it belongs to the shift-close flow, and a dashboard
/// that showed the expected figure as "actual" would defeat the cash control.
class CashierCashDrawer {
  const CashierCashDrawer({
    required this.available,
    required this.openingCash,
    required this.cashSales,
    required this.cashRefunds,
    required this.expectedCash,
    required this.cashSaleCount,
    required this.cashRefundCount,
  });

  final bool available;
  final String openingCash;
  final String cashSales;
  final String cashRefunds;
  final String expectedCash;
  final int cashSaleCount;
  final int cashRefundCount;

  factory CashierCashDrawer.fromJson(Map<String, dynamic> json) =>
      CashierCashDrawer(
        available: readBool(json['available']),
        openingCash: readString(json['openingCash'], fallback: '0.00'),
        cashSales: readString(json['cashSales'], fallback: '0.00'),
        cashRefunds: readString(json['cashRefunds'], fallback: '0.00'),
        expectedCash: readString(json['expectedCash'], fallback: '0.00'),
        cashSaleCount: readInt(json['cashSaleCount']) ?? 0,
        cashRefundCount: readInt(json['cashRefundCount']) ?? 0,
      );

  static const CashierCashDrawer empty = CashierCashDrawer(
    available: false,
    openingCash: '0.00',
    cashSales: '0.00',
    cashRefunds: '0.00',
    expectedCash: '0.00',
    cashSaleCount: 0,
    cashRefundCount: 0,
  );
}

class CashierPaymentSplit {
  const CashierPaymentSplit({
    required this.method,
    required this.count,
    required this.amount,
  });

  final String method;
  final int count;
  final String amount;

  factory CashierPaymentSplit.fromJson(Map<String, dynamic> json) =>
      CashierPaymentSplit(
        method: readString(json['method']),
        count: readInt(json['count']) ?? 0,
        amount: readString(json['amount'], fallback: '0.00'),
      );
}

/// Turnover for the shift. There is no cost, margin, or profit member here by
/// design — the endpoint does not send one for any role.
class CashierSales {
  const CashierSales({
    required this.available,
    required this.netSales,
    required this.grossSales,
    required this.discounts,
    required this.refunds,
    required this.orderCount,
    required this.averageOrderValue,
    required this.byMethod,
  });

  final bool available;
  final String netSales;
  final String grossSales;
  final String discounts;
  final String refunds;
  final int orderCount;
  final String averageOrderValue;
  final List<CashierPaymentSplit> byMethod;

  String amountFor(String method) => byMethod
      .firstWhere(
        (CashierPaymentSplit split) => split.method == method,
        orElse: () => const CashierPaymentSplit(
          method: '',
          count: 0,
          amount: '0.00',
        ),
      )
      .amount;

  /// Everything that is neither cash nor card, summed for a single tile.
  int get otherMethodCount => byMethod
      .where(
        (CashierPaymentSplit split) =>
            split.method != 'cash' && split.method != 'card',
      )
      .fold(0, (int total, CashierPaymentSplit split) => total + split.count);

  factory CashierSales.fromJson(Map<String, dynamic> json) => CashierSales(
    available: readBool(json['available']),
    netSales: readString(json['netSales'], fallback: '0.00'),
    grossSales: readString(json['grossSales'], fallback: '0.00'),
    discounts: readString(json['discounts'], fallback: '0.00'),
    refunds: readString(json['refunds'], fallback: '0.00'),
    orderCount: readInt(json['orderCount']) ?? 0,
    averageOrderValue: readString(json['averageOrderValue'], fallback: '0.00'),
    byMethod: readMapList(
      json['byMethod'],
    ).map(CashierPaymentSplit.fromJson).toList(growable: false),
  );

  static const CashierSales empty = CashierSales(
    available: false,
    netSales: '0.00',
    grossSales: '0.00',
    discounts: '0.00',
    refunds: '0.00',
    orderCount: 0,
    averageOrderValue: '0.00',
    byMethod: <CashierPaymentSplit>[],
  );
}

class CashierOrders {
  const CashierOrders({
    required this.active,
    required this.held,
    required this.completed,
    required this.blockingCount,
  });

  final int active;
  final int held;
  final int completed;

  /// Orders a shift close still has to resolve.
  final int blockingCount;

  factory CashierOrders.fromJson(Map<String, dynamic> json) => CashierOrders(
    active: readInt(json['active']) ?? 0,
    held: readInt(json['held']) ?? 0,
    completed: readInt(json['completed']) ?? 0,
    blockingCount: readInt(json['blockingCount']) ?? 0,
  );

  static const CashierOrders empty = CashierOrders(
    active: 0,
    held: 0,
    completed: 0,
    blockingCount: 0,
  );
}

class CashierShiftCountStatus {
  const CashierShiftCountStatus({
    required this.required,
    required this.completed,
    required this.pendingTemplates,
  });

  final bool required;
  final bool completed;
  final int pendingTemplates;

  factory CashierShiftCountStatus.fromJson(Map<String, dynamic> json) =>
      CashierShiftCountStatus(
        required: readBool(json['required']),
        completed: readBool(json['completed']),
        pendingTemplates: readInt(json['pendingTemplates']) ?? 0,
      );

  static const CashierShiftCountStatus empty = CashierShiftCountStatus(
    required: false,
    completed: false,
    pendingTemplates: 0,
  );
}

/// Quantities for the POS warehouse. No valuation member exists here because
/// the endpoint never sends one.
class CashierInventorySummary {
  const CashierInventorySummary({
    required this.warehouseId,
    required this.warehouseName,
    required this.configured,
    required this.ambiguous,
    required this.totalItems,
    required this.lowStockCount,
    required this.zeroStockCount,
    required this.negativeStockCount,
    required this.shiftCount,
  });

  final int? warehouseId;
  final String warehouseName;
  final bool configured;
  final bool ambiguous;
  final int totalItems;
  final int lowStockCount;
  final int zeroStockCount;
  final int negativeStockCount;
  final CashierShiftCountStatus shiftCount;

  factory CashierInventorySummary.fromJson(Map<String, dynamic> json) =>
      CashierInventorySummary(
        warehouseId: readInt(json['warehouseId']),
        warehouseName: readString(json['warehouseName']),
        configured: readBool(json['configured']),
        ambiguous: readBool(json['ambiguous']),
        totalItems: readInt(json['totalItems']) ?? 0,
        lowStockCount: readInt(json['lowStockCount']) ?? 0,
        zeroStockCount: readInt(json['zeroStockCount']) ?? 0,
        negativeStockCount: readInt(json['negativeStockCount']) ?? 0,
        shiftCount: CashierShiftCountStatus.fromJson(
          json['shiftCount'] is Map
              ? Map<String, dynamic>.from(json['shiftCount'] as Map)
              : const <String, dynamic>{},
        ),
      );

  static const CashierInventorySummary empty = CashierInventorySummary(
    warehouseId: null,
    warehouseName: '',
    configured: false,
    ambiguous: false,
    totalItems: 0,
    lowStockCount: 0,
    zeroStockCount: 0,
    negativeStockCount: 0,
    shiftCount: CashierShiftCountStatus.empty,
  );
}

class CashierVoucherTotals {
  const CashierVoucherTotals({required this.count, required this.cashTotal});

  final int count;
  final String cashTotal;

  factory CashierVoucherTotals.fromJson(Map<String, dynamic> json) =>
      CashierVoucherTotals(
        count: readInt(json['count']) ?? 0,
        cashTotal: readString(json['cashTotal'], fallback: '0.00'),
      );
}

/// Counts and cash totals for documents this Cashier raised in this shift.
/// A null block means the actor lacks the matching finance permission, so the
/// section is not rendered at all.
class CashierFinance {
  const CashierFinance({
    required this.capabilities,
    required this.receiptVouchers,
    required this.paymentVouchers,
    required this.purchaseDocumentCount,
    required this.salesInvoiceCount,
  });

  final Set<String> capabilities;
  final CashierVoucherTotals? receiptVouchers;
  final CashierVoucherTotals? paymentVouchers;
  final int? purchaseDocumentCount;
  final int? salesInvoiceCount;

  bool allows(String capability) => capabilities.contains(capability);

  factory CashierFinance.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> raw = json['capabilities'] is Map
        ? Map<String, dynamic>.from(json['capabilities'] as Map)
        : const <String, dynamic>{};
    return CashierFinance(
      capabilities: raw.entries
          .where((MapEntry<String, dynamic> entry) => readBool(entry.value))
          .map((MapEntry<String, dynamic> entry) => entry.key)
          .toSet(),
      receiptVouchers: json['receiptVouchers'] is Map
          ? CashierVoucherTotals.fromJson(
              Map<String, dynamic>.from(json['receiptVouchers'] as Map),
            )
          : null,
      paymentVouchers: json['paymentVouchers'] is Map
          ? CashierVoucherTotals.fromJson(
              Map<String, dynamic>.from(json['paymentVouchers'] as Map),
            )
          : null,
      purchaseDocumentCount: readInt(json['purchaseDocumentCount']),
      salesInvoiceCount: readInt(json['salesInvoiceCount']),
    );
  }

  static const CashierFinance empty = CashierFinance(
    capabilities: <String>{},
    receiptVouchers: null,
    paymentVouchers: null,
    purchaseDocumentCount: null,
    salesInvoiceCount: null,
  );
}

class CashierAlert {
  const CashierAlert({
    required this.severity,
    required this.code,
    required this.count,
  });

  final String severity;
  final String code;
  final int? count;

  factory CashierAlert.fromJson(Map<String, dynamic> json) => CashierAlert(
    severity: readString(json['severity'], fallback: 'info'),
    code: readString(json['code']),
    count: readInt(json['count']),
  );
}

class CashierDashboard {
  const CashierDashboard({
    required this.scope,
    required this.shift,
    required this.cashDrawer,
    required this.sales,
    required this.orders,
    required this.inventory,
    required this.finance,
    required this.alerts,
  });

  final CashierScope scope;
  final CashierShift? shift;
  final CashierCashDrawer cashDrawer;
  final CashierSales sales;
  final CashierOrders orders;
  final CashierInventorySummary inventory;
  final CashierFinance finance;
  final List<CashierAlert> alerts;

  bool get hasOpenShift => shift != null;

  factory CashierDashboard.fromJson(Map<String, dynamic> json) =>
      CashierDashboard(
        scope: CashierScope.fromJson(_map(json['scope'])),
        shift: json['shift'] is Map
            ? CashierShift.fromJson(Map<String, dynamic>.from(json['shift'] as Map))
            : null,
        cashDrawer: CashierCashDrawer.fromJson(_map(json['cashDrawer'])),
        sales: CashierSales.fromJson(_map(json['sales'])),
        orders: CashierOrders.fromJson(_map(json['orders'])),
        inventory: CashierInventorySummary.fromJson(_map(json['inventory'])),
        finance: CashierFinance.fromJson(_map(json['finance'])),
        alerts: readMapList(
          json['alerts'],
        ).map(CashierAlert.fromJson).toList(growable: false),
      );

  static const CashierDashboard empty = CashierDashboard(
    scope: CashierScope.empty,
    shift: null,
    cashDrawer: CashierCashDrawer.empty,
    sales: CashierSales.empty,
    orders: CashierOrders.empty,
    inventory: CashierInventorySummary.empty,
    finance: CashierFinance.empty,
    alerts: <CashierAlert>[],
  );
}

class CashierStockRow {
  const CashierStockRow({
    required this.itemId,
    required this.nameAr,
    required this.nameEn,
    required this.sku,
    required this.unit,
    required this.quantity,
    required this.state,
    required this.lastMovementAt,
  });

  final int itemId;
  final String nameAr;
  final String nameEn;
  final String sku;
  final String unit;
  final String quantity;

  /// One of `normal`, `low`, `zero`, `negative`.
  final String state;
  final DateTime? lastMovementAt;

  factory CashierStockRow.fromJson(Map<String, dynamic> json) =>
      CashierStockRow(
        itemId: readInt(json['itemId']) ?? 0,
        nameAr: readString(json['nameAr']),
        nameEn: readString(json['nameEn']),
        sku: readString(json['sku']),
        unit: readString(json['unit']),
        quantity: readString(json['quantity'], fallback: '0.000'),
        state: readString(json['state'], fallback: 'normal'),
        lastMovementAt: parseBackendDateTime(readString(json['lastMovementAt'])),
      );
}

class CashierStockPage {
  const CashierStockPage({
    required this.warehouseName,
    required this.configured,
    required this.items,
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  final String warehouseName;
  final bool configured;
  final List<CashierStockRow> items;
  final int total;
  final int currentPage;
  final int lastPage;

  factory CashierStockPage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> meta = _map(json['meta']);
    return CashierStockPage(
      warehouseName: readString(json['warehouseName']),
      configured: readBool(json['configured']),
      items: readMapList(
        json['items'],
      ).map(CashierStockRow.fromJson).toList(growable: false),
      total: readInt(meta['total']) ?? 0,
      currentPage: readInt(meta['currentPage']) ?? 1,
      lastPage: readInt(meta['lastPage']) ?? 1,
    );
  }

  static const CashierStockPage empty = CashierStockPage(
    warehouseName: '',
    configured: false,
    items: <CashierStockRow>[],
    total: 0,
    currentPage: 1,
    lastPage: 1,
  );
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};
