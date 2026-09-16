import 'dart:async';

import '../models/shift_models.dart';
import '../models/shift_scenario.dart';

/// UI-phase data source for the shift module.
///
/// It is deliberately local: this task is a frontend approval pass, so no
/// endpoint is called and no contract is assumed. The shapes returned here
/// are the shapes the eventual API must fill — one snapshot per open shift,
/// one history page, one sealed closing result per closed shift.
///
/// Registered as a singleton so the overview, the closing wizard and the
/// report all observe the same scenario and the same freshly closed shift.
class ShiftMockRepository {
  ShiftMockRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  ShiftScenario _scenario = ShiftScenario.balanced;

  /// Closing results produced during this session, keyed by shift number, so
  /// the report route can render a shift the user just closed.
  final Map<String, ShiftClosingResult> _closedShifts =
      <String, ShiftClosingResult>{};

  ShiftSnapshot? _openShift;
  bool _openShiftLoaded = false;

  ShiftScenario get scenario => _scenario;

  DateTime get now => _clock();

  /// Simulated latency, short enough to keep the UI responsive while still
  /// exercising the loading states.
  static const Duration _latency = Duration(milliseconds: 260);

  void selectScenario(ShiftScenario scenario) {
    _scenario = scenario;
    _openShiftLoaded = false;
    _openShift = null;
  }

  /// Loads the shift currently open on this register, or null when none is.
  Future<ShiftSnapshot?> loadOpenShift() async {
    await Future<void>.delayed(_latency);
    if (_scenario == ShiftScenario.error) {
      throw const ShiftDataException('shift snapshot unavailable');
    }
    if (_scenario == ShiftScenario.loading) {
      // Never completes within a UI session: renders the loading skeleton.
      await Future<void>.delayed(const Duration(days: 1));
    }
    if (_scenario == ShiftScenario.noOpenShift) return null;
    if (!_openShiftLoaded) {
      _openShift = ShiftMockData.snapshotFor(_scenario, _clock());
      _openShiftLoaded = true;
    }
    return _openShift;
  }

  /// Opens a shift with the given float. Returns the new snapshot.
  Future<ShiftSnapshot> openShift({
    required double openingFloat,
    String note = '',
  }) async {
    await Future<void>.delayed(_latency);
    final DateTime now = _clock();
    final ShiftSnapshot base = ShiftMockData.freshSnapshot(
      now: now,
      openingFloat: openingFloat,
      openingNote: note,
    );
    _scenario = ShiftScenario.balanced;
    _openShift = base;
    _openShiftLoaded = true;
    return base;
  }

  Future<ShiftClosingResult> closeShift(ShiftClosingResult result) async {
    await Future<void>.delayed(_latency);
    _closedShifts[result.snapshot.identity.shiftNumber] = result;
    _openShift = null;
    _openShiftLoaded = true;
    _scenario = ShiftScenario.noOpenShift;
    return result;
  }

  Future<List<ShiftHistoryEntry>> loadHistory() async {
    await Future<void>.delayed(_latency);
    if (_scenario == ShiftScenario.error) {
      throw const ShiftDataException('shift history unavailable');
    }
    if (_scenario == ShiftScenario.loading) {
      await Future<void>.delayed(const Duration(days: 1));
    }
    final List<ShiftHistoryEntry> seeded = ShiftMockData.history(_clock());
    final List<ShiftHistoryEntry> closedThisSession = _closedShifts.values
        .map(ShiftMockData.historyEntryFor)
        .toList();
    return <ShiftHistoryEntry>[...closedThisSession, ...seeded];
  }

  /// The sealed report for a shift number, from this session or the seed set.
  Future<ShiftClosingResult?> loadClosingResult(String shiftNumber) async {
    await Future<void>.delayed(_latency);
    final ShiftClosingResult? fromSession = _closedShifts[shiftNumber];
    if (fromSession != null) return fromSession;
    return ShiftMockData.archivedResult(shiftNumber, _clock());
  }

  /// The most recently closed shift, shown as continuity on the "no open
  /// shift" screen.
  Future<ShiftHistoryEntry?> loadLastShift() async {
    final List<ShiftHistoryEntry> history = await loadHistory();
    return history.isEmpty ? null : history.first;
  }
}

class ShiftDataException implements Exception {
  const ShiftDataException(this.message);

  final String message;

  @override
  String toString() => 'ShiftDataException: $message';
}

/// Expressive fixtures for every shift scenario.
abstract final class ShiftMockData {
  static const String branchName = '618TierFour';
  static const String cashierName = 'tf-pos';
  static const String cashierCode = 'EMP-0142';
  static const String warehouseName = 'Bar - 618TierFour';
  static const String supervisorName = 'محمد العلي';

  /// Bank notes counted at the drawer, descending.
  static const List<int> denominations = <int>[
    50000,
    20000,
    10000,
    5000,
    2000,
    1000,
    500,
  ];

  static ShiftSnapshot snapshotFor(ShiftScenario scenario, DateTime now) {
    final DateTime openedAt = DateTime(
      now.year,
      now.month,
      now.day,
      8,
      15,
    );
    final ShiftIdentity identity = ShiftIdentity(
      shiftNumber: 'SH-${_compactDate(now)}-001',
      branchName: branchName,
      cashierName: cashierName,
      cashierCode: cashierCode,
      openedAt: openedAt,
      openedBy: cashierName,
      lifecycle: ShiftLifecycle.open,
    );

    final bool blocked = scenario == ShiftScenario.openOrderBlocker;

    return ShiftSnapshot(
      identity: identity,
      sales: const ShiftSalesSummary(
        grossSales: 24850,
        discounts: 450,
        refunds: 250,
        refundCount: 2,
        orderCount: 47,
        cancelledOrderCount: 3,
        discountPolicyCount: 2,
      ),
      payments: const PaymentBreakdown(
        lines: <PaymentBreakdownLine>[
          PaymentBreakdownLine(
            channel: PaymentChannel.cash,
            amount: 18250,
            transactionCount: 31,
          ),
          PaymentBreakdownLine(
            channel: PaymentChannel.card,
            amount: 6600,
            transactionCount: 12,
          ),
          PaymentBreakdownLine(
            channel: PaymentChannel.transfer,
            amount: 0,
            transactionCount: 0,
          ),
          PaymentBreakdownLine(
            channel: PaymentChannel.customerCredit,
            amount: 0,
            transactionCount: 0,
          ),
          PaymentBreakdownLine(
            channel: PaymentChannel.other,
            amount: 0,
            transactionCount: 0,
          ),
        ],
      ),
      orders: blocked
          ? const OrdersStatusSummary(
              completed: 42,
              paid: 44,
              preparing: 1,
              open: 1,
              cancelled: 3,
              partiallyRefunded: 1,
              fullyRefunded: 1,
              openOrders: <OpenOrderRef>[
                OpenOrderRef(
                  orderNumber: 'ORD-1048',
                  amount: 3500,
                  stateLabel: 'غير مدفوع',
                ),
                OpenOrderRef(
                  orderNumber: 'ORD-1051',
                  amount: 1800,
                  stateLabel: 'قيد التحضير',
                ),
              ],
            )
          : const OrdersStatusSummary(
              completed: 47,
              paid: 47,
              preparing: 0,
              open: 0,
              cancelled: 3,
              partiallyRefunded: 1,
              fullyRefunded: 1,
            ),
      drawer: CashDrawerSnapshot(
        openingFloat: 5000,
        cashSales: 18250,
        cashRefunds: 500,
        withdrawals: 1000,
        deposits: 0,
        expenses: 0,
        movements: _movements(now),
      ),
      barCount: BarCountTemplate(
        warehouseName: warehouseName,
        lastCountedAt: openedAt.subtract(const Duration(hours: 16, minutes: 10)),
        lines: _barLines(scenario),
      ),
      pendingOperations: blocked
          ? const <PendingOperation>[
              PendingOperation(
                kind: PendingOperationKind.refundApproval,
                reference: 'RF-2201',
                detail: 'مرتجع بانتظار اعتماد المشرف',
                blocking: false,
                amount: 900,
              ),
            ]
          : const <PendingOperation>[],
      refunds: <ShiftRefundEntry>[
        ShiftRefundEntry(
          orderNumber: 'ORD-1014',
          occurredAt: DateTime(now.year, now.month, now.day, 12, 30),
          amount: 500,
          reason: 'طلب خاطئ من العميل',
          channel: PaymentChannel.cash,
        ),
        ShiftRefundEntry(
          orderNumber: 'ORD-1032',
          occurredAt: DateTime(now.year, now.month, now.day, 14, 45),
          amount: 250,
          reason: 'مشروب غير مطابق للطلب',
          channel: PaymentChannel.card,
        ),
      ],
      discounts: const <ShiftDiscountEntry>[
        ShiftDiscountEntry(
          policyName: 'خصم الموظفين',
          appliedCount: 6,
          amount: 300,
        ),
        ShiftDiscountEntry(
          policyName: 'عرض الصباح',
          appliedCount: 3,
          amount: 150,
        ),
      ],
      openingNote: 'تم استلام الدرج من وردية المساء بالكامل.',
    );
  }

  /// A just-opened shift: no sales yet, drawer holds only the float.
  static ShiftSnapshot freshSnapshot({
    required DateTime now,
    required double openingFloat,
    String openingNote = '',
  }) => ShiftSnapshot(
    identity: ShiftIdentity(
      shiftNumber: 'SH-${_compactDate(now)}-002',
      branchName: branchName,
      cashierName: cashierName,
      cashierCode: cashierCode,
      openedAt: now,
      openedBy: cashierName,
      lifecycle: ShiftLifecycle.open,
    ),
    sales: const ShiftSalesSummary(
      grossSales: 0,
      discounts: 0,
      refunds: 0,
      refundCount: 0,
      orderCount: 0,
      cancelledOrderCount: 0,
      discountPolicyCount: 0,
    ),
    payments: const PaymentBreakdown(
      lines: <PaymentBreakdownLine>[
        PaymentBreakdownLine(
          channel: PaymentChannel.cash,
          amount: 0,
          transactionCount: 0,
        ),
        PaymentBreakdownLine(
          channel: PaymentChannel.card,
          amount: 0,
          transactionCount: 0,
        ),
      ],
    ),
    orders: const OrdersStatusSummary(
      completed: 0,
      paid: 0,
      preparing: 0,
      open: 0,
      cancelled: 0,
      partiallyRefunded: 0,
      fullyRefunded: 0,
    ),
    drawer: CashDrawerSnapshot(
      openingFloat: openingFloat,
      cashSales: 0,
      cashRefunds: 0,
      withdrawals: 0,
      deposits: 0,
      expenses: 0,
      movements: <CashMovement>[
        CashMovement(
          kind: CashMovementKind.openingFloat,
          occurredAt: now,
          description: 'رصيد افتتاحي عند فتح الوردية',
          amount: openingFloat,
        ),
      ],
    ),
    barCount: BarCountTemplate(
      warehouseName: warehouseName,
      lastCountedAt: now.subtract(const Duration(hours: 16)),
      lines: _barLines(ShiftScenario.balanced),
    ),
    pendingOperations: const <PendingOperation>[],
    refunds: const <ShiftRefundEntry>[],
    discounts: const <ShiftDiscountEntry>[],
    openingNote: openingNote,
  );

  static List<CashMovement> _movements(DateTime now) => <CashMovement>[
    CashMovement(
      kind: CashMovementKind.openingFloat,
      occurredAt: DateTime(now.year, now.month, now.day, 8, 15),
      description: 'رصيد افتتاحي عند فتح الوردية',
      amount: 5000,
    ),
    CashMovement(
      kind: CashMovementKind.cashSale,
      occurredAt: DateTime(now.year, now.month, now.day, 9, 22),
      description: 'ORD-1021',
      amount: 3200,
    ),
    CashMovement(
      kind: CashMovementKind.cashSale,
      occurredAt: DateTime(now.year, now.month, now.day, 11, 5),
      description: 'ORD-1027',
      amount: 7450,
    ),
    CashMovement(
      kind: CashMovementKind.cashRefund,
      occurredAt: DateTime(now.year, now.month, now.day, 12, 30),
      description: 'ORD-1014',
      amount: -500,
    ),
    CashMovement(
      kind: CashMovementKind.cashSale,
      occurredAt: DateTime(now.year, now.month, now.day, 13, 40),
      description: 'ORD-1036',
      amount: 7600,
    ),
    CashMovement(
      kind: CashMovementKind.withdrawal,
      occurredAt: DateTime(now.year, now.month, now.day, 14, 0),
      description: 'توريد للصندوق الرئيسي',
      amount: -1000,
    ),
  ];

  /// The bar template. Scenarios differ only in which quantities arrive
  /// pre-counted and whether a theoretical balance is negative.
  static List<BarCountLine> _barLines(ShiftScenario scenario) {
    final bool prefill = scenario.prefillsCounts;
    final bool variance = scenario == ShiftScenario.stockVariance;
    final bool negative = scenario == ShiftScenario.negativeStock;
    final bool partial = scenario == ShiftScenario.incompleteCount;

    double? counted(double theoretical, double delta, {bool skip = false}) {
      if (skip) return null;
      if (!prefill && !partial) return null;
      return theoretical + (variance || negative ? delta : 0);
    }

    return <BarCountLine>[
      BarCountLine(
        id: 'itm-001',
        name: 'بن كلاسيك',
        sku: 'INV-COF-001',
        category: 'قهوة',
        unit: 'kg',
        decimals: 2,
        theoretical: 4.20,
        unitCost: 16000,
        counted: partial ? 4.20 : counted(4.20, -0.20),
      ),
      BarCountLine(
        id: 'itm-002',
        name: 'حليب طازج',
        sku: 'INV-DRY-004',
        category: 'ألبان',
        unit: 'حبة',
        decimals: 0,
        theoretical: 12,
        unitCost: 2500,
        counted: partial ? 14 : counted(12, 2),
      ),
      BarCountLine(
        id: 'itm-003',
        name: 'سكر أبيض',
        sku: 'INV-GRO-011',
        category: 'مواد جافة',
        unit: 'kg',
        decimals: 2,
        theoretical: 8.50,
        unitCost: 3200,
        counted: partial ? 8.50 : counted(8.50, 0),
      ),
      BarCountLine(
        id: 'itm-004',
        name: 'كريمة خفق',
        sku: 'INV-DRY-009',
        category: 'ألبان',
        unit: 'لتر',
        decimals: 2,
        theoretical: negative ? -2.00 : 3.00,
        unitCost: 9000,
        counted: partial ? null : counted(negative ? -2.00 : 3.00, 0.20),
      ),
      BarCountLine(
        id: 'itm-005',
        name: 'شوكولاتة داكنة',
        sku: 'INV-GRO-023',
        category: 'مواد جافة',
        unit: 'kg',
        decimals: 2,
        theoretical: 2.50,
        unitCost: 22000,
        counted: partial ? 2.50 : counted(2.50, 0),
      ),
      BarCountLine(
        id: 'itm-006',
        name: 'شراب فانيلا',
        sku: 'INV-SYR-002',
        category: 'شرابات',
        unit: 'لتر',
        decimals: 2,
        theoretical: 1.80,
        unitCost: 14000,
        counted: partial ? 1.80 : counted(1.80, 0),
      ),
      BarCountLine(
        id: 'itm-007',
        name: 'أكواب ورقية وسط',
        sku: 'INV-PKG-014',
        category: 'تغليف',
        unit: 'قطعة',
        decimals: 0,
        theoretical: 300,
        unitCost: 250,
        counted: partial ? 300 : counted(300, 0),
      ),
      BarCountLine(
        id: 'itm-008',
        name: 'مناديل ورقية',
        sku: 'INV-PKG-021',
        category: 'تغليف',
        unit: 'حبة',
        decimals: 0,
        theoretical: 150,
        unitCost: 120,
        counted: partial ? 150 : counted(150, 0),
      ),
      BarCountLine(
        id: 'itm-009',
        name: 'عصير برتقال',
        sku: 'INV-BEV-006',
        category: 'مشروبات',
        unit: 'لتر',
        decimals: 2,
        theoretical: 4.00,
        unitCost: 6500,
        counted: partial ? null : counted(4.00, 0),
      ),
      BarCountLine(
        id: 'itm-010',
        name: 'مياه غازية',
        sku: 'INV-BEV-012',
        category: 'مشروبات',
        unit: 'حبة',
        decimals: 0,
        theoretical: 48,
        unitCost: 1500,
        counted: partial ? null : counted(48, 0),
      ),
      BarCountLine(
        id: 'itm-011',
        name: 'شاي أخضر',
        sku: 'INV-TEA-003',
        category: 'شاي',
        unit: 'علبة',
        decimals: 0,
        theoretical: 6,
        unitCost: 8000,
        counted: partial ? 6 : counted(6, 0),
      ),
      BarCountLine(
        id: 'itm-012',
        name: 'نعناع طازج',
        sku: 'INV-HRB-005',
        category: 'أعشاب',
        unit: 'حبة',
        decimals: 0,
        theoretical: 20,
        unitCost: 700,
        counted: partial ? 20 : counted(20, 0),
      ),
    ];
  }

  /// Seeded closed shifts for the history screen.
  static List<ShiftHistoryEntry> history(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    return <ShiftHistoryEntry>[
      _historyEntry(
        number: 'SH-${_compactDate(today.subtract(const Duration(days: 1)))}-002',
        day: today.subtract(const Duration(days: 1)),
        cashier: 'tf-pos',
        openHour: 16,
        openMinute: 5,
        closeHour: 23,
        closeMinute: 50,
        orders: 38,
        netSales: 19640,
        cashSales: 14100,
        cashDifference: 0,
        barDifferences: 0,
      ),
      _historyEntry(
        number: 'SH-${_compactDate(today.subtract(const Duration(days: 1)))}-001',
        day: today.subtract(const Duration(days: 1)),
        cashier: 'sm-pos',
        openHour: 8,
        openMinute: 0,
        closeHour: 16,
        closeMinute: 2,
        orders: 51,
        netSales: 26340,
        cashSales: 19870,
        cashDifference: -200,
        barDifferences: 2,
      ),
      _historyEntry(
        number: 'SH-${_compactDate(today.subtract(const Duration(days: 2)))}-002',
        day: today.subtract(const Duration(days: 2)),
        cashier: 'tf-pos',
        openHour: 15,
        openMinute: 55,
        closeHour: 23,
        closeMinute: 40,
        orders: 33,
        netSales: 17480,
        cashSales: 12250,
        cashDifference: 150,
        barDifferences: 1,
      ),
      _historyEntry(
        number: 'SH-${_compactDate(today.subtract(const Duration(days: 3)))}-001',
        day: today.subtract(const Duration(days: 3)),
        cashier: 'sm-pos',
        openHour: 8,
        openMinute: 10,
        closeHour: 16,
        closeMinute: 0,
        orders: 44,
        netSales: 22110,
        cashSales: 16400,
        cashDifference: 0,
        barDifferences: 0,
      ),
      _historyEntry(
        number: 'SH-${_compactDate(today.subtract(const Duration(days: 6)))}-001',
        day: today.subtract(const Duration(days: 6)),
        cashier: 'nb-pos',
        openHour: 8,
        openMinute: 5,
        closeHour: 15,
        closeMinute: 58,
        orders: 29,
        netSales: 15020,
        cashSales: 11080,
        cashDifference: -60,
        barDifferences: 1,
      ),
      _historyEntry(
        number: 'SH-${_compactDate(today.subtract(const Duration(days: 12)))}-001',
        day: today.subtract(const Duration(days: 12)),
        cashier: 'tf-pos',
        openHour: 8,
        openMinute: 0,
        closeHour: 16,
        closeMinute: 15,
        orders: 47,
        netSales: 24180,
        cashSales: 17640,
        cashDifference: 0,
        barDifferences: 0,
      ),
      _historyEntry(
        number: 'SH-${_compactDate(today.subtract(const Duration(days: 19)))}-001',
        day: today.subtract(const Duration(days: 19)),
        cashier: 'sm-pos',
        openHour: 8,
        openMinute: 20,
        closeHour: 16,
        closeMinute: 30,
        orders: 40,
        netSales: 20890,
        cashSales: 15310,
        cashDifference: 320,
        barDifferences: 3,
      ),
    ];
  }

  static ShiftHistoryEntry _historyEntry({
    required String number,
    required DateTime day,
    required String cashier,
    required int openHour,
    required int openMinute,
    required int closeHour,
    required int closeMinute,
    required int orders,
    required double netSales,
    required double cashSales,
    required double cashDifference,
    required int barDifferences,
  }) => ShiftHistoryEntry(
    shiftNumber: number,
    date: day,
    cashierName: cashier,
    branchName: branchName,
    openedAt: DateTime(day.year, day.month, day.day, openHour, openMinute),
    closedAt: DateTime(day.year, day.month, day.day, closeHour, closeMinute),
    orderCount: orders,
    netSales: netSales,
    cashSales: cashSales,
    cashDifference: cashDifference,
    barDifferenceCount: barDifferences,
    status: cashDifference.abs() <= 0.5 && barDifferences == 0
        ? ShiftHistoryStatus.closed
        : ShiftHistoryStatus.closedWithDifference,
  );

  static ShiftHistoryEntry historyEntryFor(ShiftClosingResult result) =>
      ShiftHistoryEntry(
        shiftNumber: result.snapshot.identity.shiftNumber,
        date: DateTime(
          result.closedAt.year,
          result.closedAt.month,
          result.closedAt.day,
        ),
        cashierName: result.snapshot.identity.cashierName,
        branchName: result.snapshot.identity.branchName,
        openedAt: result.snapshot.identity.openedAt,
        closedAt: result.closedAt,
        orderCount: result.snapshot.sales.orderCount,
        netSales: result.snapshot.sales.netSales,
        cashSales: result.snapshot.drawer.cashSales,
        cashDifference: result.cash.difference,
        barDifferenceCount: result.snapshot.barCount.differenceItems,
        status:
            result.cash.isBalanced &&
                result.snapshot.barCount.differenceItems == 0
            ? ShiftHistoryStatus.closed
            : ShiftHistoryStatus.closedWithDifference,
      );

  /// Rebuilds a sealed report for a seeded (archived) shift so the report
  /// route works for history rows as well as freshly closed shifts.
  static ShiftClosingResult? archivedResult(String shiftNumber, DateTime now) {
    final ShiftHistoryEntry? entry = history(now)
        .where((ShiftHistoryEntry e) => e.shiftNumber == shiftNumber)
        .firstOrNull;
    if (entry == null) return null;

    final ShiftSnapshot base = snapshotFor(
      entry.barDifferenceCount > 0
          ? ShiftScenario.stockVariance
          : ShiftScenario.balanced,
      entry.closedAt,
    );
    final ShiftSnapshot archived = base.copyWith(
      identity: ShiftIdentity(
        shiftNumber: entry.shiftNumber,
        branchName: entry.branchName,
        cashierName: entry.cashierName,
        cashierCode: cashierCode,
        openedAt: entry.openedAt,
        openedBy: entry.cashierName,
        lifecycle: ShiftLifecycle.closed,
        closedAt: entry.closedAt,
        closedBy: entry.cashierName,
      ),
    );
    return ShiftClosingResult(
      snapshot: archived,
      cash: CashCountResult(
        expected: archived.drawer.expected,
        actual: archived.drawer.expected + entry.cashDifference,
        reason: entry.cashDifference.abs() <= 0.5
            ? null
            : entry.cashDifference < 0
            ? CashDifferenceReason.changeError
            : CashDifferenceReason.unknownSurplus,
        reasonDetail: entry.cashDifference.abs() <= 0.5
            ? ''
            : 'تم رصد الفرق أثناء جرد نهاية الوردية.',
      ),
      closingNotes: '',
      closedAt: entry.closedAt,
      closedBy: entry.cashierName,
      reportNumber: 'RPT-${entry.shiftNumber.replaceFirst('SH-', '')}',
    );
  }

  static String _compactDate(DateTime value) =>
      '${value.year}${_two(value.month)}${_two(value.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
