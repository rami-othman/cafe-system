import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_order_history_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_order_history_state.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';

void main() {
  test(
    'loads authorized branches, applies filters and paginates server-side',
    () async {
      final _OrdersRepository repository = _OrdersRepository();
      final CustomerOrderHistoryCubit cubit = CustomerOrderHistoryCubit(
        repository,
      );

      await cubit.load(7);
      await cubit.apply(const CustomerOrderQuery(branchId: 2, page: 2));

      expect(cubit.state.status, CustomerOrderHistoryStatus.success);
      expect(cubit.state.branches, hasLength(2));
      expect(repository.queries, const <CustomerOrderQuery>[
        CustomerOrderQuery(),
        CustomerOrderQuery(branchId: 2, page: 2),
      ]);
      expect(cubit.state.page!.meta.currentPage, 2);
      await cubit.close();
    },
  );

  test(
    'keeps a retryable failure explicit and retries the same query',
    () async {
      final _OrdersRepository repository = _OrdersRepository(
        failFirstOrderLoad: true,
      );
      final CustomerOrderHistoryCubit cubit = CustomerOrderHistoryCubit(
        repository,
      );

      await cubit.load(7, query: const CustomerOrderQuery(page: 2));
      expect(cubit.state.status, CustomerOrderHistoryStatus.failure);
      expect(cubit.state.failure, isNotNull);

      await cubit.retry();
      expect(cubit.state.status, CustomerOrderHistoryStatus.success);
      expect(repository.queries.last, const CustomerOrderQuery(page: 2));
      await cubit.close();
    },
  );
}

class _OrdersRepository implements CustomerManagementRepository {
  _OrdersRepository({this.failFirstOrderLoad = false});

  final bool failFirstOrderLoad;
  final List<CustomerOrderQuery> queries = <CustomerOrderQuery>[];
  bool _failed = false;

  @override
  Future<Customer> getCustomer(int customerId) async => const Customer(
    id: 7,
    customerNumber: 'C-007',
    name: 'Ada',
    lifecycle: CustomerLifecycle.active,
    phones: <CustomerPhone>[],
    groups: <CustomerGroupSummary>[],
    allowedActions: <String>{},
  );

  @override
  Future<List<CustomerOrderBranch>> listPermittedOrderBranches() async =>
      const <CustomerOrderBranch>[
        CustomerOrderBranch(id: 1, name: 'Main'),
        CustomerOrderBranch(id: 2, name: 'Airport'),
      ];

  @override
  Future<CustomerPage<CustomerOrder>> listCustomerOrders(
    int customerId,
    CustomerOrderQuery query,
  ) async {
    queries.add(query);
    if (failFirstOrderLoad && !_failed) {
      _failed = true;
      throw Exception('offline');
    }
    return CustomerPage<CustomerOrder>(
      items: const <CustomerOrder>[],
      meta: CustomerPageMeta(
        currentPage: query.page,
        lastPage: 2,
        perPage: query.perPage,
        total: 30,
      ),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
