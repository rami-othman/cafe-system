import '../../../core/network/dio_api_client.dart';
import '../models/cashier_dashboard.dart';

/// Reads the two Cashier operational endpoints. One aggregate call renders the
/// whole dashboard, so opening the till screen does not fan out across the POS,
/// shift, orders, finance and inventory APIs.
class CashierDashboardRepository {
  const CashierDashboardRepository({this.apiClient});

  final DioApiClient? apiClient;

  Future<CashierDashboard> dashboard({int? branchId}) async {
    final DioApiClient? client = apiClient;
    if (client == null) return CashierDashboard.empty;

    final dynamic response = await client.get(
      'cashier/dashboard',
      queryParameters: <String, dynamic>{
        if (branchId case final int value) 'branchId': value,
      },
    );
    return CashierDashboard.fromJson(
      response is Map
          ? Map<String, dynamic>.from(response)
          : const <String, dynamic>{},
    );
  }

  Future<CashierStockPage> inventory({
    int? branchId,
    String? search,
    String? state,
    int page = 1,
    int perPage = 50,
  }) async {
    final DioApiClient? client = apiClient;
    if (client == null) return CashierStockPage.empty;

    final dynamic response = await client.get(
      'cashier/inventory',
      queryParameters: <String, dynamic>{
        if (branchId case final int value) 'branchId': value,
        if (search != null && search.isNotEmpty) 'search': search,
        if (state != null && state.isNotEmpty) 'state': state,
        'page': page,
        'perPage': perPage,
      },
    );
    return CashierStockPage.fromJson(
      response is Map
          ? Map<String, dynamic>.from(response)
          : const <String, dynamic>{},
    );
  }
}
