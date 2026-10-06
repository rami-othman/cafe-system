import '../../../core/network/api_exception.dart';
import '../models/discount_product_selection.dart';
import '../../../core/network/dio_api_client.dart';
import '../../../core/utils/backend_datetime.dart';
import '../../pos/models/json_helpers.dart';
import '../../pos/models/branch.dart';
import '../models/discount_list_item.dart';
import '../models/discount_detail.dart';
import '../models/discount_form_references.dart';
import '../models/discount_dashboard_metrics.dart';
import '../models/discount_upsert_request.dart';

abstract class DiscountsRepository {
  Future<DiscountReferencePage> getProducts({
    String search = '',
    int page = 1,
  }) async =>
      DiscountReferencePage(items: (await getFormReferences()).products);
  Future<DiscountReferencePage> getVariants(
    int productId, {
    String search = '',
    int page = 1,
  }) async => const DiscountReferencePage();
  Future<List<DiscountListItem>> getDiscounts();
  Future<DiscountDashboardMetrics> getDashboardMetrics();
  Future<List<Branch>> getBranches();

  /// Optional for older test fakes. Production provides all V1 selectors.
  Future<DiscountFormReferences> getFormReferences() async =>
      const DiscountFormReferences();
  Future<DiscountDetail> getDiscountDetail(String discountId) =>
      Future<DiscountDetail>.error(
        UnimplementedError('Discount detail is unavailable.'),
      );
  Future<String> generateCouponCode() => Future<String>.error(
    UnimplementedError('Coupon generation is unavailable.'),
  );
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
  Future<DiscountReferencePage> getProducts({
    String search = '',
    int page = 1,
  }) => _referencePage('discounts/references/products', search, page);
  @override
  Future<DiscountReferencePage> getVariants(
    int productId, {
    String search = '',
    int page = 1,
  }) => _referencePage(
    'discounts/references/products/$productId/variants',
    search,
    page,
  );
  Future<DiscountReferencePage> _referencePage(
    String path,
    String search,
    int page,
  ) async => DiscountReferencePage.fromJson(
    Map<String, dynamic>.from(
      await _apiClient.getEnvelope(
        path,
        queryParameters: {
          'page': page,
          'perPage': 20,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      ),
    ),
  );

  @override
  Future<List<DiscountListItem>> getDiscounts() async {
    final dynamic response = await _apiClient.get('discounts');
    return readMapList(response).map(_fromJson).toList(growable: false);
  }

  @override
  Future<DiscountDashboardMetrics> getDashboardMetrics() async {
    final dynamic response = await _apiClient.get('discounts/metrics');
    return DiscountDashboardMetrics.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  @override
  Future<List<Branch>> getBranches() async {
    final dynamic response = await _apiClient.get('branches');
    return readMapList(response).map(Branch.fromJson).toList(growable: false);
  }

  @override
  Future<DiscountFormReferences> getFormReferences() async {
    final failures = <String, String>{};
    Future<dynamic> load(String section, String path) async {
      try {
        if (section == 'products') {
          final envelope = await _apiClient.getEnvelope(
            path,
            queryParameters: const {'page': 1, 'perPage': 100},
          );
          return (envelope as Map)['data'];
        }
        return await _apiClient.get(
          path,
          queryParameters: const {'perPage': 100},
        );
      } catch (error) {
        failures[section] = error is ApiException && error.statusCode == 403
            ? 'forbidden'
            : 'failed';
        return <dynamic>[];
      }
    }

    final responses = await Future.wait<dynamic>([
      load('products', 'discounts/references/products'),
      load('categories', 'admin/catalog/categories'),
      load('customerGroups', 'customer-groups'),
      load('customers', 'customers'),
      load('paymentMethods', 'finance/payment-methods'),
    ]);
    List<DiscountFormReference> references(dynamic value) => readMapList(value)
        .map(DiscountFormReference.fromJson)
        .where((DiscountFormReference item) => item.id > 0 && item.isAvailable)
        .toList(growable: false);

    return DiscountFormReferences(
      failures: failures,
      products: references(responses[0]),
      categories: references(responses[1]),
      customerGroups: references(responses[2]),
      customers: readMapList(responses[3])
          .map(
            (Map<String, dynamic> item) => DiscountFormReference(
              id: readInt(item['id']) ?? 0,
              name: readString(item['name']),
              isActive: true,
              subtitle: _nullableString(item['phone']),
            ),
          )
          .where((DiscountFormReference item) => item.id > 0)
          .toList(growable: false),
      paymentMethods: references(responses[4]),
    );
  }

  @override
  Future<DiscountDetail> getDiscountDetail(String discountId) async {
    final dynamic response = await _apiClient.get('discounts/$discountId');
    return DiscountDetail.fromJson(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<String> generateCouponCode() async {
    final dynamic response = await _apiClient.post('discounts/generate-code');
    final String code = readString((response as Map?)?['code']).trim();
    if (code.isEmpty) {
      throw StateError('The server did not return a coupon code.');
    }
    return code;
  }

  @override
  Future<DiscountListItem> createDiscount(DiscountUpsertRequest request) async {
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
    final DateTime? startsAt = parseBackendDateTime(
      readString(json['startsAt']),
    );
    final DateTime? endsAt = parseBackendDateTime(readString(json['endsAt']));
    final DateTime? startDate = _date(readString(json['startDate']));
    final DateTime? endDate = _date(readString(json['endDate']));
    final String code = readString(json['code']).trim();
    final String statusValue = readString(json['status']).toLowerCase();

    return DiscountListItem(
      id: readString(json['id']),
      name: readString(json['name']),
      type: type,
      status: switch (statusValue) {
        'scheduled' => DiscountStatus.scheduled,
        'expired' => DiscountStatus.expired,
        'inactive' => DiscountStatus.inactive,
        _ => DiscountStatus.active,
      },
      usageCount: readInt(json['usedCount']) ?? 0,
      estimatedSavedValue: readDouble(json['estimatedSavedValue']),
      code: code.isEmpty ? null : code,
      description: _nullableString(json['description']),
      conditions: _nullableString(json['conditions']),
      applicationMode: readString(json['applicationMode'], fallback: 'code'),
      scope: readString(json['scope'], fallback: 'order'),
      value: value,
      fixedAmountBasis: readString(
        json['fixedAmountBasis'],
        fallback: 'per_order',
      ),
      minimumOrderAmount: readDouble(json['minimumOrderAmount']),
      maximumDiscountAmount: json['maximumDiscountAmount'] == null
          ? null
          : readDouble(json['maximumDiscountAmount']),
      startDate: startDate,
      endDate: endDate,
      startsAt: startsAt,
      endsAt: endsAt,
      displayPeriodPrimary: _nullableString(json['displayPeriodPrimary']),
      displayPeriodSecondary: _nullableString(json['displayPeriodSecondary']),
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

  String? _nullableString(dynamic value) {
    final String string = readString(value).trim();
    return string.isEmpty ? null : string;
  }

  DateTime? _date(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    return DateTime.tryParse(value);
  }
}
