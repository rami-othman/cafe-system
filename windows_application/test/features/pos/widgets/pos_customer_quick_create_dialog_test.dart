import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/widgets/customer_create_dialog.dart';
import 'package:windows_application/features/pos/controllers/pos_customer_quick_create_cubit.dart';
import 'package:windows_application/features/pos/models/pos_customer_group.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';
import 'package:windows_application/features/pos/widgets/pos_customer_quick_create_dialog.dart';

void main() {
  testWidgets(
    'renders authoritative groups and validates required POS fields',
    (WidgetTester tester) async {
      final PosCustomerQuickCreateCubit cubit = PosCustomerQuickCreateCubit(
        repository: _GroupsRepository(),
        onCreate: (_) async => throw StateError('not reached'),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const CustomerCreateDialog(
                mode: CustomerCreateMode.posQuickCreate,
                maxWidth: 480,
                maxHeight: 560,
                fitContent: true,
                child: PosCustomerQuickCreateDialog(compact: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('pos-customer-group-4')), findsOneWidget);
      expect(find.byKey(const Key('pos-customer-group-9')), findsOneWidget);
      expect(
        tester
            .getSize(
              find.byKey(
                const ValueKey<String>(
                  'customer-create-dialog-content-posQuickCreate',
                ),
              ),
            )
            .height,
        lessThan(560),
      );

      await tester.tap(find.byKey(const Key('pos-customer-save')));
      await tester.pump();

      expect(find.byKey(const Key('pos-customer-name')), findsOneWidget);
      expect(find.byKey(const Key('pos-customer-phone')), findsOneWidget);
      expect(find.text('Enter a customer name.'), findsOneWidget);
      expect(find.text('Enter a phone number.'), findsOneWidget);
    },
  );
}

class _GroupsRepository extends PosRepository {
  @override
  Future<List<PosCustomerGroup>> getCustomerGroups({int perPage = 100}) async =>
      const <PosCustomerGroup>[
        PosCustomerGroup(id: 4, name: 'VIP'),
        PosCustomerGroup(id: 9, name: 'Regular'),
      ];
}
