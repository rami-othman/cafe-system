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
import 'package:windows_application/features/printer/models/receipt_template.dart';
import 'package:windows_application/features/cafe_configuration/widgets/receipt_template_preview.dart';

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
    await cubit.savePrinterConfig();
    expect(repo.updatedId, 1);
    expect(repo.updatedDraft!.name, 'Branch One');
    expect(repo.updatedDraft!.timezone, 'Asia/Damascus');
    expect(repo.updatedDraft!.printerConfig.paperWidth, PrinterPaperWidth.mm58);
    expect(repo.updatedDraft!.autoPrintAfterPayment, isTrue);
    expect(cubit.state.printerSaveStatus, SectionSaveStatus.success);
    await cubit.close();
  });

  test('disabled printing saves without a host', () async {
    final repo = _Repository();
    final cubit = PrintingCubit(repo);
    await cubit.load(preferredBranchId: 2);
    cubit.update(config: cubit.state.config.copyWith(enabled: false));
    await cubit.savePrinterConfig();
    expect(repo.updatedDraft!.printerConfig.enabled, isFalse);
    await cubit.close();
  });

  test('rejects invalid enabled printer configuration', () async {
    final repo = _Repository();
    final cubit = PrintingCubit(repo);
    await cubit.load(preferredBranchId: 1);
    cubit.update(config: cubit.state.config.copyWith(enabled: true));
    await cubit.savePrinterConfig();
    expect(cubit.state.printerSaveError, 'validation');
    expect(repo.updatedDraft, isNull);
    await cubit.close();
  });

  test(
    'saving the printer configuration never touches the receipt template',
    () async {
      final repo = _Repository();
      final cubit = PrintingCubit(repo);
      await cubit.load(preferredBranchId: 1);
      cubit.update(
        config: cubit.state.config.copyWith(
          enabled: true,
          ipAddress: 'printer.local',
        ),
        template: cubit.state.template.copyWith(
          header: cubit.state.template.header.copyWith(showLogo: false),
        ),
      );
      await cubit.savePrinterConfig();

      expect(cubit.state.printerSaveStatus, SectionSaveStatus.success);
      // The template edit is still only local/dirty — saving the printer
      // section alone must not have called the template endpoint.
      expect(repo.updatedTemplateBranchId, isNull);
      expect(cubit.state.templateSaveStatus, SectionSaveStatus.idle);
      expect(cubit.state.isTemplateDirty, isTrue);
      await cubit.close();
    },
  );

  test(
    'a failed printer-config save leaves the receipt template save state untouched',
    () async {
      final repo = _Repository()..failBranchUpdate = true;
      final cubit = PrintingCubit(repo);
      await cubit.load(preferredBranchId: 1);
      cubit.update(
        config: cubit.state.config.copyWith(
          enabled: true,
          ipAddress: 'printer.local',
        ),
        template: cubit.state.template.copyWith(
          header: cubit.state.template.header.copyWith(showLogo: false),
        ),
      );
      await cubit.savePrinterConfig();
      expect(cubit.state.printerSaveStatus, SectionSaveStatus.failure);
      expect(cubit.state.printerSaveError, 'save');
      expect(cubit.state.templateSaveStatus, SectionSaveStatus.idle);

      await cubit.saveReceiptTemplate();
      expect(cubit.state.templateSaveStatus, SectionSaveStatus.success);
      expect(repo.updatedTemplateBranchId, 1);
      // The printer section's failure is unaffected by the template save.
      expect(cubit.state.printerSaveStatus, SectionSaveStatus.failure);
      await cubit.close();
    },
  );

  test(
    'a failed receipt-design save leaves the printer-config save state untouched',
    () async {
      final repo = _Repository()..failTemplateUpdate = true;
      final cubit = PrintingCubit(repo);
      await cubit.load(preferredBranchId: 1);
      cubit.update(
        config: cubit.state.config.copyWith(
          enabled: true,
          ipAddress: 'printer.local',
        ),
        template: cubit.state.template.copyWith(
          header: cubit.state.template.header.copyWith(showLogo: false),
        ),
      );
      await cubit.saveReceiptTemplate();
      expect(cubit.state.templateSaveStatus, SectionSaveStatus.failure);
      expect(cubit.state.templateSaveError, 'save');
      expect(cubit.state.printerSaveStatus, SectionSaveStatus.idle);

      await cubit.savePrinterConfig();
      expect(cubit.state.printerSaveStatus, SectionSaveStatus.success);
      expect(repo.updatedId, 1);
      // The template section's failure is unaffected by the printer save.
      expect(cubit.state.templateSaveStatus, SectionSaveStatus.failure);
      await cubit.close();
    },
  );

  test('loads the branch receipt template alongside printer config', () async {
    final repo = _Repository();
    repo.templates[1] = const ReceiptTemplate(
      footer: ReceiptTemplateFooter(enabled: true, text: 'Branch one footer'),
    );
    final cubit = PrintingCubit(repo);
    await cubit.load(preferredBranchId: 1);
    expect(cubit.state.template.footer.text, 'Branch one footer');
    expect(cubit.state.savedTemplate, cubit.state.template);
    await cubit.close();
  });

  test(
    'template edits mark the form dirty and save independently of the branch',
    () async {
      final repo = _Repository();
      final cubit = PrintingCubit(repo);
      await cubit.load(preferredBranchId: 1);
      expect(cubit.state.isDirty, isFalse);

      cubit.update(
        template: cubit.state.template.copyWith(
          header: cubit.state.template.header.copyWith(showLogo: false),
        ),
      );
      expect(cubit.state.isDirty, isTrue);
      expect(cubit.state.isTemplateDirty, isTrue);
      expect(cubit.state.isPrinterConfigDirty, isFalse);

      await cubit.saveReceiptTemplate();
      expect(repo.updatedTemplateBranchId, 1);
      expect(repo.updatedTemplate!.header.showLogo, isFalse);
      expect(cubit.state.templateSaveStatus, SectionSaveStatus.success);
      expect(cubit.state.isDirty, isFalse);
      // Saving the template alone never calls the branch endpoint.
      expect(repo.updatedId, isNull);
      await cubit.close();
    },
  );

  test('reset restores the saved template', () async {
    final repo = _Repository();
    final cubit = PrintingCubit(repo);
    await cubit.load(preferredBranchId: 1);
    final saved = cubit.state.template;
    cubit.update(
      template: saved.copyWith(footer: saved.footer.copyWith(enabled: false)),
    );
    expect(cubit.state.isDirty, isTrue);
    cubit.reset();
    expect(cubit.state.template, saved);
    expect(cubit.state.isDirty, isFalse);
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

  testWidgets(
    'Receipt Design section toggles a field and marks the form dirty',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 2200);
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: PrintingScreen()),
          ),
        ),
      );

      expect(find.text('Receipt Design'), findsOneWidget);
      expect(cubit.state.template.header.showLogo, isTrue);
      final logoToggle = find.byKey(const Key('receipt-header-logo'));
      await tester.ensureVisible(logoToggle);
      await tester.pumpAndSettle();
      await tester.tap(logoToggle);
      await tester.pump();
      expect(cubit.state.template.header.showLogo, isFalse);
      expect(cubit.state.isDirty, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
    },
  );

  testWidgets('Receipt Design move buttons reorder sections', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 2200);
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PrintingScreen()),
        ),
      ),
    );

    expect(
      cubit.state.template.sectionOrder.first,
      ReceiptTemplateSection.header,
    );
    // Move-down icon buttons appear in section order: header's is first.
    final moveDown = find.byIcon(Icons.arrow_downward).first;
    await tester.ensureVisible(moveDown);
    await tester.pumpAndSettle();
    await tester.tap(moveDown);
    await tester.pump();
    expect(
      cubit.state.template.sectionOrder.first,
      ReceiptTemplateSection.orderInfo,
    );
    expect(cubit.state.template.sectionOrder[1], ReceiptTemplateSection.header);

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });

  testWidgets('Preview Receipt opens a dialog rendering the current template', (
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

    final Finder previewButton = find.byKey(
      const Key('printing-receipt-preview'),
    );
    await tester.ensureVisible(previewButton);
    await tester.pumpAndSettle();
    await tester.tap(previewButton);
    await tester.pump();
    expect(find.byType(ReceiptTemplatePreview), findsOneWidget);
    // Rendering does real font/image work over a platform channel; give the
    // real event loop turns to finish it instead of pumping the fake clock,
    // and avoid pumpAndSettle since the spinner's animation never settles.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

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
  int? updatedTemplateBranchId;
  ReceiptTemplate? updatedTemplate;
  final templates = <int, ReceiptTemplate>{};
  bool failBranchUpdate = false;
  bool failTemplateUpdate = false;

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
    if (failBranchUpdate) throw StateError('network error');
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
  Future<ReceiptTemplate> getReceiptTemplate(int branchId) async =>
      templates[branchId] ?? const ReceiptTemplate.defaultTemplate();

  @override
  Future<ReceiptTemplate> updateReceiptTemplate(
    int branchId,
    ReceiptTemplate template,
  ) async {
    if (failTemplateUpdate) throw StateError('network error');
    updatedTemplateBranchId = branchId;
    updatedTemplate = template;
    templates[branchId] = template;
    return template;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
