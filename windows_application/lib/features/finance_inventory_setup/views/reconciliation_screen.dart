import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_pagination.dart';
import '../widgets/finance_shell.dart';

/// Canonical Reconciliation list (`/finance/reconciliation`). Every balance,
/// difference, match count, and readiness flag comes straight from
/// `FinancialReconciliationQueryService`; this screen never recomputes
/// accounting truth, only formats it. Sessions are inherently few (created
/// per account per period), so a single generous page comfortably covers
/// real tenants — KPIs are computed from the loaded page and are exact
/// whenever `meta.total <= items.length`.
class ReconciliationScreen extends StatefulWidget {
  const ReconciliationScreen({super.key});
  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  String? _type;
  String? _status;
  String _search = '';
  int _page = 1;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  int _requestId = 0;
  FinancePage<ReconciliationSession>? _pageData;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  FinanceSetupRepository get _repository =>
      context.read<FinanceSetupCubit>().repository;

  Map<String, dynamic> get _parameters => <String, dynamic>{
    if (_type != null) 'type': _type,
    if (_status != null) 'status': _status,
    if (_search.isNotEmpty) 'search': _search,
    'page': _page,
    'perPage': 50,
  };

  Future<void> _load() async {
    final int requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final FinancePage<ReconciliationSession> page = await _repository
          .getReconciliations(filters: _parameters);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _pageData = page;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _applyType(String? type) {
    setState(() {
      _type = type;
      _page = 1;
    });
    _load();
  }

  void _applyStatus(String? status) {
    setState(() {
      _status = status;
      _page = 1;
    });
    _load();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _search = value.trim();
        _page = 1;
      });
      _load();
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _type = null;
      _status = null;
      _search = '';
      _page = 1;
    });
    _load();
  }

  void _changePage(int page) {
    setState(() => _page = page);
    _load();
  }

  Future<void> _openCreateDialog() async {
    final bool? created = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => _CreateReconciliationDialog(repository: _repository),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: FinanceShell(
        currentSection: 'التسويات',
        title: 'التسويات',
        subtitle: 'مطابقة الحركات في النظام مع كشوف الحسابات والنقدية الفعلية',
        showContext: false,
        actions: <Widget>[
          ElevatedButton.icon(
            onPressed: _openCreateDialog,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              backgroundColor: FinanceColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('تسوية جديدة'),
          ),
        ],
        child: _buildBody(),
      ),
    ),
  );

  Widget _buildBody() {
    if (_pageData == null && _error == null) {
      return const FinanceLoadingState(label: 'جارٍ تحميل التسويات…');
    }
    if (_pageData == null) {
      return FinanceErrorState(message: 'تعذّر تحميل التسويات.', onRetry: _load);
    }
    final FinancePage<ReconciliationSession> page = _pageData!;
    final bool hasFilters = _type != null || _status != null || _search.isNotEmpty;
    return SingleChildScrollView(
      child: Opacity(
        opacity: _loading ? 0.6 : 1,
        child: IgnorePointer(
          ignoring: _loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SummaryGrid(sessions: page),
              const SizedBox(height: FinanceSpace.lg),
              FinanceFilterBar(
                onReset: hasFilters ? _clearFilters : null,
                children: <Widget>[
                  _FilterDropdown(
                    label: 'النوع',
                    value: _type,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'cash', child: Text('نقدي')),
                      DropdownMenuItem<String>(value: 'bank', child: Text('بنك')),
                      DropdownMenuItem<String>(value: 'card', child: Text('بطاقة')),
                    ],
                    onChanged: _applyType,
                  ),
                  _FilterDropdown(
                    label: 'الحالة',
                    value: _status,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'in_progress', child: Text('قيد التنفيذ')),
                      DropdownMenuItem<String>(value: 'completed', child: Text('مكتملة')),
                    ],
                    onChanged: _applyStatus,
                  ),
                  SizedBox(
                    width: 220,
                    height: 34,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: FinanceText.body,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'بحث بالمرجع',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: FinanceColors.workspace,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(FinanceRadius.control),
                          borderSide: const BorderSide(color: FinanceColors.border),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FinanceSpace.lg),
              if (_error != null) ...<Widget>[
                FinanceAlertBanner(
                  message: 'تعذّر تحديث التسويات لهذه الفلاتر. تُعرض آخر بيانات محمّلة.',
                  tone: FinanceTone.warning,
                  action: TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                ),
                const SizedBox(height: FinanceSpace.md),
              ],
              if (page.items.isEmpty)
                SizedBox(
                  height: 220,
                  child: FinanceEmptyState(
                    message: hasFilters
                        ? 'لا توجد تسويات مطابقة للفلاتر المحددة'
                        : 'لا توجد تسويات مسجلة بعد',
                    action: hasFilters
                        ? TextButton(onPressed: _clearFilters, child: const Text('إعادة تعيين الفلاتر'))
                        : null,
                  ),
                )
              else ...<Widget>[
                _ReconciliationsTable(
                  rows: page.items,
                  onOpen: (ReconciliationSession s) =>
                      context.go('${AppRoutes.financeReconciliationCanonical}/${s.id}'),
                ),
                FinancePagination(meta: page.meta, onPageChanged: _changePage),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.sessions});
  final FinancePage<ReconciliationSession> sessions;

  @override
  Widget build(BuildContext context) {
    final List<ReconciliationSession> open =
        sessions.items.where((ReconciliationSession s) => s.status != 'completed').toList();
    final double unresolved = open.fold<double>(
      0,
      (double sum, ReconciliationSession s) => sum + _amount(s.balances.difference).abs(),
    );
    final int needMatching = sessions.items
        .where(
          (ReconciliationSession s) =>
              s.summary.unmatchedSystemCount > 0 || s.summary.unmatchedStatementCount > 0,
        )
        .length;
    return FinanceKpiGrid(
      items: <FinanceKpiData>[
        FinanceKpiData(label: 'تسويات مفتوحة', value: '${open.length}', icon: Icons.fact_check_outlined),
        FinanceKpiData(
          label: 'تسويات مكتملة',
          value: '${sessions.items.length - open.length}',
          icon: Icons.check_circle_outline,
        ),
        FinanceKpiData(
          label: 'فروقات غير محسومة',
          value: unresolved.toStringAsFixed(2),
          icon: Icons.warning_amber_outlined,
          tone: unresolved > 0 ? FinanceTone.danger : FinanceTone.neutral,
        ),
        FinanceKpiData(
          label: 'بحاجة مطابقة',
          value: '$needMatching',
          icon: Icons.compare_arrows_outlined,
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    constraints: const BoxConstraints(minWidth: 130),
    padding: const EdgeInsetsDirectional.only(start: FinanceSpace.sm),
    decoration: BoxDecoration(
      color: FinanceColors.workspace,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.control),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        hint: Text(label, style: FinanceText.small),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        style: FinanceText.body,
        isDense: true,
        onChanged: onChanged,
        items: <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: null, child: Text('$label: الكل')),
          ...items,
        ],
      ),
    ),
  );
}

class _ReconciliationsTable extends StatelessWidget {
  const _ReconciliationsTable({required this.rows, required this.onOpen});
  final List<ReconciliationSession> rows;
  final ValueChanged<ReconciliationSession> onOpen;

  static const Map<String, String> _typeLabels = <String, String>{
    'cash': 'نقدي',
    'bank': 'بنك',
    'card': 'بطاقة',
  };

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>[
      'الفترة',
      'الحساب',
      'النوع',
      'الفرع',
      'الافتتاحي',
      'الختامي (دفتر)',
      'الفعلي/الكشف',
      'الفرق',
      'التقدم',
      'الحالة',
    ],
    minWidth: 1400,
    onRowTap: (int index) => onOpen(rows[index]),
    rows: rows.map((ReconciliationSession s) {
      final bool balanced = s.balances.differenceDirection == 'balanced';
      final String actualOrStatement = s.type == 'cash'
          ? (s.balances.actualCash ?? '—')
          : (s.balances.externalClosing ?? '—');
      return <Widget>[
        Text(
          s.periodFrom == s.periodTo ? s.periodFrom : '${s.periodFrom} → ${s.periodTo}',
          style: FinanceText.body,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              s.account.name ?? s.account.financialAccountName,
              style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            FinanceReference(reference: s.reference),
          ],
        ),
        Text(_typeLabels[s.type] ?? s.type, style: FinanceText.body),
        Text(s.account.branchName ?? 'عام', style: FinanceText.body),
        Text(s.balances.bookOpening ?? '—', style: FinanceText.body),
        Text(s.balances.bookClosing ?? '—', style: FinanceText.body),
        Text(actualOrStatement, style: FinanceText.body),
        Text(
          s.balances.difference ?? '—',
          style: FinanceText.body.copyWith(
            fontWeight: FontWeight.w700,
            color: balanced ? FinanceColors.success : FinanceColors.danger,
          ),
        ),
        Text('${s.summary.progressPercent.round()}%', style: FinanceText.body),
        FinanceStatusBadge(status: s.status),
      ];
    }).toList(),
  );
}

class _CreateReconciliationDialog extends StatefulWidget {
  const _CreateReconciliationDialog({required this.repository});
  final FinanceSetupRepository repository;

  @override
  State<_CreateReconciliationDialog> createState() => _CreateReconciliationDialogState();
}

class _CreateReconciliationDialogState extends State<_CreateReconciliationDialog> {
  bool _loadingOptions = true;
  List<FinancialLocation> _cashLocations = const <FinancialLocation>[];
  List<FinancialLocation> _bankLocations = const <FinancialLocation>[];
  List<PaymentMethodSetting> _cardMethods = const <PaymentMethodSetting>[];

  String _type = 'cash';
  int? _locationId;
  int? _paymentMethodId;
  String _dateFrom = DateTime.now().toIso8601String().substring(0, 10);
  String _dateTo = DateTime.now().toIso8601String().substring(0, 10);
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.repository.getFinancialLocations('cash'),
        widget.repository.getFinancialLocations('bank'),
        widget.repository.getPaymentMethods(),
      ]);
      if (!mounted) return;
      setState(() {
        _cashLocations = (results[0] as List<FinancialLocation>)
            .where((FinancialLocation l) => l.isActive)
            .toList(growable: false);
        _bankLocations = (results[1] as List<FinancialLocation>)
            .where((FinancialLocation l) => l.isActive)
            .toList(growable: false);
        _cardMethods = (results[2] as List<PaymentMethodSetting>)
            .where((PaymentMethodSetting m) => m.isActive)
            .toList(growable: false);
        _locationId = _cashLocations.isEmpty ? null : _cashLocations.first.id;
        _loadingOptions = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loadingOptions = false;
        });
      }
    }
  }

  List<FinancialLocation> get _locationsForType => _type == 'cash' ? _cashLocations : _bankLocations;

  void _onTypeChanged(String type) {
    setState(() {
      _type = type;
      _locationId = type == 'card'
          ? null
          : (_locationsForType.isEmpty ? null : _locationsForType.first.id);
      _paymentMethodId = type == 'card' && _cardMethods.isNotEmpty ? _cardMethods.first.id : null;
    });
  }

  Future<void> _pickDate(bool isTo) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(isTo ? _dateTo : _dateFrom) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      final String value = picked.toIso8601String().substring(0, 10);
      if (isTo) {
        _dateTo = value;
      } else {
        _dateFrom = value;
      }
    });
  }

  Future<void> _submit() async {
    if (_type == 'card' && _paymentMethodId == null) {
      setState(() => _error = 'اختر طريقة دفع بطاقة نشطة.');
      return;
    }
    if (_type != 'card' && _locationId == null) {
      setState(() => _error = 'اختر حساباً نقدياً أو بنكياً نشطاً.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repository.createReconciliation(<String, dynamic>{
        'type': _type,
        if (_type != 'card') 'financialLocationId': _locationId,
        if (_type == 'card') 'paymentMethodId': _paymentMethodId,
        'dateFrom': _dateFrom,
        'dateTo': _dateTo,
        'idempotencyKey': 'reconciliation-${DateTime.now().microsecondsSinceEpoch}',
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FinanceDialogShell(
    title: 'تسوية جديدة',
    actions: <Widget>[
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context, false),
        child: const Text('إلغاء'),
      ),
      ElevatedButton(
        onPressed: _submitting || _loadingOptions ? null : _submit,
        style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
        child: _submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('إنشاء'),
      ),
    ],
    child: _loadingOptions
        ? const SizedBox(height: 140, child: FinanceLoadingState(label: 'جارٍ تحميل الخيارات…'))
        : SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'نوع التسوية'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'cash', child: Text('نقدي')),
                      DropdownMenuItem<String>(value: 'bank', child: Text('بنك')),
                      DropdownMenuItem<String>(value: 'card', child: Text('بطاقة')),
                    ],
                    onChanged: (String? v) => _onTypeChanged(v!),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  if (_type == 'card')
                    DropdownButtonFormField<int?>(
                      initialValue: _paymentMethodId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'طريقة الدفع (بطاقة)'),
                      items: _cardMethods
                          .map(
                            (PaymentMethodSetting m) =>
                                DropdownMenuItem<int?>(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis)),
                          )
                          .toList(),
                      onChanged: (int? v) => setState(() => _paymentMethodId = v),
                    )
                  else
                    DropdownButtonFormField<int?>(
                      initialValue: _locationId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: _type == 'cash' ? 'الحساب النقدي' : 'الحساب البنكي'),
                      items: _locationsForType
                          .map(
                            (FinancialLocation l) =>
                                DropdownMenuItem<int?>(value: l.id, child: Text(l.name, overflow: TextOverflow.ellipsis)),
                          )
                          .toList(),
                      onChanged: (int? v) => setState(() => _locationId = v),
                    ),
                  const SizedBox(height: FinanceSpace.md),
                  InkWell(
                    onTap: () => _pickDate(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'من تاريخ'),
                      child: Text(_dateFrom),
                    ),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  InkWell(
                    onTap: () => _pickDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'إلى تاريخ'),
                      child: Text(_dateTo),
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: FinanceSpace.sm),
                    Text(_error!, style: const TextStyle(color: FinanceColors.danger)),
                  ],
                ],
              ),
            ),
          ),
  );
}

double _amount(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
