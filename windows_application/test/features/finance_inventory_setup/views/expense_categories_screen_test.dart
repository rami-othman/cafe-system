import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/expense_categories_screen.dart';

void main() {
  testWidgets('loads real expense categories and renders their linked account', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter());

    expect(find.text('RENT'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('6100'), findsOneWidget);
    expect(find.text('نشط'), findsOneWidget);
  });

  testWidgets('shows the empty state when no categories are configured', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter(categories: const <Map<String, dynamic>>[]));

    expect(find.text('لا توجد فئات مصروفات مهيأة.'), findsOneWidget);
  });

  testWidgets('blocks saving a category with an empty code or name', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter());

    await tester.tap(find.text('إضافة فئة'));
    await tester.pumpAndSettle();

    final Finder codeField = find.widgetWithText(TextField, 'الرمز');
    await tester.enterText(codeField, '');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('أدخل رمزاً واسماً صالحين.'), findsOneWidget);
  });

  testWidgets('toggling status asks for confirmation before calling the API', (
    WidgetTester tester,
  ) async {
    final _FakeRouter router = _FakeRouter();
    await _pumpScreen(tester, router: router);

    await tester.tap(find.byIcon(Icons.toggle_on_outlined));
    await tester.pumpAndSettle();
    expect(find.text('تعطيل الفئة'), findsOneWidget);
    expect(router.statusChanges, isEmpty);

    await tester.tap(find.text('تعطيل'));
    await tester.pumpAndSettle();
    expect(router.statusChanges, <int>[1]);
  });
}

Future<void> _pumpScreen(WidgetTester tester, {required _FakeRouter router}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        try {
          handler.resolve(router.respond(options));
        } on DioException catch (error) {
          handler.reject(error);
        }
      },
    ),
  );
  final FinanceSetupRepository repository = FinanceSetupRepository(
    DioApiClient(dio: dio),
  );
  final FinanceSetupCubit cubit = FinanceSetupCubit(repository: repository);

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: BlocProvider<FinanceSetupCubit>.value(
            value: cubit,
            child: const ExpenseCategoriesScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeRouter {
  _FakeRouter({List<Map<String, dynamic>>? categories})
    : _categories = categories ?? <Map<String, dynamic>>[_rentCategory()];

  final List<Map<String, dynamic>> _categories;
  final List<int> statusChanges = <int>[];

  static Map<String, dynamic> _rentCategory() => <String, dynamic>{
    'id': 1,
    'code': 'RENT',
    'name': 'Rent',
    'financialAccountId': 12,
    'financialAccountCode': '6100',
    'financialAccountName': 'Rent Expense',
    'isActive': true,
    'sortOrder': 0,
  };

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;

    if (path == 'finance/expense-categories' && options.method == 'GET') {
      return _ok(options, _categories);
    }
    if (path.startsWith('finance/expense-categories/') && path.endsWith('/status')) {
      final int id = int.parse(path.split('/')[2]);
      statusChanges.add(id);
      final Map<String, dynamic> category = _categories.firstWhere((c) => c['id'] == id);
      category['isActive'] = !(category['isActive'] as bool);
      return _ok(options, category);
    }
    if (path == 'finance/accounts') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 12,
          'code': '6100',
          'nameAr': 'مصروف إيجار',
          'nameEn': 'Rent Expense',
          'accountGroup': 'expenses',
          'normalBalance': 'debit',
          'isActive': true,
          'isSystemProtected': false,
        },
      ]);
    }

    throw DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
        data: <String, dynamic>{'message': 'Unhandled test route: $path'},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  Response<dynamic> _ok(RequestOptions options, dynamic data) => Response<dynamic>(
    requestOptions: options,
    statusCode: 200,
    data: <String, dynamic>{'data': data},
  );
}
