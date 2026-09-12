import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_form_cubit.dart';
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
      find.byKey(const Key('customer-group-form-surface')),
      findsOneWidget,
    );
    expect(find.text('Group name'), findsOneWidget);
    expect(find.text('Description'), findsNothing);
    expect(find.text('Status'), findsNothing);
  });
}

class _Repository implements CustomerManagementRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
