import '../../../core/network/dio_api_client.dart';
import '../models/discount_settings.dart';

abstract class DiscountSettingsRepository {
  Future<SavedDiscountSettings> read();
  Future<SavedDiscountSettings> save(
    DiscountSettingsDraft draft,
    int expectedVersion,
  );
  Future<Set<String>> managerPermissions();
  Future<Set<String>> replaceManagerPermissions(Set<String> permissions);
}

class ApiDiscountSettingsRepository implements DiscountSettingsRepository {
  const ApiDiscountSettingsRepository(this.api);
  final DioApiClient api;
  static const path = 'cafe-configuration/discount-settings';
  @override
  Future<SavedDiscountSettings> read() async => SavedDiscountSettings.fromJson(
    Map<String, dynamic>.from(await api.get(path)),
  );
  @override
  Future<SavedDiscountSettings> save(
    DiscountSettingsDraft draft,
    int expectedVersion,
  ) async => SavedDiscountSettings.fromJson(
    Map<String, dynamic>.from(
      await api.put(path, data: draft.toJson(expectedVersion)),
    ),
  );
  @override
  Future<Set<String>> managerPermissions() async =>
      _permissions(await api.get('discounts/role-permissions/manager'));
  @override
  Future<Set<String>> replaceManagerPermissions(
    Set<String> permissions,
  ) async => _permissions(
    await api.put(
      'discounts/role-permissions/manager',
      data: {'permissions': permissions.toList()..sort()},
    ),
  );
  Set<String> _permissions(dynamic response) =>
      Set<String>.from((response as Map)['permissions'] as List);
}
