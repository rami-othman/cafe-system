import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../pos/models/branch.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/daily_closing_support.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_pagination.dart';
import '../widgets/finance_shell.dart';

/// Canonical Daily Closing history (`/finance/daily-closing`). Every KPI,
/// figure and readiness badge is `DailyClosingController::present()` output
/// re-derived per row by the backend — this screen only formats it and never
/// recomputes net sales, cash, or readiness locally.
class DailyClosingScreen extends StatefulWidget {
  const DailyClosingScreen({super.key});
  @override
  State<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends State<DailyClosingScreen> {
  int? _branchId;
  String? _status;
  String? _from;
  String? _to;
  int _page = 1;

  List<Branch> _branches = const <Branch>[];
  FinancePage<DailyClosingListItem>? _pageData;
  Object? _error;
  bool _loading = false;
  int _requestId = 0;

  FinanceSetupRepository get _repository => context.read<FinanceSetupCubit>().repository;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _load();
  }

  Future<void> _loadBranches() async {
    try {
      final List<Branch> branches = await _repository.getBranches();
      if (mounted) setState(() => _branches = branches);
    } catch (_) {
      // Branch filter degrades gracefully to "all branches" on failure.
    }
  }

  Map<String, dynamic> get _parameters => <String, dynamic>{
    if (_branchId != null) 'branchId': _branchId,
    if (_status != null) 'status': _status,
    if (_from != null) 'from': _from,
    if (_to != null) 'to': _to,
    'page': _page,
    'perPage': 50,
  };

  Future<void> _load() async {
    final int requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final FinancePage<DailyClosingListItem> page = await _repository.getDailyClosings(
        filters: _parameters,
      );
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

  void _applyBranch(int? branchId) {
    setState(() {
      _branchId = branchId;
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

  Future<void> _pickDate({required bool isTo}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse((isTo ? _to : _from) ?? '') ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    final String value = picked.toIso8601String().substring(0, 10);
    setState(() {
      if (isTo) {
        _to = value;
      } else {
        _from = value;
      }
      _page = 1;
    });
    _load();
  }

  void _clearFilters() {
    setState(() {
      _branchId = null;
      _status = null;
      _from = null;
      _to = null;
      _page = 1;
    });
    _load();
  }

  void _changePage(int page) {
    setState(() => _page = page);
    _load();
  }

  Future<void> _openDayDialog() async {
    final DailyClosingDetail? opened = await showDialog<DailyClosingDetail>(
      context: context,
      builder: (BuildContext dialog) => _OpenDayDialog(repository: _repository, branches: _branches),
    );
    if (opened == null || !mounted) return;
    await _load();
    if (mounted) context.go('${AppRoutes.financeDailyClosingCanonical}/${opened.id}');
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: FinanceShell(
        currentSection: 'الإغلاق اليومي',
        title: 'الإغلاق اليومي',
        subtitle: 'سجل الإغلاقات اليومية لكل فرع مع حالة التسوية والجاهزية',
        showContext: false,
        actions: <Widget>[
          ElevatedButton.icon(
            onPressed: _openDayDialog,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              backgroundColor: FinanceColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('فتح إغلاق يوم'),
          ),
        ],
        child: _buildBody(),
      ),
    ),
  );

  Widget _buildBody() {
    if (_pageData == null && _error == null) {
      return const FinanceLoadingState(label: 'جارٍ تحميل الإغلاقات اليومية…');
    }
    if (_pageData == null) {
      return FinanceErrorState(message: 'تعذّر تحميل الإغلاقات اليومية.', onRetry: _load);
    }
    final FinancePage<DailyClosingListItem> page = _pageData!;
    final bool hasFilters = _branchId != null || _status != null || _from != null || _to != null;
    return SingleChildScrollView(
      child: Opacity(
        opacity: _loading ? 0.6 : 1,
        child: IgnorePointer(
          ignoring: _loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SummaryGrid(items: page.items),
              const SizedBox(height: FinanceSpace.lg),
              FinanceFilterBar(
                onReset: hasFilters ? _clearFilters : null,
                children: <Widget>[
                  _BranchDropdown(branches: _branches, value: _branchId, onChanged: _applyBranch),
                  _StatusDropdown(value: _status, onChanged: _applyStatus),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(isTo: false),
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(_from == null ? 'من تاريخ' : _from!),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(isTo: true),
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(_to == null ? 'إلى تاريخ' : _to!),
                  ),
                ],
              ),
              const SizedBox(height: FinanceSpace.lg),
              if (_error != null) ...<Widget>[
                FinanceAlertBanner(
                  message: 'تعذّر تحديث القائمة لهذه الفلاتر. تُعرض آخر بيانات محمّلة.',
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
                        ? 'لا توجد إغلاقات مطابقة للفلاتر المحددة'
                        : 'لا توجد إغلاقات يومية مسجلة بعد',
                    action: hasFilters
                        ? TextButton(onPressed: _clearFilters, child: const Text('إعادة تعيين الفلاتر'))
                        : null,
                  ),
                )
              else ...<Widget>[
                _DailyClosingTable(
                  rows: page.items,
                  onOpen: (DailyClosingListItem item) =>
                      context.go('${AppRoutes.financeDailyClosingCanonical}/${item.id}'),
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
  const _SummaryGrid({required this.items});
  final List<DailyClosingListItem> items;

  @override
  Widget build(BuildContext context) {
    final int open = items.where((DailyClosingListItem d) => d.status != 'closed').length;
    final int closed = items.length - open;
    final int needsAttention = items
        .where((DailyClosingListItem d) => d.status != 'closed' && d.readiness == 'blocked')
        .length;
    return FinanceKpiGrid(
      items: <FinanceKpiData>[
        FinanceKpiData(label: 'أيام مفتوحة', value: '$open', icon: Icons.lock_open_outlined),
        FinanceKpiData(label: 'أيام مغلقة', value: '$closed', icon: Icons.lock_outline, tone: FinanceTone.success),
        FinanceKpiData(
          label: 'أيام بحاجة معالجة',
          value: '$needsAttention',
          icon: Icons.warning_amber_outlined,
          tone: needsAttention > 0 ? FinanceTone.danger : FinanceTone.neutral,
        ),
      ],
    );
  }
}

class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({required this.branches, required this.value, required this.onChanged});
  final List<Branch> branches;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    constraints: const BoxConstraints(minWidth: 150),
    padding: const EdgeInsetsDirectional.only(start: FinanceSpace.sm),
    decoration: BoxDecoration(
      color: FinanceColors.workspace,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.control),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: value,
        hint: const Text('الفرع', style: FinanceText.small),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        style: FinanceText.body,
        isDense: true,
        onChanged: onChanged,
        items: <DropdownMenuItem<int?>>[
          const DropdownMenuItem<int?>(value: null, child: Text('الفرع: الكل')),
          ...branches.map(
            (Branch branch) => DropdownMenuItem<int?>(value: branch.id, child: Text('الفرع: ${branch.name}')),
          ),
        ],
      ),
    ),
  );
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.value, required this.onChanged});
  final String? value;
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
      child: DropdownButton<String?>(
        value: value,
        hint: const Text('الحالة', style: FinanceText.small),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        style: FinanceText.body,
        isDense: true,
        onChanged: onChanged,
        items: const <DropdownMenuItem<String?>>[
          DropdownMenuItem<String?>(value: null, child: Text('الحالة: الكل')),
          DropdownMenuItem<String?>(value: 'open', child: Text('مفتوح')),
          DropdownMenuItem<String?>(value: 'closed', child: Text('مغلق')),
        ],
      ),
    ),
  );
}

class _DailyClosingTable extends StatelessWidget {
  const _DailyClosingTable({required this.rows, required this.onOpen});
  final List<DailyClosingListItem> rows;
  final ValueChanged<DailyClosingListItem> onOpen;

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>[
      'التاريخ',
      'الفرع',
      'صافي المبيعات',
      'النقد المتوقع',
      'النقد الفعلي',
      'الفرق',
      'حالة التسوية',
      'حالة الإغلاق',
      'أُغلق في',
    ],
    minWidth: 1300,
    onRowTap: (int index) => onOpen(rows[index]),
    rows: rows.map((DailyClosingListItem d) {
      final DailyClosingReadinessState state = dailyClosingReadinessState(d.readiness, d.warningsCount);
      final bool balanced = d.difference == null || _isZero(d.difference!);
      return <Widget>[
        Text(d.businessDate, style: FinanceText.body),
        Text(d.branchName, style: FinanceText.body),
        FinanceAmount(value: d.netSales),
        FinanceAmount(value: d.expectedCash ?? '—'),
        FinanceAmount(value: d.actualCash ?? '—'),
        Text(
          d.difference ?? '—',
          style: FinanceText.body.copyWith(
            fontWeight: FontWeight.w700,
            color: balanced ? FinanceColors.success : FinanceColors.danger,
          ),
        ),
        Container(
          alignment: AlignmentDirectional.centerStart,
          child: FinanceStatusBadgeCustom(
            label: dailyClosingReadinessLabel(state),
            tone: dailyClosingReadinessTone(state),
          ),
        ),
        Container(
          alignment: AlignmentDirectional.centerStart,
          child: FinanceStatusBadgeCustom(
            label: d.status == 'closed' ? 'مغلق' : 'غير مغلق',
            tone: d.status == 'closed' ? FinanceTone.success : FinanceTone.neutral,
          ),
        ),
        Text(d.closedAt ?? '—', style: FinanceText.body),
      ];
    }).toList(),
  );

  bool _isZero(String value) => (double.tryParse(value.replaceAll(',', '')) ?? 0).abs() < 0.005;
}

class _OpenDayDialog extends StatefulWidget {
  const _OpenDayDialog({required this.repository, required this.branches});
  final FinanceSetupRepository repository;
  final List<Branch> branches;

  @override
  State<_OpenDayDialog> createState() => _OpenDayDialogState();
}

class _OpenDayDialogState extends State<_OpenDayDialog> {
  int? _branchId;
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _branchId = widget.branches.isEmpty ? null : widget.branches.first.id;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked.toIso8601String().substring(0, 10));
  }

  Future<void> _submit() async {
    if (_branchId == null) {
      setState(() => _error = 'اختر فرعاً.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final DailyClosingDetail detail = await widget.repository.getDailyClosingPreview(
        branchId: _branchId!,
        date: _date,
      );
      if (mounted) Navigator.of(context).pop(detail);
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
    title: 'فتح إغلاق يوم',
    actions: <Widget>[
      TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
      ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
        child: _submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('فتح'),
      ),
    ],
    child: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<int?>(
            initialValue: _branchId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الفرع'),
            items: widget.branches
                .map((Branch b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (int? v) => setState(() => _branchId = v),
          ),
          const SizedBox(height: FinanceSpace.md),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(decoration: const InputDecoration(labelText: 'التاريخ'), child: Text(_date)),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: FinanceSpace.sm),
            Text(_error!, style: const TextStyle(color: FinanceColors.danger)),
          ],
        ],
      ),
    ),
  );
}
