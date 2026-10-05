import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_form_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_form_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'does not invent a shared-phone warning without an authorized match contract',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<CustomerFormCubit>(
            create: (_) => CustomerFormCubit(_Repository()),
            child: const Scaffold(body: CustomerFormScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('customer-name-field')),
        'Ada',
      );
      await tester.ensureVisible(find.byKey(const Key('customer-add-phone')));
      await tester.tap(find.byKey(const Key('customer-add-phone')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('customer-phone-0-raw')));
      await tester.enterText(
        find.byKey(const Key('customer-phone-0-raw')),
        '+963 999 1',
      );
      await tester.pump();

      expect(find.textContaining('Shared phone'), findsNothing);
      expect(find.textContaining('shared phone'), findsNothing);
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
