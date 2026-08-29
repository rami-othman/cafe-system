import 'package:intl/intl.dart';

import '../../../core/network/dio_api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../pos/models/json_helpers.dart';
import '../../pos/models/branch.dart';
import '../models/discount_list_item.dart';
import '../models/discount_upsert_request.dart';

abstract class DiscountsRepository {
  Future<List<DiscountListItem>> getDiscounts();
  Future<List<Branch>> getBranches();
  Future<DiscountListItem> createDiscount(DiscountUpsertRequest request);
  Future<DiscountListItem> updateDiscount(
    String discountId,
    DiscountUpsertRequest request,
  );
  Future<DiscountListItem> setStatus(String discountId, bool isActive);
  Future<void> deleteDiscount(String discountId);
}

class DiscountsApiRepository implements DiscountsRepository {
  const DiscountsApiRepository(this._apiClient);

  final DioApiClient _apiClient;

  @override
  Future<List<DiscountListItem>> getDiscounts() async {
    final dynamic response = await _apiClient.get('discounts');
    return readMapList(response).map(_fromJson).toList(growable: false);
  }

  @override
  Future<List<Branch>> getBranches() async {
    final dynamic response = await _apiClient.get('branches');
    return readMapList(response).map(Branch.fromJson).toList(growable: false);
  }

  @override
  Future<DiscountListItem> createDiscount(DiscountUpsertRequest request) async {
    _debugRequest('POST /discounts', request);
    final dynamic response = await _apiClient.post(
      'discounts',
      data: request.toJson(),
    );
    return _fromJson(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<DiscountListItem> updateDiscount(
    String discountId,
    DiscountUpsertRequest request,
  ) async {
    _debugRequest('PATCH /discounts/$discountId', request);
    final dynamic response = await _apiClient.patch(
      'discounts/$discountId',
      data: request.toJson(),
    );
    return _fromJson(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<DiscountListItem> setStatus(String discountId, bool isActive) async {
    final dynamic response = await _apiClient.patch(
      'discounts/$discountId/status',
      data: <String, dynamic>{'isActive': isActive},
    );
    return _fromJson(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<void> deleteDiscount(String discountId) =>
      _apiClient.delete('discounts/$discountId');

  DiscountListItem _fromJson(Map<String, dynamic> json) {
    final String type = readString(json['type']).toLowerCase();
    final double value = readDouble(json['value']);
    final DateTime? startsAt = DateTime.tryParse(
      readString(json['startsAt']),
    )?.toLocal();
    final DateTime? endsAt = DateTime.tryParse(
      readString(json['endsAt']),
    )?.toLocal();
    final String code = readString(json['code']).trim();
    final String primary = readString(json['displayPeriodPrimary']).trim();
    final String statusValue = readString(json['status']).toLowerCase();

    return DiscountListItem(
      id: readString(json['id']),
      name: readString(json['name'], fallback: 'Discount'),
      secondaryLabel: code.isEmpty ? 'Automatic' : 'Code: $code',
      type: switch (type) {
        'fixed' => 'Fixed Amount',
        'bogo' => 'BOGO',
        _ => 'Percentage',
      },
      displayValue: switch (type) {
        'fixed' => '${CurrencyFormatter.format(value)} off',
        'bogo' => 'Buy ${value.toInt()} Get ${value.toInt()}',
        _ => '${_decimal(value)}% off',
      },
      conditions: readString(json['conditions'], fallback: 'No conditions'),
      validPeriodPrimary: primary.isNotEmpty
          ? primary
          : _period(startsAt, endsAt),
      validPeriodSecondary: _nullableString(json['displayPeriodSecondary']),
      status: switch (statusValue) {
        'scheduled' => DiscountStatus.scheduled,
        'expired' => DiscountStatus.expired,
        'inactive' => DiscountStatus.inactive,
        _ => DiscountStatus.active,
      },
      usageCount: readInt(json['usedCount']) ?? 0,
      estimatedSavedValue: CurrencyFormatter.format(
        readDouble(json['estimatedSavedValue']),
      ),
      code: code.isEmpty ? null : code,
      description: _nullableString(json['description']),
      applicationMode: readString(json['applicationMode'], fallback: 'code'),
      scope: readString(json['scope'], fallback: 'order'),
      value: value,
      minimumOrderAmount: readDouble(json['minimumOrderAmount']),
      maximumDiscountAmount: json['maximumDiscountAmount'] == null
          ? null
          : readDouble(json['maximumDiscountAmount']),
      startsAt: startsAt,
      endsAt: endsAt,
      isActive: readBool(json['isActive'], fallback: statusValue != 'inactive'),
      appliesToAllBranches: readBool(
        json['appliesToAllBranches'],
        fallback: true,
      ),
      branchIds: (json['branchIds'] as List<dynamic>? ?? const <dynamic>[])
          .map(readInt)
          .whereType<int>()
          .toList(growable: false),
    );
  }

  String _period(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Always Valid';
    final DateFormat format = DateFormat('MMM d');
    if (start == null) return 'Until ${format.format(end!)}';
    if (end == null) return 'From ${format.format(start)}';
    return '${format.format(start)} - ${format.format(end)}';
  }

  String? _nullableString(dynamic value) {
    final String string = readString(value).trim();
    return string.isEmpty ? null : string;
  }

  static String _decimal(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();

  void _debugRequest(String endpoint, DiscountUpsertRequest request) {
    assert(() {
      // Branch IDs are intentionally logged only in debug builds to diagnose
      // tenant-scoped validation without exposing request data in release logs.
      // ignore: avoid_print
      print('[DiscountsRepository] $endpoint ${request.toJson()}');
      return true;
    }());
  }
}
