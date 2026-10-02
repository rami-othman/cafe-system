import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_api_client.dart';
import '../../../core/utils/backend_datetime.dart';
import '../models/shift_models.dart';
import '../models/shift_close_preview.dart';

/// Real shift API client. It intentionally maps one aggregate server payload
/// to the existing view models, keeping all calculation authority in Laravel.
class ShiftRepository {
  const ShiftRepository({this.apiClient});

  final DioApiClient? apiClient;
  DateTime get now => DateTime.now();

  Future<ShiftSnapshot?> loadOpenShift() async {
    final DioApiClient client = _client;
    try {
      final dynamic response = await client.get('shifts/current/snapshot');
      if (response == null) return null;
      return _snapshot(_map(response));
    } on ApiException catch (error) {
      throw ShiftDataException(_lifecycleMessage(error));
    }
  }

  Future<ShiftClosePreview> loadClosePreview(
    int shiftId, {
    DateTime? date,
  }) async {
    try {
      final String query = date == null
          ? ''
          : '?closingDate=${date.toIso8601String().substring(0, 10)}';
      final Map<String, dynamic> json = _map(
        await _client.get('shifts/$shiftId/close-preview$query'),
      );
      final Map<String, dynamic> period = _map(json['period']);
      return ShiftClosePreview(
        snapshot: _snapshot(_map(json['snapshot'])),
        date: DateTime.parse(period['closingDate'].toString()),
        openingDate: DateTime.parse(period['openingDate'].toString()),
        today: DateTime.parse(period['today'].toString()),
        timezone: period['timezone'].toString(),
        endExclusive: _date(period['periodEndExclusive']),
        historical: period['historical'] == true,
        version: period['version'].toString(),
        currentLedgerCash: _double(period['currentLedgerCash']),
        laterNetCash: _double(period['laterNetCash']),
        transferAmount: _double(period['transferAmount']),
        continuationCashAfterTransfer: _double(
          period['continuationCashAfterTransfer'],
        ),
        willContinue: period['willContinue'] == true,
        laterRecordCount: _map(
          period['laterRecords'],
        ).values.fold<int>(0, (sum, value) => sum + _int(value)),
        issues: (period['issues'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic value) => value.toString())
            .toList(),
        unexplainedCash: _double(period['unexplainedCash']),
        destinationName: period['destinationName']?.toString(),
        varianceAccountCode: period['varianceAccountCode']?.toString(),
        varianceAccountName: period['varianceAccountName']?.toString(),
        overAccountCode: period['overAccountCode']?.toString(),
        overAccountName: period['overAccountName']?.toString(),
      );
    } on ApiException catch (error) {
      throw ShiftDataException(_lifecycleMessage(error));
    }
  }

  Future<ShiftSnapshot> openShift({
    required double openingFloat,
    required String note,
    int? branchId,
  }) async {
    try {
      final int resolvedBranchId = await _resolveBranchId(branchId);
      await _client.post(
        'shifts/current',
        data: <String, dynamic>{
          'branchId': resolvedBranchId,
          'openingCash': openingFloat,
          if (note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      final ShiftSnapshot? snapshot = await loadOpenShift();
      if (snapshot == null) {
        throw const ShiftDataException(
          'The shift was opened but its snapshot could not be loaded.',
        );
      }
      return snapshot;
    } on ApiException catch (error) {
      throw ShiftDataException(_lifecycleMessage(error));
    }
  }

  Future<ShiftClosingResult> closeShift(ShiftClosingResult draft) async {
    try {
      final dynamic response = await _client.post(
        'shifts/${draft.snapshot.identity.id}/close',
        data: <String, dynamic>{
          'closingCash': draft.countedCashInput ?? draft.cash.actual,
          if (draft.previewVersion != null)
            'previewVersion': draft.previewVersion,
          if (draft.cashCountBasis != null)
            'cashCountBasis': draft.cashCountBasis,
          if (draft.barCountBasis != null) 'barCountBasis': draft.barCountBasis,
          if (draft.closingDate != null)
            'closingDate': draft.closingDate!.toIso8601String().substring(
              0,
              10,
            ),
          if (draft.cash.reason != null)
            'cashDifferenceReason': _reason(draft.cash.reason!),
          if (draft.cash.reasonDetail.trim().isNotEmpty)
            'cashDifferenceReasonDetail': draft.cash.reasonDetail.trim(),
          if (draft.closingNotes.trim().isNotEmpty)
            'note': draft.closingNotes.trim(),
          'barCountLines': draft.snapshot.barCount.lines
              .where((BarCountLine line) => line.counted != null)
              .map(
                (BarCountLine line) => <String, dynamic>{
                  'inventoryItemId': int.tryParse(line.id),
                  'counted': line.counted,
                  if (line.note.trim().isNotEmpty) 'reason': line.note.trim(),
                },
              )
              .where(
                (Map<String, dynamic> line) => line['inventoryItemId'] != null,
              )
              .toList(growable: false),
        },
      );
      return _closing(_map(response));
    } on ApiException catch (error) {
      throw ShiftDataException(_lifecycleMessage(error));
    }
  }

  Future<List<ShiftHistoryEntry>> loadHistory() async {
    try {
      final dynamic response = await _client.getEnvelope('shifts/history');
      final Map<String, dynamic> envelope = _map(response);
      return _list(envelope['data']).map(_history).toList(growable: false);
    } on ApiException catch (error) {
      throw ShiftDataException(_lifecycleMessage(error));
    }
  }

  Future<ShiftHistoryEntry?> loadLastShift() async {
    final List<ShiftHistoryEntry> history = await loadHistory();
    return history.isEmpty ? null : history.first;
  }

  Future<ShiftClosingResult?> loadClosingResult(String shiftNumber) async {
    try {
      final dynamic response = await _client.get('shifts/$shiftNumber/report');
      return _closing(_map(response));
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      throw ShiftDataException(_lifecycleMessage(error));
    }
  }

  /// Open/close failures carry the actionable, server-localized reason in a
  /// field error (drawer not configured, close destination missing, drawer
  /// already has an open shift, opening count differs from the drawer ledger,
  /// ...). Surface that instead of the generic "please correct the input".
  String _lifecycleMessage(ApiException error) {
    final Map<String, List<String>>? fields = error.validationErrors;
    if (fields != null) {
      for (final List<String> messages in fields.values) {
        if (messages.isNotEmpty && messages.first.trim().isNotEmpty) {
          return messages.first;
        }
      }
    }
    return error.message;
  }

  DioApiClient get _client {
    final DioApiClient? client = apiClient;
    if (client == null) {
      throw const ShiftDataException('The shift service is unavailable.');
    }
    return client;
  }

  Future<int> _resolveBranchId(int? preferred) async {
    if (preferred != null && preferred > 0) return preferred;
    final dynamic response = await _client.get('branches');
    final List<Map<String, dynamic>> branches = _list(response);
    final int? id = branches.isEmpty ? null : _int(branches.first['id']);
    if (id == null || id <= 0) {
      throw const ShiftDataException(
        'No operational branch is available for this shift.',
      );
    }
    return id;
  }

  ShiftSnapshot _snapshot(Map<String, dynamic> json) => ShiftSnapshot(
    identity: _identity(_map(json['identity'])),
    sales: _sales(_map(json['sales'])),
    payments: PaymentBreakdown(
      lines: _list(_map(json['payments'])['lines'])
          .map(
            (Map<String, dynamic> line) => PaymentBreakdownLine(
              channel: _channel(line['channel']),
              amount: _double(line['amount']),
              transactionCount: _int(line['transactionCount']),
            ),
          )
          .toList(growable: false),
    ),
    orders: _orders(_map(json['orders'])),
    drawer: _drawer(_map(json['drawer'])),
    barCount: _barCount(_map(json['barCount'])),
    pendingOperations: _list(
      json['pendingOperations'],
    ).map(_pending).toList(growable: false),
    refunds: _list(json['refunds']).map(_refund).toList(growable: false),
    discounts: _list(json['discounts']).map(_discount).toList(growable: false),
    openingNote: json['openingNote']?.toString() ?? '',
  );

  ShiftIdentity _identity(Map<String, dynamic> json) => ShiftIdentity(
    id: _int(json['id']),
    shiftNumber: json['shiftNumber']?.toString() ?? '',
    branchName: json['branchName']?.toString() ?? '',
    cashierName: json['cashierName']?.toString() ?? '',
    cashierCode: json['cashierCode']?.toString() ?? '',
    openedAt: _date(json['openedAt']),
    openedBy: json['openedBy']?.toString() ?? '',
    lifecycle: json['lifecycle'] == 'closed'
        ? ShiftLifecycle.closed
        : ShiftLifecycle.open,
    closedAt: _nullableDate(json['closedAt']),
    closedBy: json['closedBy']?.toString(),
  );

  ShiftSalesSummary _sales(Map<String, dynamic> json) => ShiftSalesSummary(
    grossSales: _double(json['grossSales']),
    discounts: _double(json['discounts']),
    refunds: _double(json['refunds']),
    refundCount: _int(json['refundCount']),
    orderCount: _int(json['orderCount']),
    cancelledOrderCount: _int(json['cancelledOrderCount']),
    discountPolicyCount: _int(json['discountPolicyCount']),
    salesSum: _double(json['salesSum']),
    salesTotal: _double(json['salesTotal']),
    salesNet: _double(json['salesNet']),
    purchasesPaid: _double(json['purchasesPaid']),
    expensesPaid: _double(json['expensesPaid']),
  );
  OrdersStatusSummary _orders(Map<String, dynamic> json) => OrdersStatusSummary(
    completed: _int(json['completed']),
    paid: _int(json['paid']),
    preparing: _int(json['preparing']),
    open: _int(json['open']),
    cancelled: _int(json['cancelled']),
    partiallyRefunded: _int(json['partiallyRefunded']),
    fullyRefunded: _int(json['fullyRefunded']),
    openOrders: _list(json['openOrders'])
        .map(
          (Map<String, dynamic> row) => OpenOrderRef(
            orderNumber: row['orderNumber']?.toString() ?? '',
            amount: _double(row['amount']),
            stateLabel: row['stateLabel']?.toString() ?? '',
          ),
        )
        .toList(growable: false),
  );
  CashDrawerSnapshot _drawer(Map<String, dynamic> json) => CashDrawerSnapshot(
    customerPayments: _double(json['customerPayments']),
    customerRefunds: _double(json['customerRefunds']),
    expectedCash: json['expectedCash'] == null
        ? null
        : _double(json['expectedCash']),
    openingFloat: _double(json['openingFloat']),
    cashSales: _double(json['cashSales']),
    cashRefunds: _double(json['cashRefunds']),
    withdrawals: _double(json['withdrawals']),
    deposits: _double(json['deposits']),
    expenses: _double(json['expenses']),
    movements: _list(json['movements'])
        .map(
          (Map<String, dynamic> row) => CashMovement(
            kind: _movement(row['kind']),
            occurredAt: _date(row['occurredAt']),
            description: row['description']?.toString() ?? '',
            amount: _double(row['amount']),
          ),
        )
        .toList(growable: false),
  );
  BarCountTemplate _barCount(Map<String, dynamic> json) => BarCountTemplate(
    warehouseName: json['warehouseName']?.toString() ?? '',
    lastCountedAt: _nullableDate(json['lastCountedAt']),
    lines: _list(json['lines'])
        .map(
          (Map<String, dynamic> row) => BarCountLine(
            id: row['id']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
            sku: row['sku']?.toString() ?? '',
            category: row['category']?.toString() ?? '',
            unit: row['unit']?.toString() ?? '',
            decimals: _int(row['decimals']),
            theoretical: _double(row['theoretical']),
            unitCost: _double(row['unitCost']),
            counted: row['counted'] == null ? null : _double(row['counted']),
            laterNetQuantity: _double(row['laterNetQuantity']),
          ),
        )
        .toList(growable: false),
  );
  PendingOperation _pending(Map<String, dynamic> json) => PendingOperation(
    kind: PendingOperationKind.barCount,
    reference: json['reference']?.toString() ?? '',
    detail: json['detail']?.toString() ?? '',
    blocking: json['blocking'] == true,
    amount: json['amount'] == null ? null : _double(json['amount']),
  );
  ShiftRefundEntry _refund(Map<String, dynamic> json) => ShiftRefundEntry(
    orderNumber: json['orderNumber']?.toString() ?? '',
    occurredAt: _date(json['occurredAt']),
    amount: _double(json['amount']),
    reason: json['reason']?.toString() ?? '',
    channel: _channel(json['channel']),
  );
  ShiftDiscountEntry _discount(Map<String, dynamic> json) => ShiftDiscountEntry(
    policyName: json['policyName']?.toString() ?? '',
    appliedCount: _int(json['appliedCount']),
    amount: _double(json['amount']),
  );
  ShiftHistoryEntry _history(Map<String, dynamic> json) => ShiftHistoryEntry(
    shiftNumber: json['shiftNumber']?.toString() ?? '',
    date: _date(json['date']),
    cashierName: json['cashierName']?.toString() ?? '',
    branchName: json['branchName']?.toString() ?? '',
    openedAt: _date(json['openedAt']),
    closedAt: _date(json['closedAt']),
    orderCount: _int(json['orderCount']),
    netSales: _double(json['netSales']),
    cashSales: _double(json['cashSales']),
    cashDifference: _double(json['cashDifference']),
    barDifferenceCount: _int(json['barDifferenceCount']),
    status: json['status'] == 'closedWithDifference'
        ? ShiftHistoryStatus.closedWithDifference
        : ShiftHistoryStatus.closed,
    closeMode: ShiftCloseMode.fromApi(json['closeType']),
    salesSum: json['salesSum'] == null ? null : _double(json['salesSum']),
    salesNet: json['salesNet'] == null ? null : _double(json['salesNet']),
    purchasesPaid: _double(json['purchasesPaid']),
    expensesPaid: _double(json['expensesPaid']),
  );
  ShiftClosingResult _closing(Map<String, dynamic> json) {
    final Map<String, dynamic> cash = _map(json['cash']);
    final Map<String, dynamic> period = _map(_map(json['snapshot'])['period']);
    final Map<String, dynamic>? varianceJson = json['variance'] is Map
        ? _map(json['variance'])
        : null;
    final Map<String, dynamic>? transferJson = json['transfer'] is Map
        ? _map(json['transfer'])
        : null;
    return ShiftClosingResult(
      snapshot: _snapshot(_map(json['snapshot'])),
      cash: CashCountResult(
        expected: _double(cash['expected']),
        actual: _double(cash['actual']),
        reason: _nullableReason(cash['reason']),
        reasonDetail: cash['reasonDetail']?.toString() ?? '',
      ),
      closingNotes: json['closingNotes']?.toString() ?? '',
      closedAt: _date(json['closedAt']),
      closedBy: json['closedBy']?.toString() ?? '',
      reportNumber: json['reportNumber']?.toString() ?? '',
      closeMode: ShiftCloseMode.fromApi(json['closeType']),
      closingDate: period['closingDate'] == null
          ? null
          : DateTime.parse(period['closingDate'].toString()),
      cashCountBasis: period['cashCountBasis']?.toString(),
      barCountBasis: period['barCountBasis']?.toString(),
      continuationShiftId: period['continuationShiftId'] == null
          ? null
          : _int(period['continuationShiftId']),
      closeExecutedAt: period['closeExecutedAt'] == null
          ? null
          : _date(period['closeExecutedAt']),
      variance: varianceJson == null
          ? null
          : ShiftCloseVariance(
              amount: _double(varianceJson['amount']),
              journalEntryId: varianceJson['journalEntryId'] == null
                  ? null
                  : _int(varianceJson['journalEntryId']),
              accountCode: varianceJson['accountCode']?.toString(),
              accountName: varianceJson['accountName']?.toString(),
            ),
      transfer: transferJson == null
          ? null
          : ShiftCloseTransfer(
              id: transferJson['id'] == null ? null : _int(transferJson['id']),
              amount: transferJson['amount'] == null
                  ? null
                  : _double(transferJson['amount']),
              date: transferJson['date'] == null
                  ? null
                  : _nullableDate(transferJson['date']),
              destinationName: transferJson['destinationName']?.toString(),
              floatLeft: _double(transferJson['floatLeft']),
              skippedReason: transferJson['skippedReason']?.toString(),
            ),
      unexplainedCash: _double(json['unexplainedCash']),
    );
  }

  PaymentChannel _channel(Object? value) => switch (value?.toString()) {
    'cash' => PaymentChannel.cash,
    'card' => PaymentChannel.card,
    'transfer' => PaymentChannel.transfer,
    'customerCredit' => PaymentChannel.customerCredit,
    _ => PaymentChannel.other,
  };
  CashMovementKind _movement(Object? value) => switch (value?.toString()) {
    'cashSale' => CashMovementKind.cashSale,
    'cashRefund' => CashMovementKind.cashRefund,
    'withdrawal' => CashMovementKind.withdrawal,
    'deposit' => CashMovementKind.deposit,
    'expense' => CashMovementKind.expense,
    _ => CashMovementKind.openingFloat,
  };
  CashDifferenceReason? _nullableReason(Object? value) => value == null
      ? null
      : switch (value.toString()) {
          'change_error' => CashDifferenceReason.changeError,
          'unrecorded_transaction' =>
            CashDifferenceReason.unrecordedTransaction,
          'unrecorded_withdrawal' => CashDifferenceReason.unrecordedWithdrawal,
          'unrecorded_expense' => CashDifferenceReason.unrecordedExpense,
          'unknown_surplus' => CashDifferenceReason.unknownSurplus,
          'unknown_shortage' => CashDifferenceReason.unknownShortage,
          'other' => CashDifferenceReason.other,
          _ => null,
        };
  String _reason(CashDifferenceReason value) => switch (value) {
    CashDifferenceReason.changeError => 'change_error',
    CashDifferenceReason.unrecordedTransaction => 'unrecorded_transaction',
    CashDifferenceReason.unrecordedWithdrawal => 'unrecorded_withdrawal',
    CashDifferenceReason.unrecordedExpense => 'unrecorded_expense',
    CashDifferenceReason.unknownSurplus => 'unknown_surplus',
    CashDifferenceReason.unknownShortage => 'unknown_shortage',
    CashDifferenceReason.other => 'other',
  };
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value.map(_map).toList(growable: false)
    : const <Map<String, dynamic>>[];
double _double(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
DateTime _date(Object? value) =>
    parseBackendDateTime(value?.toString()) ??
    DateTime.fromMillisecondsSinceEpoch(0);
DateTime? _nullableDate(Object? value) => value == null ? null : _date(value);

class ShiftDataException implements Exception {
  const ShiftDataException(this.message);
  final String message;
}
