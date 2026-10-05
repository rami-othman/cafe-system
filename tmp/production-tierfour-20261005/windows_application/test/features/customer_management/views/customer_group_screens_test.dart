import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_list_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_detail_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_group_detail_screen.dart';
import 'package:windows_application/features/customer_management/views/customer_group_list_screen.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_scaffold.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('customer management keeps stable customer and group tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: CustomerManagementScaffold(
            groupsSelected: true,
            child: Text('groups'),
          ),
        ),
      ),
    );
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Customer Groups'), findsOneWidget);
  });

  testWidgets('group list presents authoritative count metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerGroupListCubit>(
          create: (_) => CustomerGroupListCubit(_Repository()),
          child: Scaffold(
            body: CustomerGroupListScreen(repository: _Repository()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 group'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('VIP description'), findsNothing);
  });

  testWidgets('desktop group filters stay at logical start in LTR and RTL', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final ({Locale locale, TextDirection direction, bool isRtl}) scenario
        in <({Locale locale, TextDirection direction, bool isRtl})>[
          (
            locale: const Locale('en'),
            direction: TextDirection.ltr,
            isRtl: false,
          ),
          (
            locale: const Locale('ar'),
            direction: TextDirection.rtl,
            isRtl: true,
          ),
        ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: scenario.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Directionality(
            textDirection: scenario.direction,
            child: BlocProvider<CustomerGroupListCubit>(
              create: (_) => CustomerGroupListCubit(_Repository()),
              child: Scaffold(
                body: CustomerGroupListScreen(repository: _Repository()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Rect search = tester.getRect(find.byType(TextField));
      final Rect status = tester.getRect(
        find.byKey(const Key('customer-group-lifecycle-filter')),
      );
      if (scenario.isRtl) {
        expect(search.left, greaterThan(720));
        expect(status.left, greaterThan(720));
        expect(search.left, greaterThan(status.left));
      } else {
        expect(search.left, lessThan(720));
        expect(status.left, lessThan(720));
        expect(search.left, lessThan(status.left));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('group detail presents identity, date, members, and actions', (
    tester,
  ) async {
    final _Repository repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerGroupDetailCubit>(
          create: (_) => CustomerGroupDetailCubit(repository),
          child: Scaffold(
            body: SizedBox(
              width: 500,
              height: 800,
              child: CustomerGroupDetailScreen(
                groupId: 1,
                repository: repository,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('customer-group-identity-surface')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('customer-group-created-at')), findsNothing);
    expect(
      find.byKey(const Key('customer-group-members-surface')),
      findsOneWidget,
    );
    expect(find.text('12 members'), findsOneWidget);
    expect(find.text('â€¢'), findsNothing);
    expect(find.byKey(const Key('customer-group-add-members')), findsOneWidget);
    expect(find.text('VIP description'), findsNothing);
    expect(
      find.text('Review the group identity, lifecycle, and current members.'),
      findsNothing,
    );
    expect(find.byType(DropdownButton), findsNothing);
    expect(
      find.byKey(const Key('customer-group-detail-lifecycle')),
      findsOneWidget,
    );
    expect(repository.groupRequests, 1);
    expect(repository.memberRequests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('group detail actions retain 48 pixel interactive targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      _detailHost(
        _Repository(),
        locale: const Locale('en'),
        direction: TextDirection.ltr,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(find.byKey(const Key('customer-group-detail-edit')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('customer-group-add-members')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('customer-group-detail-lifecycle')))
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('mounted Group Detail uses its 760 content breakpoint', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final ({double viewportWidth, bool expectsTable}) scenario
        in <({double viewportWidth, bool expectsTable})>[
          (viewportWidth: 824, expectsTable: true),
          (viewportWidth: 823, expectsTable: false),
        ]) {
      tester.view.physicalSize = Size(scenario.viewportWidth, 800);
      await tester.pumpWidget(
        _scaffoldedDetailHost(_Repository(withMember: true)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(DataTable),
        scenario.expectsTable ? findsOneWidget : findsNothing,
        reason:
            'member collection content width is ${scenario.viewportWidth - 64}',
      );
      expect(
        find.byKey(const Key('customer-group-member-card-2')),
        scenario.expectsTable ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('group detail shows creation date only when returned', (
    tester,
  ) async {
    final _Repository repository = _Repository(
      createdAt: DateTime.utc(2026, 9, 8),
    );
    await tester.pumpWidget(
      _detailHost(
        repository,
        locale: const Locale('en'),
        direction: TextDirection.ltr,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-group-created-at')), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic Group Detail keeps its creation date as one LTR value', (
    tester,
  ) async {
    await tester.pumpWidget(
      _detailHost(
        _Repository(createdAt: DateTime.utc(2026, 9, 8)),
        locale: const Locale('ar'),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    final Text date = tester.widget<Text>(
      find.byKey(const Key('customer-group-created-at-value')),
    );
    expect(date.textDirection, TextDirection.ltr);
    expect(date.data, startsWith('\u2066'));
    expect(date.data, endsWith('\u2069'));
  });

  testWidgets('group detail stays overflow-free across required viewports', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    final List<Size> sizes = <Size>[
      const Size(1440, 900),
      const Size(1280, 800),
      const Size(500, 800),
      const Size(760, 800),
      const Size(759, 800),
    ];
    for (final Locale locale in <Locale>[
      const Locale('en'),
      const Locale('ar'),
    ]) {
      for (final Size size in sizes) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _detailHost(
            _Repository(withMember: true),
            locale: locale,
            direction: locale.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('customer-group-members-surface')),
          findsOneWidget,
          reason: 'locale=$locale size=$size',
        );
        if (locale.languageCode == 'en') {
          expect(find.text('Members: 17'), findsOneWidget);
        }
        expect(
          tester.takeException(),
          isNull,
          reason: 'locale=$locale size=$size',
        );
      }
    }
  });
}

Widget _detailHost(
  _Repository repository, {
  required Locale locale,
  required TextDirection direction,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Directionality(
    textDirection: direction,
    child: BlocProvider<CustomerGroupDetailCubit>(
      create: (_) => CustomerGroupDetailCubit(repository),
      child: Scaffold(
        body: CustomerGroupDetailScreen(groupId: 1, repository: repository),
      ),
    ),
  ),
);

Widget _scaffoldedDetailHost(_Repository repository) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<CustomerGroupDetailCubit>(
    create: (_) => CustomerGroupDetailCubit(repository),
    child: Scaffold(
      body: CustomerManagementScaffold(
        groupsSelected: true,
        child: CustomerGroupDetailScreen(groupId: 1, repository: repository),
      ),
    ),
  ),
);

class _Repository implements CustomerManagementRepository {
  _Repository({this.withMember = false, this.createdAt});

  final bool withMember;
  final DateTime? createdAt;
  int groupRequests = 0;
  int memberRequests = 0;

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(_) async =>
      const CustomerPage<CustomerGroup>(
        items: <CustomerGroup>[
          CustomerGroup(
            id: 1,
            name: 'VIP',
            lifecycle: CustomerLifecycle.active,
            memberCount: 12,
          ),
        ],
        meta: CustomerPageMeta(
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 1,
        ),
      );

  @override
  Future<CustomerGroup> getGroup(int groupId) async {
    groupRequests++;
    return CustomerGroup(
      id: 1,
      name: 'VIP',
      lifecycle: CustomerLifecycle.active,
      memberCount: 12,
      createdAt: createdAt,
    );
  }

  @override
  Future<CustomerPage<Customer>> listGroupMembers(int groupId, query) async {
    memberRequests++;
    return CustomerPage<Customer>(
      items: withMember ? <Customer>[_member] : const <Customer>[],
      meta: CustomerPageMeta(
        currentPage: 1,
        lastPage: 1,
        perPage: 25,
        total: withMember ? 17 : 0,
      ),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const Customer _member = Customer(
  id: 2,
  customerNumber: 'C-000002',
  name: 'Member',
  lifecycle: CustomerLifecycle.active,
  phones: <CustomerPhone>[],
  groups: <CustomerGroupSummary>[],
  allowedActions: <String>{},
);
