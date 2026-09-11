import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_components.dart';

class InvoiceTypeCatalogScreen extends StatefulWidget {
  const InvoiceTypeCatalogScreen({super.key});

  @override
  State<InvoiceTypeCatalogScreen> createState() => _InvoiceTypeCatalogScreenState();
}

class _InvoiceTypeCatalogScreenState extends State<InvoiceTypeCatalogScreen> {
  List<Map<String, dynamic>> _groups = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _types = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  FinanceSetupRepository get _repository =>
      context.read<FinanceSetupCubit>().repository;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getFinanceList('finance/invoice-groups'),
        _repository.getFinanceList('finance/invoice-types'),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = results[0] as List<Map<String, dynamic>>;
        _types = results[1] as List<Map<String, dynamic>>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      FinancePageHeader(
        title: 'مجموعات وأنواع الفواتير',
        subtitle: 'أنشئ مجموعة، ثم أضف إليها أنواع الفواتير التي تريد إتاحتها للمستخدمين.',
        actions: <Widget>[
          AppButton(label: 'مجموعة جديدة', icon: Icons.create_new_folder_outlined, onPressed: _showGroupForm),
          AppButton(label: 'نوع فاتورة جديد', icon: Icons.add, variant: AppButtonVariant.outlined, onPressed: _groups.isEmpty ? null : _showTypeForm),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ManagementMessage(message: _error!, error: true, onRetry: _load)
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('المجموعات', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: _groups.map((Map<String, dynamic> group) => _GroupCard(group: group)).toList(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text('الأنواع المتاحة في فاتورة المورد', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        if (_types.isEmpty)
                          const ManagementMessage(message: 'أنشئ مجموعة ثم أضف نوع فاتورة إليها.')
                        else
                          ManagementTableShell(
                            minWidth: 700,
                            child: DataTable(
                              columns: const <DataColumn>[
                                DataColumn(label: Text('المجموعة')),
                                DataColumn(label: Text('النوع')),
                                DataColumn(label: Text('السلوك المحاسبي')),
                                DataColumn(label: Text('الترحيل')),
                                DataColumn(label: Text('الحالة')),
                              ],
                              rows: _types.map((Map<String, dynamic> type) => DataRow(cells: <DataCell>[
                                DataCell(Text('${type['groupName'] ?? ''}')),
                                DataCell(Text('${type['name'] ?? ''}')),
                                DataCell(Text(_behaviorLabel('${type['postingBehavior'] ?? ''}'))),
                                DataCell(Text(type['isPostable'] == true ? 'قابل للترحيل' : 'تجريبي فقط')),
                                DataCell(Text(type['isActive'] == true ? 'نشط' : 'غير نشط')),
                              ])).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    ],
  );

  Future<void> _showGroupForm() async {
    final TextEditingController code = TextEditingController();
    final TextEditingController name = TextEditingController();
    final TextEditingController description = TextEditingController();
    String? error;
    await showDialog<void>(context: context, builder: (BuildContext dialog) => StatefulBuilder(builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
      title: const Text('مجموعة فواتير جديدة'),
      content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        TextField(controller: code, decoration: const InputDecoration(labelText: 'الرمز الإنجليزي (مثال: test)'),),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المجموعة'),),
        TextField(controller: description, decoration: const InputDecoration(labelText: 'وصف اختياري'),),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      ])),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          if (code.text.trim().isEmpty || name.text.trim().isEmpty) { setDialogState(() => error = 'أدخل الرمز والاسم.'); return; }
          try { await _repository.createInvoiceGroup(<String, dynamic>{'code': code.text.trim().toLowerCase(), 'name': name.text.trim(), 'description': description.text.trim().isEmpty ? null : description.text.trim()}); if (context.mounted) Navigator.pop(dialog); await _load(); } catch (e) { setDialogState(() => error = '$e'); }
        }, child: const Text('إنشاء')),
      ],
    )));
    code.dispose(); name.dispose(); description.dispose();
  }

  Future<void> _showTypeForm() async {
    final TextEditingController code = TextEditingController();
    final TextEditingController name = TextEditingController();
    int groupId = (_groups.first['id'] as num).toInt();
    String behavior = 'other';
    bool postable = true;
    String? error;
    await showDialog<void>(context: context, builder: (BuildContext dialog) => StatefulBuilder(builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
      title: const Text('نوع فاتورة جديد'),
      content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        DropdownButtonFormField<int>(value: groupId, isExpanded: true, decoration: const InputDecoration(labelText: 'المجموعة'), items: _groups.map((g) => DropdownMenuItem<int>(value: (g['id'] as num).toInt(), child: Text('${g['name']}'))).toList(), onChanged: (v) => setDialogState(() => groupId = v!)),
        TextField(controller: code, decoration: const InputDecoration(labelText: 'الرمز الإنجليزي (مثال: supplier-service)'),),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم النوع'),),
        DropdownButtonFormField<String>(value: behavior, decoration: const InputDecoration(labelText: 'السلوك المحاسبي'), items: const <DropdownMenuItem<String>>[
          DropdownMenuItem(value: 'expense', child: Text('مصروف — يطلب فئة مصروف')),
          DropdownMenuItem(value: 'inventory', child: Text('مخزون — حساب المخزون')),
          DropdownMenuItem(value: 'other', child: Text('أخرى — يطلب الحساب المدين')),
          DropdownMenuItem(value: 'none', child: Text('تجريبي / غير مالي')),
        ], onChanged: (v) => setDialogState(() { behavior = v!; if (behavior == 'none') postable = false; })),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: postable, title: const Text('قابل للترحيل المحاسبي'), onChanged: behavior == 'none' ? null : (v) => setDialogState(() => postable = v)),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      ])),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          if (code.text.trim().isEmpty || name.text.trim().isEmpty) { setDialogState(() => error = 'أدخل الرمز والاسم.'); return; }
          try { await _repository.createInvoiceType(<String, dynamic>{'groupId': groupId, 'code': code.text.trim().toLowerCase(), 'name': name.text.trim(), 'postingBehavior': behavior, 'isPostable': postable}); if (context.mounted) Navigator.pop(dialog); await _load(); } catch (e) { setDialogState(() => error = '$e'); }
        }, child: const Text('إنشاء')),
      ],
    )));
    code.dispose(); name.dispose();
  }

  String _behaviorLabel(String behavior) => <String, String>{'expense': 'مصروف', 'inventory': 'مخزون', 'other': 'حساب مدين مختار', 'none': 'تجريبي / غير مالي'}[behavior] ?? behavior;
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final Map<String, dynamic> group;
  @override
  Widget build(BuildContext context) => SizedBox(width: 260, child: Card(child: Padding(padding: AppSpacing.allMd, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Text('${group['name'] ?? ''}', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 4), Text('${group['code'] ?? ''}'),
    if ('${group['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${group['description']}')),
  ]))));
}
