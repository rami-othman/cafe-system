import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/features/auth/views/settings_screen.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/controllers/pos_state.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';
import 'package:windows_application/features/operational_context/controllers/operational_branch_cubit.dart';
import 'package:windows_application/features/operational_context/models/operational_branch_state.dart';
import 'package:windows_application/features/operational_context/repositories/operational_branch_repository.dart';
import 'package:windows_application/features/printer/controllers/printer_setup_cubit.dart';
import 'package:windows_application/features/printer/models/printer_config.dart';
import 'package:windows_application/features/printer/repositories/device_printer_settings_store.dart';
import 'package:windows_application/features/printer/services/printer_service.dart';
import 'package:windows_application/features/printer/services/receipt_renderer.dart';
import 'package:windows_application/features/printer/models/receipt_data.dart';
import 'package:windows_application/features/printer/views/printer_setup_card.dart';
import 'package:windows_application/l10n/app_localizations.dart';

const Branch _downtown = Branch(
  id: 1,
  name: 'Downtown',
  currency: 'SYP',
  timezone: 'Asia/Damascus',
  isActive: true,
);
const Branch _uptown = Branch(
  id: 2,
  name: 'Uptown',
  currency: 'SYP',
  timezone: 'Asia/Damascus',
  isActive: true,
);

void main() {
  late _BranchCubit branchCubit;
  late _OperationalCubit operationalCubit;
  late List<int> requestedBranches;
  late bool failConfig;

  setUp(() async {
    await serviceLocator.reset();
    branchCubit = _BranchCubit();
    operationalCubit = _OperationalCubit();
    requestedBranches = <int>[];
    failConfig = false;
    serviceLocator.registerFactory<PrinterSetupCubit>(
      () => PrinterSetupCubit(
        tenantId: 1,
        branchDefaultsProvider: (int branchId) async {
          requestedBranches.add(branchId);
          if (failConfig) throw StateError('API failure');
          return PrinterConfig(name: 'Printer $branchId');
        },
        settingsStore: _MemoryStore(),
        printerService: _FakePrinter(),
      ),
    );
  });

  tearDown(() async {
    await branchCubit.close();
    await operationalCubit.close();
    await serviceLocator.reset();
  });

  testWidgets(
    'Settings printer card loads the selected branch without opening POS',
    (WidgetTester tester) async {
      branchCubit.show(const PosState(branches: <Branch>[_downtown]));
      await _pumpCard(tester, branchCubit, operationalCubit);

      expect(requestedBranches, <int>[1]);
      expect(_printerName(tester), 'Printer 1');
      expect(find.text('Use Branch Defaults'), findsOneWidget);
    },
  );

  testWidgets(
    'local override fields enable after branch defaults are turned off',
    (WidgetTester tester) async {
      branchCubit.show(const PosState(branches: <Branch>[_downtown]));
      await _pumpCard(tester, branchCubit, operationalCubit);

      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('printer-name')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('printer-ip')))
            .enabled,
        isFalse,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('printer-name')))
            .enabled,
        isTrue,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('printer-ip')))
            .enabled,
        isTrue,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('printer-port')))
            .enabled,
        isTrue,
      );
    },
  );

  testWidgets('Settings scrolls the full printer card at desktop height', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1651, 937);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    branchCubit.show(const PosState(branches: <Branch>[_downtown]));
    operationalCubit.show(
      const OperationalBranchState(
        branches: <Branch>[_downtown],
        selectedBranchId: 1,
      ),
    );
    final AuthSessionCubit auth = AuthSessionCubit(
      repository: OfflineAuthRepository(),
      storage: MemoryAuthSessionStorage(),
      apiClient: DioApiClient(),
    );
    addTearDown(auth.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<PosCubit>.value(value: branchCubit),
          BlocProvider<OperationalBranchCubit>.value(value: operationalCubit),
          BlocProvider<AuthSessionCubit>.value(value: auth),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SizedBox(height: 865, child: SettingsScreen())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    final Finder scroll = find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Save Device Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching the top-level branch reloads printer defaults', (
    WidgetTester tester,
  ) async {
    branchCubit.show(const PosState(branches: <Branch>[_downtown, _uptown]));
    await _pumpCard(tester, branchCubit, operationalCubit);
    branchCubit.show(
      const PosState(branches: <Branch>[_downtown, _uptown], branchId: 2),
    );
    await tester.pumpAndSettle();

    expect(requestedBranches, <int>[1, 2]);
    expect(_printerName(tester), 'Printer 2');
  });

  testWidgets('branch loading and no selection have distinct states', (
    WidgetTester tester,
  ) async {
    branchCubit.show(const PosState(isLoading: true));
    operationalCubit.show(const OperationalBranchState(isLoading: true));
    await _pumpCard(tester, branchCubit, operationalCubit, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    operationalCubit.show(const OperationalBranchState());
    await tester.pumpAndSettle();
    expect(find.text('No active branch selected'), findsOneWidget);
    expect(requestedBranches, isEmpty);
  });

  testWidgets('Retry re-resolves branches after a branch lookup failure', (
    WidgetTester tester,
  ) async {
    operationalCubit.reader.fail = true;
    await _pumpCard(tester, branchCubit, operationalCubit);
    expect(find.text('Could not load the active branch.'), findsOneWidget);

    operationalCubit.reader.fail = false;
    operationalCubit.reader.branches = const <Branch>[_downtown];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requestedBranches, <int>[1]);
    expect(_printerName(tester), 'Printer 1');
  });

  testWidgets(
    'configuration API failure shows Retry and reloads active branch',
    (WidgetTester tester) async {
      failConfig = true;
      branchCubit.show(const PosState(branches: <Branch>[_downtown]));
      await _pumpCard(tester, branchCubit, operationalCubit);
      expect(find.text('Printer setup could not be loaded.'), findsOneWidget);

      failConfig = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(requestedBranches, <int>[1, 1]);
      expect(_printerName(tester), 'Printer 1');
    },
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  PosCubit branchCubit,
  _OperationalCubit operationalCubit, {
  bool settle = true,
}) async {
  if (!operationalCubit.state.isLoading &&
      branchCubit.state.branches.isNotEmpty) {
    operationalCubit.show(
      OperationalBranchState(
        branches: branchCubit.state.branches,
        selectedBranchId: branchCubit.state.branchId,
      ),
    );
  }
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<PosCubit>.value(value: branchCubit),
        BlocProvider<OperationalBranchCubit>.value(value: operationalCubit),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: PrinterSetupCard())),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

String? _printerName(WidgetTester tester) => tester
    .widget<TextFormField>(find.byKey(const Key('printer-name')))
    .initialValue;

class _BranchCubit extends PosCubit {
  _BranchCubit() : super(repository: PosRepository());

  void show(PosState value) => emit(value);
}

class _OperationalCubit extends OperationalBranchCubit {
  _OperationalCubit() : this.withReader(_BranchReader());
  _OperationalCubit.withReader(this.reader) : super(repository: reader);
  final _BranchReader reader;
  void show(OperationalBranchState value) => emit(value);
}

class _BranchReader implements OperationalBranchReader {
  bool fail = false;
  List<Branch> branches = const <Branch>[];
  @override
  Future<List<Branch>> getActiveBranches() async {
    if (fail) throw StateError('offline');
    return branches;
  }
}

class _MemoryStore implements DevicePrinterSettingsStore {
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
  }) async => const PrinterPrintResult.success();
}
