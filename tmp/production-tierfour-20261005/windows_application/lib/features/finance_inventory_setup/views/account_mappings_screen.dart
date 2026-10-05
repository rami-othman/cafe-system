import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/dio_api_client.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../widgets/account_picker_field.dart';
import '../widgets/finance_components.dart';

/// ربط الحسابات: أين يُرحَّل كل نوع من القيود (إيراد المبيعات، الضريبة، تكلفة
/// المبيعات، المخزون، فروقات المخزون، زيادة/عجز الصندوق…). المالك يختار الحساب
/// من الشجرة، والخادم يتحقق أنه من المجموعة الصحيحة وحساب نهائي.
class AccountMappingsScreen extends StatefulWidget {
  const AccountMappingsScreen({super.key});

  @override
  State<AccountMappingsScreen> createState() => _AccountMappingsScreenState();
}

class _Mapping {
  const _Mapping({
    required this.key,
    required this.label,
    required this.hint,
    required this.accountId,
    required this.allowedGroups,
    this.needsDefault = false,
  });

  final String key;
  final String label;
  final String hint;
  final int? accountId;
  final List<String> allowedGroups;
  final bool needsDefault;

  factory _Mapping.fromJson(Map<String, dynamic> json) => _Mapping(
    key: '${json['key']}',
    label: '${json['label']}',
    hint: '${json['hint'] ?? ''}',
    accountId: (json['accountId'] as num?)?.toInt(),
    needsDefault: json['needsDefault'] == true,
    allowedGroups: (json['allowedGroups'] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic g) => '$g')
        .toList(growable: false),
  );
}

class _AccountMappingsScreenState extends State<AccountMappingsScreen> {
  final DioApiClient _api = serviceLocator<DioApiClient>();
  List<_Mapping> _items = const <_Mapping>[];
  List<FinancialAccount> _accounts = const <FinancialAccount>[];
  bool _loading = true;
  String? _error;
  String? _saving;
  bool _defaulting = false;
  bool _autoTried = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _api.get('finance/account-mappings'),
        context.read<FinanceSetupCubit>().repository.getAccountCatalog(),
      ]);
      final dynamic raw = results[0];
      final List<dynamic> rows = raw is List ? raw : (raw as Map)['data'] as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _items = rows
            .map((dynamic v) => _Mapping.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(growable: false);
        _accounts = results[1] as List<FinancialAccount>;
        _loading = false;
      });
      // أول فتح: أي بند فارغ أو غير صالح يُعبَّأ تلقائيًا بالحساب الافتراضي من الدليل.
      if (!_autoTried && _items.any((_Mapping m) => m.needsDefault)) {
        _autoTried = true;
        await _applyDefaults(silent: true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _applyDefaults({bool silent = false, bool overwrite = false}) async {
    setState(() => _defaulting = true);
    try {
      final dynamic result = await _api.post(
        'finance/account-mappings/defaults',
        data: <String, dynamic>{'overwrite': overwrite},
      );
      final int count = result is Map ? (result['count'] as num?)?.toInt() ?? 0 : 0;
      if (!mounted) return;
      if (!silent || count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'تم تعيين $count حساب افتراضي من دليل الحسابات.'
                  : 'كل البنود مربوطة بحسابات صالحة.',
            ),
          ),
        );
      }
      if (count > 0) await _load();
    } catch (error) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _defaulting = false);
    }
  }

  Future<void> _confirmReset() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('إعادة كل الربط للافتراضي'),
        content: const Text(
          'سيُستبدل كل ربط حالي (حتى الذي اخترته يدويًا) بالحساب الافتراضي. القيود القديمة لا تتغير.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('إعادة للافتراضي')),
        ],
      ),
    );
    if (ok == true) await _applyDefaults(overwrite: true);
  }

  Future<void> _change(_Mapping item, int? accountId) async {
    if (accountId == null || accountId == item.accountId) return;
    setState(() => _saving = item.key);
    try {
      await _api.put(
        'finance/account-mappings/${item.key}',
        data: <String, dynamic>{'accountId': accountId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الربط. القيود الجديدة ستستخدم هذا الحساب.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      FinancePageHeader(
        title: 'ربط الحسابات',
        subtitle:
            'اختر الحساب الذي تُرحَّل إليه كل عملية (المبيعات، الضريبة، تكلفة المبيعات، المخزون، فروقات المخزون، زيادة وعجز الصندوق). التغيير يسري على القيود الجديدة فقط.',
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: _defaulting || _loading ? null : _applyDefaults,
            icon: _defaulting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: const Text('تعبئة الافتراضي'),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: _defaulting || _loading ? null : _confirmReset,
            child: const Text('إعادة الكل للافتراضي'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Expanded(child: _content()),
    ],
  );

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ManagementMessage(message: _error!, error: true, onRetry: _load);
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        final _Mapping item = _items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (item.hint.isNotEmpty)
                        Text(item.hint, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 5,
                  child: AccountPickerField(
                    label: 'الحساب',
                    accounts: _accounts,
                    value: item.accountId,
                    where: (FinancialAccount a) => item.allowedGroups.contains(a.accountGroup),
                    onChanged: _saving == null ? (int? id) => _change(item, id) : (_) {},
                  ),
                ),
                if (_saving == item.key)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
