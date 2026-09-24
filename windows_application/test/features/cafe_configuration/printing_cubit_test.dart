import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/features/cafe_configuration/controllers/cafe_configuration_cubits.dart';
import 'package:windows_application/features/cafe_configuration/controllers/printing_cubit.dart';
import 'package:windows_application/features/cafe_configuration/models/cafe_configuration_models.dart';
import 'package:windows_application/features/cafe_configuration/repositories/cafe_configuration_repository.dart';
import 'package:windows_application/features/cafe_configuration/widgets/cafe_configuration_navigation.dart';
import 'package:windows_application/features/cafe_configuration/views/cafe_configuration_screens.dart';
import 'package:windows_application/features/cafe_configuration/views/printing_screen.dart';
import 'package:windows_application/features/printer/models/printer_config.dart';

void main() {
  test('Printing route selects the top level tab', () {
    expect(
      CafeConfigurationDestination.forPath('/cafe-configuration/printing'),
      CafeConfigurationDestination.printing,
    );
  });

  test(
    'loads current branch, switches branches, and ignores old values',
    () async {
      final repo = _Repository();
      final cubit = PrintingCubit(repo);
      await cubit.load(preferredBranchId: 2);
      expect(cubit.state.selectedBranchId, 2);
      expect(cubit.state.config.paperWidth, PrinterPaperWidth.mm58);
      expect(cubit.state.autoPrintAfterPayment, isTrue);
      await cubit.selectBranch(1);
      expect(cubit.state.config.enabled, isFalse);
      expect(cubit.state.config.paperWidth, PrinterPaperWidth.mm80);
      expect(repo.loadedIds, [2, 1]);
      await cubit.selectBranch(99);
      expect(repo.loadedIds, [2, 1]);
      await cubit.close();
    },
  );

  test('saves printer changes with other branch fields intact', () async {
    final repo = _Repository();
    final cubit = PrintingCubit(repo);
    await cubit.load(preferredBranchId: 1);
    cubit.update(
      config: cubit.state.config.copyWith(
        enabled: true,
        ipAddress: 'printer.local',
        paperWidth: PrinterPaperWidth.mm58,
      ),
      autoPrintAfterPayment: true,
    );
    await cubit.save();
    expect(repo.updatedId, 1);
    expect(repo.updatedDraft!.name, 'Branch One');
    expect(repo.updatedDraft!.timezone, 'Asia/Damascus');
    expect(repo.updatedDraft!.printerConfig.paperWidth, PrinterPaperWidth.mm58);
    expect(repo.updatedDraft!.autoPrintAfterPayment, isTrue);
    expect(cubit.state.status, CafeConfigurationLoadStatus.success);
    await cubit.close();
  });

  test('disabled printing saves without a host', () async {
    final repo = _Repository();
    final cubit = PrintingCubit(repo);
    await cubit.load(preferredBranchId: 2);
    cubit.update(config: cubit.state.config.copyWith(enabled: false));
    await cubit.save();
    expect(repo.updatedDraft!.printerConfig.enabled, isFalse);
    await cubit.close();
  });

  test('rejects invalid enabled printer configuration', () async {
    final repo = _Repository();
    final cubit = PrintingCubit(repo);
    await cubit.load(preferredBranchId: 1);
    cubit.update(config: cubit.state.config.copyWith(enabled: true));
    await cubit.save();
    expect(cubit.state.error, 'validation');
    expect(repo.updatedDraft, isNull);
    await cubit.close();
  });

  testWidgets('Printing screen shows branch selector and saved defaults', (
    tester,
  ) async {
    final cubit = PrintingCubit(_Repository());
    await cubit.load(preferredBranchId: 2);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PrintingScreen()),
        ),
      ),
    );
    expect(find.byKey(const Key('printing-branch')), findsOneWidget);
    expect(find.text('Receipt Printing Enabled'), findsOneWidget);
    expect(find.text('58mm'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });

  testWidgets('Printing fields adapt to desktop and narrow RTL widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final cubit = PrintingCubit(_Repository());
    await cubit.load(preferredBranchId: 2);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PrintingScreen()),
        ),
      ),
    );
    expect(find.text('تفعيل طباعة الإيصالات'), findsOneWidget);
    final name = find.byKey(const ValueKey('printing-name-2-0'));
    final host = find.byKey(const ValueKey('printing-host-2-0'));
    expect(tester.getTopLeft(name).dy, tester.getTopLeft(host).dy);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(600, 900);
    await tester.pump();
    expect(tester.getTopLeft(host).dy, greaterThan(tester.getTopLeft(name).dy));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });

  testWidgets('Branch Edit has no Printing section', (tester) async {
    final cubit = BranchEditorCubit(_Repository(), branchId: 1);
    await cubit.initialize();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BranchEditorScreen(isEdit: true)),
        ),
      ),
    );
    expect(find.text('Printing'), findsNothing);
    expect(find.text('Receipt Printing Enabled'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });
}

class _Repository implements CafeConfigurationRepository {
  final loadedIds = <int>[];
  int? updatedId;
  BranchDraft? updatedDraft;

  final branches = <int, CafeConfigurationBranch>{
    1: const CafeConfigurationBranch(
      id: 1,
      name: 'Branch One',
      address: 'Main Street',
      phone: null,
      timezone: 'Asia/Damascus',
      currency: 'SYP',
      isActive: true,
    ),
    2: const CafeConfigurationBranch(
      id: 2,
      name: 'Branch Two',
      address: null,
      phone: null,
      timezone: 'Asia/Damascus',
      currency: 'SYP',
      isActive: true,
      printerConfig: PrinterConfig(
        enabled: true,
        ipAddress: '192.168.1.2',
        paperWidth: PrinterPaperWidth.mm58,
      ),
      autoPrintAfterPayment: true,
    ),
  };

  @override
  Future<List<CafeConfigurationBranch>> getBranches() async =>
      branches.values.toList();

  @override
  Future<CafeConfigurationBranch> getBranch(int id) async {
    loadedIds.add(id);
    return branches[id]!;
  }

  @override
  Future<CafeConfigurationBranch> updateBranch(
    int id,
    BranchDraft draft,
  ) async {
    updatedId = id;
    updatedDraft = draft;
    final old = branches[id]!;
    return CafeConfigurationBranch(
      id: id,
      name: draft.name,
      address: draft.address,
      phone: draft.phone,
      timezone: draft.timezone,
      currency: old.currency,
      isActive: old.isActive,
      printerConfig: draft.printerConfig,
      autoPrintAfterPayment: draft.autoPrintAfterPayment,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
