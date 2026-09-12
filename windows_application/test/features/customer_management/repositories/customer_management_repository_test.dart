import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/customer_management/models/customer_drafts.dart';
import 'package:windows_application/features/customer_management/models/customer_failure.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';

void main() {
  test(
    'covers every approved customer-management endpoint and payload',
    () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(<_Reply>[
        _Reply.ok(<String, dynamic>{
          'data': <String, dynamic>{
            'customer': <String, dynamic>{'manage': true},
          },
        }),
        _Reply.ok(_customerPage()),
        _Reply.ok(<String, dynamic>{'data': _customerJson()}),
        _Reply.ok(<String, dynamic>{'data': _customerJson()}),
        _Reply.ok(<String, dynamic>{'data': _customerJson()}),
        _Reply.ok(<String, dynamic>{'data': _customerJson()}),
        _Reply.ok(_groupPage()),
        _Reply.ok(<String, dynamic>{'data': _groupJson()}),
        _Reply.ok(<String, dynamic>{'data': _groupJson()}),
        _Reply.ok(<String, dynamic>{'data': _groupJson()}),
        _Reply.ok(<String, dynamic>{'data': _groupJson()}),
        _Reply.ok(_customerPage()),
        _Reply.ok(_customerPage()),
        _Reply.ok(<String, dynamic>{'data': _groupJson()}),
        _Reply.ok(<String, dynamic>{'data': _groupJson()}),
      ]);
      final ApiCustomerManagementRepository repository = _repository(adapter);
      const CustomerDraft customerDraft = CustomerDraft(
        name: 'Rami',
        phones: <CustomerPhoneDraft>[
          CustomerPhoneDraft(
            rowId: 'row-a',
            rawNumber: '+963 9',
            type: 'mobile',
            isPrimary: true,
          ),
        ],
        groupIds: <int>{4, 2},
      );
      const GroupDraft groupDraft = GroupDraft(name: 'VIP');
      const CustomerListQuery customerQuery = CustomerListQuery(
        search: 'Rami',
        status: CustomerStatusFilter.active,
        groupId: 7,
        page: 2,
        perPage: 30,
      );
      const CustomerGroupListQuery groupQuery = CustomerGroupListQuery(
        search: 'VIP',
        status: CustomerStatusFilter.active,
        page: 3,
        perPage: 10,
      );

      expect(await repository.fetchCustomerManagementCapability(), isTrue);
      await repository.listCustomers(customerQuery);
      await repository.getCustomer(1);
      await repository.createCustomer(customerDraft);
      await repository.updateCustomer(1, customerDraft);
      await repository.changeCustomerLifecycle(1, 'archive');
      await repository.listGroups(groupQuery);
      await repository.getGroup(2);
      await repository.createGroup(groupDraft);
      await repository.updateGroup(2, groupDraft);
      await repository.changeGroupLifecycle(2, 'restore');
      await repository.listGroupMembers(2, groupQuery);
      await repository.listEligibleMembers(2, groupQuery);
      await repository.addGroupMembers(2, <int>{9, 3});
      await repository.removeGroupMember(2, 3);

      expect(
        adapter.requests.map(
          (RequestOptions request) => '${request.method} ${request.path}',
        ),
        <String>[
          'GET customer-management/capabilities',
          'GET admin/customer-management/customers',
          'GET admin/customer-management/customers/1',
          'POST admin/customer-management/customers',
          'PUT admin/customer-management/customers/1',
          'POST admin/customer-management/customers/1/archive',
          'GET admin/customer-management/customer-groups',
          'GET admin/customer-management/customer-groups/2',
          'POST admin/customer-management/customer-groups',
          'PUT admin/customer-management/customer-groups/2',
          'POST admin/customer-management/customer-groups/2/restore',
          'GET admin/customer-management/customer-groups/2/members',
          'GET admin/customer-management/customer-groups/2/eligible-members',
          'POST admin/customer-management/customer-groups/2/members',
          'DELETE admin/customer-management/customer-groups/2/members/3',
        ],
      );
      expect(
        adapter.requests[1].queryParameters,
        customerQuery.toQueryParameters(),
      );
      expect(
        adapter.requests[6].queryParameters,
        groupQuery.toQueryParameters(),
      );
      expect(adapter.requests[3].data, <String, dynamic>{
        'name': 'Rami',
        'email': null,
        'birthDate': null,
        'notes': null,
        'phones': <Map<String, dynamic>>[
          <String, dynamic>{
            'rawNumber': '+963 9',
            'type': 'mobile',
            'isPrimary': true,
          },
        ],
        'groupIds': <int>[2, 4],
      });
      expect(adapter.requests[8].data, <String, dynamic>{'name': 'VIP'});
      expect(adapter.requests[13].data, <String, dynamic>{
        'customerIds': <int>[3, 9],
      });
      expect(
        adapter.requests.every(
          (RequestOptions request) =>
              !request.headers.containsKey('X-Tenant-Id'),
        ),
        isTrue,
      );
    },
  );

  for (final _FailureCase failure in <_FailureCase>[
    _FailureCase.status(403, CustomerFailureKind.forbidden),
    _FailureCase.status(404, CustomerFailureKind.notFound),
    _FailureCase.status(409, CustomerFailureKind.conflict),
    _FailureCase.status(422, CustomerFailureKind.validation),
    _FailureCase.error(
      DioExceptionType.connectionTimeout,
      CustomerFailureKind.timeout,
    ),
    _FailureCase.error(
      DioExceptionType.connectionError,
      CustomerFailureKind.network,
      const SocketException('offline'),
    ),
    _FailureCase.status(500, CustomerFailureKind.server),
  ]) {
    test('maps ${failure.name} from the production Dio repository', () async {
      final ApiCustomerManagementRepository repository = _repository(
        _ScriptedAdapter(<_Reply>[failure.reply]),
      );
      await expectLater(
        repository.getCustomer(1),
        throwsA(
          isA<Object>().having(
            (Object error) => CustomerFailure.fromError(error).kind,
            'localized failure kind',
            failure.kind,
          ),
        ),
      );
    });
  }
}

ApiCustomerManagementRepository _repository(_ScriptedAdapter adapter) =>
    ApiCustomerManagementRepository(
      DioApiClient(dio: Dio()..httpClientAdapter = adapter),
    );
Map<String, dynamic> _customerJson() => <String, dynamic>{
  'id': 1,
  'customerNumber': 'C-000001',
  'name': 'Rami',
  'status': 'active',
  'phones': const <dynamic>[],
  'groups': const <dynamic>[],
  'allowedActions': const <String>['update'],
};
Map<String, dynamic> _groupJson() => <String, dynamic>{
  'id': 2,
  'name': 'VIP',
  'status': 'active',
  'memberCount': 0,
};
Map<String, dynamic> _customerPage() => <String, dynamic>{
  'data': <Map<String, dynamic>>[_customerJson()],
  'meta': <String, dynamic>{
    'currentPage': 1,
    'lastPage': 1,
    'perPage': 30,
    'total': 1,
  },
};
Map<String, dynamic> _groupPage() => <String, dynamic>{
  'data': <Map<String, dynamic>>[_groupJson()],
  'meta': <String, dynamic>{
    'currentPage': 1,
    'lastPage': 1,
    'perPage': 30,
    'total': 1,
  },
};

class _FailureCase {
  const _FailureCase._(this.name, this.kind, this.reply);
  factory _FailureCase.status(int status, CustomerFailureKind kind) =>
      _FailureCase._(
        'HTTP $status',
        kind,
        _Reply.status(status, <String, dynamic>{
          'code': 'CUSTOMER_FAILURE',
          'errors': <String, dynamic>{
            'phones.0.rawNumber': <String>['Invalid'],
          },
        }),
      );
  factory _FailureCase.error(
    DioExceptionType type,
    CustomerFailureKind kind, [
    Object? error,
  ]) => _FailureCase._(type.name, kind, _Reply.error(type, error));
  final String name;
  final CustomerFailureKind kind;
  final _Reply reply;
}

class _Reply {
  const _Reply._({
    this.statusCode = 200,
    this.body,
    this.errorType,
    this.error,
  });
  factory _Reply.ok(Object body) => _Reply._(body: body);
  factory _Reply.status(int statusCode, Object body) =>
      _Reply._(statusCode: statusCode, body: body);
  factory _Reply.error(DioExceptionType type, Object? error) =>
      _Reply._(errorType: type, error: error);
  final int statusCode;
  final Object? body;
  final DioExceptionType? errorType;
  final Object? error;
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._replies);
  final List<_Reply> _replies;
  final List<RequestOptions> requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final _Reply reply = _replies.removeAt(0);
    if (reply.errorType != null)
      throw DioException(
        requestOptions: options,
        type: reply.errorType!,
        error: reply.error,
      );
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.statusCode,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
