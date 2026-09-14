import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/navigation/unsaved_navigation_guard.dart';
import 'package:windows_application/features/customer_management/controllers/customer_form_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_form_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'dirty form navigation asks before discarding and keeps input on stay',
    (tester) async {
      final UnsavedNavigationController navigation =
          UnsavedNavigationController();
      final GoRouter router = GoRouter(
        initialLocation: '/customers/new',
        routes: <RouteBase>[
          GoRoute(
            path: '/customers/new',
            builder: (context, state) => BlocProvider<CustomerFormCubit>(
              create: (_) => CustomerFormCubit(_Repository()),
              child: const Scaffold(body: CustomerFormScreen()),
            ),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const Text('Customer list'),
          ),
        ],
      );
      await tester.pumpWidget(
        UnsavedNavigationScope(
          controller: navigation,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('customer-name-field')),
        'Ada',
      );
      await tester.tap(find.byKey(const Key('customer-form-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customer-name-field')), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);

      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pump();
      expect(find.byKey(const Key('customer-name-field')), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.byKey(const Key('customer-form-surface')), findsOneWidget);

      await tester.tap(find.byKey(const Key('customer-form-cancel')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customer-name-field')), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);

      await tester.tap(find.byKey(const Key('customer-form-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Customer list'), findsOneWidget);
    },
  );
}

class _Repository implements CustomerManagementRepository {
  @override
  Future<CustomerPage<CustomerGroup>> listGroups(
    CustomerGroupListQuery query,
  ) async => const CustomerPage<CustomerGroup>(
    items: <CustomerGroup>[],
    meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 100, total: 0),
  );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
