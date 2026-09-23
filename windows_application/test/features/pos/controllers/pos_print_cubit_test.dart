import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/controllers/pos_print_cubit.dart';
import 'package:windows_application/features/pos/controllers/pos_state.dart';
import 'package:windows_application/features/pos/models/cart_item.dart';
import 'package:windows_application/features/pos/models/payment_result.dart';
import 'package:windows_application/features/pos/models/pos_product.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';
import 'package:windows_application/features/pos/controllers/pos_print_state.dart';
import 'package:windows_application/features/printer/models/printer_config.dart';
import 'package:windows_application/features/printer/models/receipt_data.dart';
import 'package:windows_application/features/printer/repositories/device_printer_settings_store.dart';
import 'package:windows_application/features/printer/services/printer_service.dart';
import 'package:windows_application/features/printer/services/receipt_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PRINT pre-bill fetches the saved order and prints NOT PAID once',
    () async {
      final repository = _FakeRepository();
      final printer = _FakePrinter();
      final cubit = _cubit(repository, printer);
      addTearDown(cubit.close);

      final orderBefore = _orderState();
      final outcome = await cubit.printPreBill(
        orderState: orderBefore,
        locale: const Locale('en'),
      );

      expect(outcome.isSuccess, isTrue);
      expect(repository.receiptCalls, 1);
      expect(repository.jobs.single.type, 'pre_bill');
      expect(repository.jobStatuses, <String>['printing', 'completed']);
      expect(printer.calls, 1);
      expect(printer.lastIsPreBill, isTrue);
      expect(
        ReceiptRenderer.documentStatusLines(
          const Locale('en'),
          isPreBill: printer.lastIsPreBill,
        ),
        <String>['ORDER CHECK', 'NOT PAID'],
      );
      expect(repository.payCalls, 0);
      expect(orderBefore.currentOrderId, 42);
      expect(orderBefore.currentOrderPaymentStatus, 'unpaid');
    },
  );

  test(
    'pre-bill requires an order and items before making a print job',
    () async {
      final repository = _FakeRepository();
      final printer = _FakePrinter();
      final cubit = _cubit(repository, printer);
      addTearDown(cubit.close);

      final noOrder = await cubit.printPreBill(
        orderState: _orderState(orderId: null),
        locale: const Locale('en'),
      );
      final noItems = await cubit.printPreBill(
        orderState: _orderState(items: const <CartItem>[]),
        locale: const Locale('en'),
      );

      expect(noOrder.failure, PosPrintFailure.orderRequired);
      expect(noItems.failure, PosPrintFailure.itemsRequired);
      expect(repository.jobs, isEmpty);
      expect(repository.receiptCalls, 0);
      expect(printer.calls, 0);
    },
  );

  test('pre-bill refuses an order the backend reports as paid', () async {
    final repository = _FakeRepository(
      receipt: _receipt(
        payment: const ReceiptPayment(method: 'cash', amount: 5),
      ),
    );
    final printer = _FakePrinter();
    final cubit = _cubit(repository, printer);
    addTearDown(cubit.close);

    final outcome = await cubit.printPreBill(
      orderState: _orderState(),
      locale: const Locale('en'),
    );

    expect(outcome.failure, PosPrintFailure.preBillUnavailable);
    expect(repository.receiptCalls, 1);
    expect(repository.jobStatuses, <String>['failed']);
    expect(printer.calls, 0);
    expect(repository.payCalls, 0);
  });

  test(
    'paid receipt uses authoritative data and prints zero balance without Cash',
    () async {
      final repository = _FakeRepository(
        receipt: _receipt(total: 0, payment: null),
      );
      final printer = _FakePrinter();
      final cubit = _cubit(repository, printer);
      addTearDown(cubit.close);

      final outcome = await cubit.printReceipt(
        orderId: 42,
        branchId: 7,
        locale: const Locale('en'),
      );

      expect(outcome.isSuccess, isTrue);
      expect(repository.receiptCalls, 1);
      expect(printer.calls, 1);
      expect(printer.lastReceipt?.total, 0);
      expect(printer.lastReceipt?.payment, isNull);
      expect(printer.lastIsPreBill, isFalse);
      expect(repository.jobs.single.type, 'receipt');
    },
  );

  test(
    'print failure stays separate from payment and explicit retry reprints',
    () async {
      final repository = _FakeRepository();
      final printer = _FakePrinter(
        results: <PrinterPrintResult>[
          const PrinterPrintResult.failure(PrinterPrintFailure.unreachable),
          const PrinterPrintResult.success(),
        ],
      );
      final cubit = _cubit(repository, printer);
      addTearDown(cubit.close);

      final failed = await cubit.printReceipt(
        orderId: 42,
        branchId: 7,
        locale: const Locale('en'),
      );
      final retried = await cubit.printReceipt(
        orderId: 42,
        branchId: 7,
        locale: const Locale('en'),
      );

      expect(failed.failure, PosPrintFailure.printerUnreachable);
      expect(retried.isSuccess, isTrue);
      expect(printer.calls, 2);
      expect(repository.jobs, hasLength(2));
      expect(repository.jobStatuses, <String>[
        'printing',
        'failed',
        'printing',
        'completed',
      ]);
      expect(repository.payCalls, 0);
    },
  );

  test(
    'auto-print is setting controlled and runs once per paid order',
    () async {
      final repository = _FakeRepository();
      final printer = _FakePrinter();
      final cubit = _cubit(repository, printer, autoPrint: true);
      addTearDown(cubit.close);

      final first = await cubit.autoPrintReceipt(
        orderId: 42,
        branchId: 7,
        locale: const Locale('en'),
      );
      final replay = await cubit.autoPrintReceipt(
        orderId: 42,
        branchId: 7,
        locale: const Locale('en'),
      );

      expect(first.isSuccess, isTrue);
      expect(replay.isSkipped, isTrue);
      expect(printer.calls, 1);
      expect(repository.jobs, hasLength(1));
    },
  );

  test(
    'auto-print disabled does not print and failure exposes a manual retry',
    () async {
      final disabledRepo = _FakeRepository();
      final disabledPrinter = _FakePrinter();
      final disabledCubit = _cubit(disabledRepo, disabledPrinter);
      addTearDown(disabledCubit.close);
      final disabled = await disabledCubit.autoPrintReceipt(
        orderId: 42,
        branchId: 7,
        locale: const Locale('en'),
      );
      expect(disabled.isSkipped, isTrue);
      expect(disabledPrinter.calls, 0);
      expect(disabledRepo.receiptCalls, 0);

      final repository = _FakeRepository(receipt: _receipt(orderId: 43));
      final printer = _FakePrinter(
        results: <PrinterPrintResult>[
          const PrinterPrintResult.failure(PrinterPrintFailure.timeout),
          const PrinterPrintResult.success(),
        ],
      );
      final cubit = _cubit(repository, printer, autoPrint: true);
      addTearDown(cubit.close);
      final failed = await cubit.autoPrintReceipt(
        orderId: 43,
        branchId: 7,
        locale: const Locale('en'),
      );
      final retry = await cubit.printReceipt(
        orderId: 43,
        branchId: 7,
        locale: const Locale('en'),
      );

      expect(failed.failure, PosPrintFailure.printerTimeout);
      expect(retry.isSuccess, isTrue);
      expect(printer.calls, 2);
      expect(repository.payCalls, 0);
    },
  );

  test('receipt API and rendering failures are recorded safely', () async {
    final apiRepository = _FakeRepository()..receiptError = StateError('raw');
    final apiPrinter = _FakePrinter();
    final apiCubit = _cubit(apiRepository, apiPrinter);
    final apiFailure = await apiCubit.printReceipt(
      orderId: 42,
      branchId: 7,
      locale: const Locale('en'),
    );
    expect(apiFailure.failure, PosPrintFailure.receiptUnavailable);
    expect(apiPrinter.calls, 0);
    expect(apiRepository.jobs.single.status, 'failed');
    await apiCubit.close();

    final renderRepository = _FakeRepository();
    final renderPrinter = _FakePrinter()..throwRenderingFailure = true;
    final renderCubit = _cubit(renderRepository, renderPrinter);
    final renderFailure = await renderCubit.printReceipt(
      orderId: 42,
      branchId: 7,
      locale: const Locale('en'),
    );
    expect(renderFailure.failure, PosPrintFailure.renderingFailed);
    expect(renderRepository.jobStatuses, <String>['printing', 'failed']);
    expect(renderRepository.payCalls, 0);
    await renderCubit.close();
  });

  test(
    'missing configuration, unreachable printer, and timeout are safe failures',
    () async {
      final missingRepository = _FakeRepository();
      final missingPrinter = _FakePrinter();
      final missingCubit = _cubit(
        missingRepository,
        missingPrinter,
        config: const PrinterConfig(),
      );
      addTearDown(missingCubit.close);
      final missing = await missingCubit.printReceipt(
        orderId: 42,
        branchId: 7,
        locale: const Locale('en'),
      );
      expect(missing.failure, PosPrintFailure.printerNotConfigured);
      expect(missingPrinter.calls, 0);
      expect(missingRepository.jobs.single.status, 'failed');

      for (final entry in <(PrinterPrintFailure, PosPrintFailure)>[
        (PrinterPrintFailure.unreachable, PosPrintFailure.printerUnreachable),
        (PrinterPrintFailure.timeout, PosPrintFailure.printerTimeout),
      ]) {
        final repository = _FakeRepository();
        final printer = _FakePrinter(
          results: <PrinterPrintResult>[PrinterPrintResult.failure(entry.$1)],
        );
        final cubit = _cubit(repository, printer);
        final outcome = await cubit.printReceipt(
          orderId: 42,
          branchId: 7,
          locale: const Locale('en'),
        );
        expect(outcome.failure, entry.$2);
        expect(repository.jobStatuses.last, 'failed');
        await cubit.close();
      }
    },
  );

  test('double-click during an active print is ignored', () async {
    final repository = _FakeRepository();
    final printer = _FakePrinter()
      ..pendingResult = Completer<PrinterPrintResult>();
    final cubit = _cubit(repository, printer);
    addTearDown(cubit.close);

    final first = cubit.printReceipt(
      orderId: 42,
      branchId: 7,
      locale: const Locale('en'),
    );
    expect(cubit.state.isPrinting, isTrue);
    final second = await cubit.printReceipt(
      orderId: 42,
      branchId: 7,
      locale: const Locale('en'),
    );
    printer.pendingResult!.complete(const PrinterPrintResult.success());
    final firstResult = await first;

    expect(second.isSkipped, isTrue);
    expect(firstResult.isSuccess, isTrue);
    expect(printer.calls, 1);
  });
}

PosPrintCubit _cubit(
  _FakeRepository repository,
  _FakePrinter printer, {
  PrinterConfig config = const PrinterConfig(
    name: 'Front Counter',
    ipAddress: '192.168.1.50',
    enabled: true,
  ),
  bool autoPrint = false,
}) => PosPrintCubit(
  repository: repository,
  branchSettingsProvider: (_) async => PosPrintBranchSettings(
    printerConfig: config,
    autoPrintAfterPayment: autoPrint,
  ),
  deviceSettingsStore: _FakeSettingsStore(),
  printerService: printer,
  tenantId: 3,
);

PosState _orderState({int? orderId = 42, List<CartItem>? items}) => PosState(
  currentOrderId: orderId,
  currentOrderStatus: 'draft',
  currentOrderPaymentStatus: 'unpaid',
  branchId: 7,
  isBackendMode: true,
  cartItems: items ?? <CartItem>[_cartItem()],
);

CartItem _cartItem() => const CartItem(
  id: 'line-1',
  product: PosProduct(
    id: '11',
    backendId: 11,
    name: 'Coffee',
    category: 'Drinks',
    size: 'Regular',
    price: 5,
    isAvailable: true,
  ),
  quantity: 1,
  unitPrice: 5,
);

ReceiptData _receipt({
  int orderId = 42,
  double total = 5,
  ReceiptPayment? payment,
}) => ReceiptData(
  orderId: orderId,
  orderNumber: 'ORD-42',
  date: '2026-09-23T12:00:00Z',
  items: const <ReceiptItem>[
    ReceiptItem(name: 'Coffee', quantity: 1, unitPrice: 5, lineTotal: 5),
  ],
  subtotal: total,
  discountTotal: total == 0 ? 5 : 0,
  taxTotal: 0,
  total: total,
  payment: payment,
);

class _FakeRepository extends PosRepository {
  _FakeRepository({ReceiptData? receipt}) : receipt = receipt ?? _receipt();

  ReceiptData receipt;
  Object? receiptError;
  int receiptCalls = 0;
  int payCalls = 0;
  int _nextJobId = 1;
  final List<_FakePrintJob> jobs = <_FakePrintJob>[];
  final List<String> jobStatuses = <String>[];

  @override
  Future<ReceiptData> getPrintableReceipt(int orderId) async {
    receiptCalls++;
    if (receiptError != null) throw receiptError!;
    return receipt;
  }

  @override
  Future<int> createPrintJob({
    required int orderId,
    required String type,
    String? printerId,
    String? deviceName,
  }) async {
    final job = _FakePrintJob(id: _nextJobId++, type: type, status: 'queued');
    jobs.add(job);
    return job.id;
  }

  @override
  Future<void> updatePrintJob({
    required int printJobId,
    required String status,
    String? failureCode,
  }) async {
    jobs.singleWhere((job) => job.id == printJobId).status = status;
    jobStatuses.add(status);
  }

  @override
  Future<PaymentResult> payOrder({
    required int orderId,
    required String method,
    required double amount,
    required String idempotencyKey,
    String? reference,
    required double totalDue,
  }) async {
    payCalls++;
    throw StateError('Printing must not call payment.');
  }
}

class _FakePrintJob {
  _FakePrintJob({required this.id, required this.type, required this.status});
  final int id;
  final String type;
  String status;
}

class _FakeSettingsStore implements DevicePrinterSettingsStore {
  @override
  Future<DevicePrinterSettings> read({required int tenantId}) async =>
      const DevicePrinterSettings();

  @override
  Future<void> write({
    required int tenantId,
    required DevicePrinterSettings settings,
  }) async {}
}

class _FakePrinter implements PrinterService {
  _FakePrinter({this.results = const <PrinterPrintResult>[]});

  final List<PrinterPrintResult> results;
  int calls = 0;
  bool lastIsPreBill = false;
  ReceiptData? lastReceipt;
  Completer<PrinterPrintResult>? pendingResult;
  bool throwRenderingFailure = false;

  @override
  Future<PrinterPrintResult> printTest(PrinterConfig config) async =>
      const PrinterPrintResult.success();

  @override
  Future<PrinterPrintResult> printRaster(
    PrinterConfig config,
    ReceiptRaster raster,
  ) async => const PrinterPrintResult.success();

  @override
  Future<PrinterPrintResult> printReceipt(
    PrinterConfig config,
    ReceiptData receipt,
    Locale locale, {
    bool isPreBill = false,
  }) async {
    calls++;
    if (throwRenderingFailure) throw const ReceiptRenderException();
    lastIsPreBill = isPreBill;
    lastReceipt = receipt;
    if (pendingResult != null) return pendingResult!.future;
    if (calls <= results.length) return results[calls - 1];
    return const PrinterPrintResult.success();
  }
}
