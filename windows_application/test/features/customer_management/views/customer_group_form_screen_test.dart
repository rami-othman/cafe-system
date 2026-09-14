import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_form_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_drafts.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_group_form_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('group form exposes only name and save actions', (tester) async {
    final _Repository repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => CustomerGroupFormCubit(repository)..initializeCreate(),
          child: const Scaffold(body: CustomerGroupFormScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('customer-group-name')), findsOneWidget);
    expect(
      find.byKey(const Key('customer-group-create-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('Group name'), findsOneWidget);
    expect(find.text('Description'), findsNothing);
    expect(find.text('Status'), findsNothing);
  });

  testWidgets('create form is presented as a modal dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) =>
              CustomerGroupFormCubit(_Repository())..initializeCreate(),
          child: const Scaffold(body: CustomerGroupFormScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.byKey(const Key('customer-group-form-breadcrumbs')),
      findsNothing,
    );
  });

  testWidgets('create dialog contains only the name form composition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) =>
              CustomerGroupFormCubit(_Repository())..initializeCreate(),
          child: const Scaffold(body: CustomerGroupFormScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('New Group'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-group-form-breadcrumbs')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('customer-group-form-section-heading')),
      findsNothing,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('customer-group-create-content')))
          .width,
      lessThanOrEqualTo(480),
    );
    expect(find.text('Description'), findsNothing);
    expect(find.text('Status'), findsNothing);
    expect(find.byKey(const Key('customer-group-form-cancel')), findsOneWidget);
  });

  testWidgets('create form remains usable in Arabic at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: BlocProvider(
            create: (_) =>
                CustomerGroupFormCubit(_Repository())..initializeCreate(),
            child: const Scaffold(body: CustomerGroupFormScreen()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('مجموعة جديدة'), findsOneWidget);
    expect(find.byKey(const Key('customer-group-name')), findsOneWidget);
    expect(find.byKey(const Key('customer-group-save')), findsOneWidget);
    expect(find.byKey(const Key('customer-group-form-cancel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create dialog remains overflow-free across reference sizes', (
    tester,
  ) async {
    const List<Size> sizes = <Size>[
      Size(1440, 900),
      Size(1440, 900),
      Size(1280, 800),
      Size(1280, 800),
      Size(500, 800),
      Size(500, 800),
    ];
    const List<Locale> locales = <Locale>[
      Locale('en'),
      Locale('ar'),
      Locale('en'),
      Locale('ar'),
      Locale('en'),
      Locale('ar'),
    ];
    const List<TextDirection> directions = <TextDirection>[
      TextDirection.ltr,
      TextDirection.rtl,
      TextDirection.ltr,
      TextDirection.rtl,
      TextDirection.ltr,
      TextDirection.rtl,
    ];

    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (int index = 0; index < sizes.length; index++) {
      tester.view.physicalSize = sizes[index];
      await tester.pumpWidget(
        MaterialApp(
          locale: locales[index],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Directionality(
            textDirection: directions[index],
            child: BlocProvider(
              create: (_) =>
                  CustomerGroupFormCubit(_Repository())..initializeCreate(),
              child: const Scaffold(body: CustomerGroupFormScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('customer-group-create-dialog')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('customer-group-save')), findsOneWidget);
      expect(
        find.byKey(const Key('customer-group-form-cancel')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('create failure keeps the name and announces the failure', (
    tester,
  ) async {
    final _FailingCreateRepository repository = _FailingCreateRepository();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => CustomerGroupFormCubit(repository)..initializeCreate(),
          child: const Scaffold(body: CustomerGroupFormScreen()),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('customer-group-name')),
      'Morning regulars',
    );
    await tester.tap(find.byKey(const Key('customer-group-save')));
    await tester.pumpAndSettle();

    expect(
      repository.submittedDraft,
      const GroupDraft(name: 'Morning regulars'),
    );
    expect(find.text('Morning regulars'), findsOneWidget);
    expect(find.byKey(const Key('customer-group-error')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
  });
}

class _Repository implements CustomerManagementRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingCreateRepository implements CustomerManagementRepository {
  GroupDraft? submittedDraft;

  @override
  Future<CustomerGroup> createGroup(GroupDraft draft) async {
    submittedDraft = draft;
    throw StateError('network unavailable');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
