import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../widgets/finance_paginated_table.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Supplier> _suppliers = const [];
  SetupStatus? _status;
  bool _loading = true;
  String? _error;
  String? _statusFilter;
  String _search = '';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceSetupCubit>().repository;
      final data = await Future.wait([
        repo.getSuppliers(
          filters: <String, dynamic>{
            if (_statusFilter != null) 'status': _statusFilter,
            if (_search.isNotEmpty) 'search': _search,
          },
        ),
        repo.getSetupStatus(),
      ]);
      if (mounted) {
        setState(() {
          _suppliers = data[0] as List<Supplier>;
          _status = data[1] as SetupStatus;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ManagementPageHeader(
          title: 'الموردون والمستحقات',
          subtitle: 'رصيد المورد مستمد من الفواتير والدفعات المُرحّلة فقط.',
          actions: <Widget>[
            AppButton(label: 'إضافة مورد', icon: Icons.add, onPressed: _edit),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_status != null) ...<Widget>[
          _kpis(_status!),
          const SizedBox(height: AppSpacing.lg),
        ],
        ManagementFilterBar(
          children: <Widget>[
            SizedBox(
              width: 220,
              child: TextField(
                onChanged: (v) => _search = v,
                onSubmitted: (_) => _load(),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'اسم المورد أو الرمز',
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String?>(
                initialValue: _statusFilter,
                isExpanded: true,
                hint: const Text('كل الحالات'),
                items: const <DropdownMenuItem<String?>>[
                  DropdownMenuItem(value: null, child: Text('كل الحالات')),
                  DropdownMenuItem(value: 'active', child: Text('نشط')),
                  DropdownMenuItem(value: 'inactive', child: Text('غير نشط')),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v);
                  _load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ManagementMessage(message: _error!, error: true, onRetry: _load)
              : _suppliers.isEmpty
              ? ManagementMessage(
                  message: 'لا يوجد موردون مسجلون بعد.',
                  onRetry: _load,
                )
              : ManagementTableShell(
                  minWidth: 1100,
                  child: FinancePaginatedTable(
                    minWidth: 1100,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('رمز المورد')),
                      DataColumn(label: Text('الاسم')),
                      DataColumn(label: Text('إجمالي المستحق')),
                      DataColumn(label: Text('المتأخر')),
                      DataColumn(label: Text('فواتير مفتوحة')),
                      DataColumn(label: Text('آخر نشاط')),
                      DataColumn(label: Text('الحالة')),
                      DataColumn(label: Text('إجراء')),
                    ],
                    rows: _suppliers
                        .map(
                          (x) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(x.supplierNumber)),
                              DataCell(Text(x.name)),
                              DataCell(Text(x.outstandingBalance)),
                              DataCell(
                                Text(
                                  x.overdueBalance,
                                  style: TextStyle(
                                    color: x.overdueBalance != '0.00'
                                        ? Colors.red
                                        : null,
                                  ),
                                ),
                              ),
                              DataCell(Text('${x.openInvoiceCount}')),
                              DataCell(Text(x.lastInvoiceDate ?? '—')),
                              DataCell(
                                ManagementBadge(
                                  label: x.isActive ? 'نشط' : 'غير نشط',
                                  tone: x.isActive
                                      ? ManagementTone.success
                                      : ManagementTone.neutral,
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: 'عرض',
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      onPressed: () => context.go(
                                        '${AppRoutes.financeSuppliers}/${x.id}',
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'تعديل',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _edit(existing: x),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _kpis(SetupStatus status) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 4,
    mainAxisSpacing: AppSpacing.md,
    crossAxisSpacing: AppSpacing.md,
    childAspectRatio: 2.6,
    children: <Widget>[
      ManagementKpiCard(
        label: 'إجمالي المستحقات',
        value: status.totalPayables,
        icon: Icons.account_balance_wallet_outlined,
      ),
      ManagementKpiCard(
        label: 'مستحقات متأخرة',
        value: status.overduePayables,
        icon: Icons.warning_amber_outlined,
      ),
      ManagementKpiCard(
        label: 'فواتير موردين مفتوحة',
        value: '${status.openSupplierInvoiceCount}',
        icon: Icons.receipt_long_outlined,
      ),
      ManagementKpiCard(
        label: 'موردون نشطون',
        value: '${status.activeSupplierCount}',
        icon: Icons.storefront_outlined,
      ),
    ],
  );

  Future<void> _edit({Supplier? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final contact = TextEditingController(text: existing?.contactPerson ?? '');
    final taxNumber = TextEditingController(text: existing?.taxNumber ?? '');
    final terms = TextEditingController(
      text: '${existing?.paymentTermsDays ?? 0}',
    );
    final notes = TextEditingController(text: existing?.notes ?? '');
    String? error;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(existing == null ? 'إضافة مورد' : 'تعديل مورد'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                  ),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'الهاتف'),
                  ),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                    ),
                  ),
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  TextField(
                    controller: contact,
                    decoration: const InputDecoration(labelText: 'جهة الاتصال'),
                  ),
                  TextField(
                    controller: taxNumber,
                    decoration: const InputDecoration(
                      labelText: 'الرقم الضريبي',
                    ),
                  ),
                  TextField(
                    controller: terms,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مهلة السداد (أيام)',
                    ),
                  ),
                  TextField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('إلغاء'),
            ),
            AppButton(
              label: 'حفظ',
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  set(() => error = 'أدخل اسم المورد.');
                  return;
                }
                try {
                  await context
                      .read<FinanceSetupCubit>()
                      .repository
                      .saveSupplier(<String, dynamic>{
                        'name': name.text.trim(),
                        'phone': phone.text.trim().isEmpty
                            ? null
                            : phone.text.trim(),
                        'email': email.text.trim().isEmpty
                            ? null
                            : email.text.trim(),
                        'address': address.text.trim().isEmpty
                            ? null
                            : address.text.trim(),
                        'contactPerson': contact.text.trim().isEmpty
                            ? null
                            : contact.text.trim(),
                        'taxNumber': taxNumber.text.trim().isEmpty
                            ? null
                            : taxNumber.text.trim(),
                        'paymentTermsDays':
                            int.tryParse(terms.text.trim()) ?? 0,
                        'notes': notes.text.trim().isEmpty
                            ? null
                            : notes.text.trim(),
                      }, id: existing?.id);
                  if (d.mounted) Navigator.pop(d);
                  await _load();
                } catch (e) {
                  if (d.mounted) set(() => error = e.toString());
                }
              },
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    contact.dispose();
    taxNumber.dispose();
    terms.dispose();
    notes.dispose();
  }
}
