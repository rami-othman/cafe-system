import 'package:flutter/material.dart';

import '../../../core/services/service_locator.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../finance_inventory_setup/repositories/finance_setup_repository.dart';
import '../../finance_inventory_setup/widgets/cash_source_field.dart';
import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../models/purchasing_models.dart';
import 'purchase_error_messages.dart';

/// دفع للمورد من داخل فاتورة الشراء: الدفعة تُخصَّص لهذه الفاتورة وحدها
/// (جزئية أو كاملة)، وتستخدم نفس مسار دفعات الموردين في النظام.
/// يعيد true عند نجاح الدفع.
Future<bool?> showPurchasePaymentDialog(
  BuildContext context, {
  required PurchaseInvoice purchase,
}) => showDialog<bool>(
  context: context,
  builder: (BuildContext dialog) => _PurchasePaymentDialog(purchase: purchase),
);

class _PurchasePaymentDialog extends StatefulWidget {
  const _PurchasePaymentDialog({required this.purchase});
  final PurchaseInvoice purchase;

  @override
  State<_PurchasePaymentDialog> createState() => _PurchasePaymentDialogState();
}

class _PurchasePaymentDialogState extends State<_PurchasePaymentDialog> {
  final FinanceSetupRepository _repository = serviceLocator<FinanceSetupRepository>();
  late final TextEditingController _amount = TextEditingController(
    text: _clean(widget.purchase.remainingAmount),
  );
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  List<PaymentMethodSetting> _methods = const <PaymentMethodSetting>[];
  int? _methodId;
  CashSourceOptions? _cashOptions;
  int? _cashLocationId;
  bool _loading = true;
  bool _loadingCash = false;
  bool _submitting = false;
  String? _error;
  String _date = DateTime.now().toIso8601String().substring(0, 10);

  static String _clean(String v) => v.replaceAll(',', '');
  double get _remaining => double.tryParse(_clean(widget.purchase.remainingAmount)) ?? 0;
  double get _entered => double.tryParse(_amount.text.trim()) ?? 0;

  PaymentMethodSetting? get _method =>
      _methods.where((PaymentMethodSetting m) => m.id == _methodId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<PaymentMethodSetting> all = await _repository.getPaymentMethods();
      // طرق الدفع الصالحة لخروج المال: نقد (من صندوق) أو طريقة مربوطة بحساب/صندوق ثابت (بنك، شام كاش).
      final List<PaymentMethodSetting> methods = all
          .where((PaymentMethodSetting m) =>
              m.isActive && m.type != 'wallet' && (m.type == 'cash' || m.financialLocationId != null))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _methodId = methods.isEmpty ? null : methods.first.id;
        _loading = false;
      });
      await _loadCash();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = purchaseLineErrorMessage(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCash() async {
    final int? branchId = widget.purchase.branchId;
    if (_method?.type != 'cash' || branchId == null) return;
    setState(() => _loadingCash = true);
    try {
      final CashSourceOptions options = await _repository.getCashSourceOptions(branchId);
      if (!mounted) return;
      setState(() {
        _cashOptions = options;
        _cashLocationId = options.mode == 'selectable' && options.allowed.length == 1
            ? options.allowed.first.id
            : null;
        _loadingCash = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = purchaseLineErrorMessage(error);
          _loadingCash = false;
        });
      }
    }
  }

  int? get _locationId {
    final PaymentMethodSetting? m = _method;
    if (m == null) return null;
    return m.type == 'cash' ? _cashLocationId : m.financialLocationId;
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
    final PaymentMethodSetting? method = _method;
    if (method == null) {
      setState(() => _error = 'اختر طريقة دفع.');
      return;
    }
    if (widget.purchase.branchId == null) {
      setState(() => _error = 'الفاتورة غير مرتبطة بفرع، لا يمكن الدفع منها.');
      return;
    }
    if (method.type == 'cash' && !cashSourceIsResolved(_cashOptions, _cashLocationId)) {
      setState(() => _error = 'اختر الصندوق الذي سيُدفع منه.');
      return;
    }
    // A cashier (shift mode) pays cash from the open shift's drawer: the server picks it, no id is sent.
    final bool shiftCash = method.type == 'cash' && _cashOptions?.mode == 'shift';
    if (_locationId == null && !shiftCash) {
      setState(() => _error = 'طريقة الدفع غير مربوطة بحساب أو صندوق.');
      return;
    }
    if (_entered <= 0) {
      setState(() => _error = 'أدخل مبلغًا أكبر من صفر.');
      return;
    }
    if (_entered > _remaining + 0.0001) {
      setState(() => _error = 'المبلغ أكبر من المتبقي على الفاتورة (${_remaining.toStringAsFixed(2)}).');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repository.paySupplierInvoices(<String, dynamic>{
        'supplierId': widget.purchase.supplierId,
        'branchId': widget.purchase.branchId,
        'paymentDate': _date,
        'amount': _entered.toStringAsFixed(2),
        'paymentMethodId': method.id,
        'financialLocationId': _locationId,
        if (_reference.text.trim().isNotEmpty) 'externalReference': _reference.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'idempotencyKey': 'purchase-pay-${widget.purchase.id}-${DateTime.now().microsecondsSinceEpoch}',
        'allocations': <Map<String, dynamic>>[
          <String, dynamic>{'invoiceId': widget.purchase.id, 'amount': _entered.toStringAsFixed(2)},
        ],
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = purchaseLineErrorMessage(error);
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final PurchaseInvoice p = widget.purchase;
    final double after = (_remaining - _entered).clamp(0, double.infinity).toDouble();
    return FinanceDialogShell(
      title: 'دفع للمورد — ${p.invoiceNumber}',
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        const SizedBox(width: FinanceSpace.sm),
        ElevatedButton(
          onPressed: _submitting || _loading || _methods.isEmpty ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('تسجيل الدفعة'),
        ),
      ],
      child: _loading
          ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('المورد: ${p.supplierName}', style: FinanceText.body),
                  const SizedBox(height: FinanceSpace.xs),
                  Text(
                    'الإجمالي ${p.totalAmount} · المدفوع ${p.paidAmount} · المتبقي ${p.remainingAmount} SYP',
                    style: FinanceText.small,
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'المبلغ المدفوع الآن',
                      helperText: 'المتبقي بعد هذه الدفعة: ${after.toStringAsFixed(2)} SYP',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  if (_methods.isEmpty)
                    const Text('لا توجد طرق دفع مفعّلة صالحة للدفع للمورد.', style: FinanceText.small)
                  else
                    DropdownButtonFormField<int>(
                      initialValue: _methodId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'طريقة الدفع / الصندوق'),
                      items: _methods
                          .map((PaymentMethodSetting m) => DropdownMenuItem<int>(
                                value: m.id,
                                child: Text(m.name, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(growable: false),
                      onChanged: (int? v) {
                        setState(() {
                          _methodId = v;
                          _cashOptions = null;
                          _cashLocationId = null;
                        });
                        _loadCash();
                      },
                    ),
                  if (_method != null && _method!.type != 'cash') ...<Widget>[
                    const SizedBox(height: FinanceSpace.xs),
                    Text('يُدفع من: ${_method!.financialLocationName ?? 'حساب الطريقة'}', style: FinanceText.small),
                  ],
                  if (_method?.type == 'cash') ...<Widget>[
                    const SizedBox(height: FinanceSpace.sm),
                    if (_loadingCash)
                      const LinearProgressIndicator()
                    else
                      CashSourceField(
                        options: _cashOptions,
                        selectedLocationId: _cashLocationId,
                        onChanged: (int? v) => setState(() => _cashLocationId = v),
                      ),
                  ],
                  const SizedBox(height: FinanceSpace.md),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event, size: 16),
                    label: Text('تاريخ الدفع: $_date'),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  TextField(
                    controller: _reference,
                    decoration: const InputDecoration(labelText: 'رقم المرجع (اختياري)'),
                  ),
                  const SizedBox(height: FinanceSpace.sm),
                  TextField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: FinanceSpace.md),
                    Text(_error!, style: const TextStyle(color: FinanceColors.danger)),
                  ],
                ],
              ),
            ),
    );
  }
}
