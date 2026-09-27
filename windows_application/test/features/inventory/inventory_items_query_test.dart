import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';

void main() {
  test('factory material type list survives HTTP query serialization', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final incoming = server.first;
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}/api/v1/'));
    addTearDown(() => dio.close(force: true));
    final api = DioApiClient(dio: dio)..scopeBranchId = 5;
    const types = ['raw_material', 'semi_finished', 'packaging'];
    final loading = InventoryRepository(api).itemsPage(types: types, branchId: 5);
    final request = await incoming;
    expect(request.uri.path, '/api/v1/inventory/items');
    expect(request.uri.queryParametersAll['types[]'], types);
    expect(request.uri.queryParameters.containsKey('types'), isFalse);
    expect(request.uri.queryParameters['scopeBranchId'], '5');
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'data': {'items': [], 'meta': {'currentPage': 1, 'lastPage': 1, 'total': 0}}}));
    await request.response.close();
    expect((await loading).items, isEmpty);
  });
}
