import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_api_client.dart';
import '../models/customer_import_models.dart';

abstract interface class CustomerImportRepository {
  Future<CustomerImportStatus> previewCustomerImport({
    required Uint8List bytes,
    required String filename,
  });

  Future<CustomerImportStatus> commitCustomerImport({
    required int importId,
    required bool createMissingGroups,
  });

  Future<CustomerImportStatus> getCustomerImport(int importId);

  Future<Uint8List> downloadCustomerImportErrors(int importId);
}

class ApiCustomerImportRepository implements CustomerImportRepository {
  ApiCustomerImportRepository(this._apiClient);

  final DioApiClient _apiClient;

  @override
  Future<CustomerImportStatus> previewCustomerImport({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty || filename.trim().isEmpty) {
      throw ArgumentError('A non-empty CSV file is required.');
    }
    final dynamic response = await _apiClient.postMultipart(
      'admin/customer-management/customer-imports/preview',
      data: FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return CustomerImportStatus.fromJson(_map(response));
  }

  @override
  Future<CustomerImportStatus> commitCustomerImport({
    required int importId,
    required bool createMissingGroups,
  }) async {
    final dynamic response = await _apiClient.post(
      'admin/customer-management/customer-imports/${_id(importId)}/commit',
      data: <String, dynamic>{'createMissingGroups': createMissingGroups},
    );
    return CustomerImportStatus.fromJson(_map(response));
  }

  @override
  Future<CustomerImportStatus> getCustomerImport(int importId) async {
    final dynamic response = await _apiClient.get(
      'admin/customer-management/customer-imports/${_id(importId)}',
    );
    return CustomerImportStatus.fromJson(_map(response));
  }

  @override
  Future<Uint8List> downloadCustomerImportErrors(int importId) =>
      _apiClient.getBytes(
        'admin/customer-management/customer-imports/${_id(importId)}/errors',
      );
}

Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.cast<String, dynamic>()
    : throw const FormatException('Customer import API response is invalid.');

int _id(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'importId');
  return value;
}
