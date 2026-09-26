import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/manufacturing_production_cubit.dart';
import '../controllers/manufacturing_production_state.dart';
import '../models/manufacturing_production_models.dart';

/// Completion step: `POST production/drafts/{id}/complete`. Supports the
/// Actual output, consumption, waste and simple managerial operating costs.
class ManufacturingProductionCompleteScreen extends StatefulWidget {
  const ManufacturingProductionCompleteScreen({
    super.key,
    required this.draftId,
  });
  final int draftId;

  @override
  State<ManufacturingProductionCompleteScreen> createState() =>
      _ManufacturingProductionCompleteScreenState();
}

class _ManufacturingProductionCompleteScreenState
    extends State<ManufacturingProductionCompleteScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _costs = {
    'أجور': TextEditingController(),
    'كهرباء': TextEditingController(),
    'أخرى': TextEditingController(),
  };
  final TextEditingController _actualQty = TextEditingController();
  final TextEditingController _wasteQty = TextEditingController();
  final TextEditingController _wasteNotes = TextEditingController();
  final Map<int, TextEditingController> _actualConsumption =
      <int, TextEditingController>{};
  String? _wasteReason;
  bool _hydrated = false;

  static const List<String> _wasteReasons = <String>[
    'احتراق',
    'كسر',
    'انسكاب',
    'خطأ تحضير',
    'تجربة',
    'جودة غير مطابقة',
    'آخر',
  ];

  @override
  void initState() {
    super.initState();
    final ManufacturingProductionCubit cubit = context
        .read<ManufacturingProductionCubit>();
    Future<void>.microtask(() => cubit.loadDraft(widget.draftId));
  }

  @override
  void dispose() {
    _actualQty.dispose();
    _wasteQty.dispose();
    _wasteNotes.dispose();
    for (final controller in _costs.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in _actualConsumption.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _hydrate(ManufacturingProductionDraft draft) {
    if (_hydrated) return;
    _hydrated = true;
    _actualQty.text = draft.qty;
    for (final ManufacturingDraftConsumptionLine line in draft.consumption) {
      _actualConsumption[line.materialId] = TextEditingController(
        text: line.actual,
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ManufacturingProductionCubit, ManufacturingProductionState>(
        builder: (BuildContext context, ManufacturingProductionState state) {
          final ManufacturingProductionDraft? draft =
              state.draft?.id == widget.draftId ? state.draft : null;
          if (draft != null) _hydrate(draft);

          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const ManagementPageHeader(
                  title: 'إتمام الإنتاج',
                  subtitle: 'أدخل الكمية الفعلية المنتجة وأي هدر مسجل.',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (state.loading && draft == null)
                  const Padding(padding: AppSpacing.allXxl, child: AppLoading())
                else if (state.error != null && draft == null)
                  ManagementMessage(message: state.error!, error: true)
                else if (draft == null)
                  const ManagementMessage(message: 'المسودة غير موجودة.')
                else
                  _buildForm(context, draft, state),
              ],
            ),
          );
        },
      );

  Widget _buildForm(
    BuildContext context,
    ManufacturingProductionDraft draft,
    ManufacturingProductionState state,
  ) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ManagementMessage(message: state.error!, error: true),
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _actualQty,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) => _quantityError(value, positive: true),
                decoration: InputDecoration(
                  labelText: 'الكمية الصالحة المنتجة (${draft.unit})',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'الاستهلاك الفعلي (اختياري - يستخدم المخطط افتراضياً)',
              ),
              const SizedBox(height: AppSpacing.sm),
              ...draft.consumption.map(
                (ManufacturingDraftConsumptionLine line) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TextFormField(
                    controller: _actualConsumption.putIfAbsent(
                      line.materialId,
                      () => TextEditingController(text: line.planned),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          '${line.name.isEmpty ? 'مادة #${line.materialId}' : line.name} (${line.unit}) — مخطط ${line.planned}',
                    ),
                    validator: (value) => _quantityError(value),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('الهدر (اختياري)'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _wasteQty,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) => _quantityError(value),
                      decoration: InputDecoration(
                        labelText: 'كمية الهدر (${draft.unit})',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _wasteReason,
                      decoration: const InputDecoration(labelText: 'السبب'),
                      items: _wasteReasons
                          .map(
                            (String reason) => DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) =>
                          setState(() => _wasteReason = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _wasteNotes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات الهدر'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تكاليف التشغيل (اختيارية)'),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'تُضاف إلى التكلفة الكاملة للمتابعة. تكلفة المخزون تعتمد على المواد المستهلكة؛ تسجيل الأجور هنا لا ينشئ دفعة أو مصروفاً مالياً.',
              ),
              const SizedBox(height: AppSpacing.md),
              ..._costs.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TextFormField(
                    controller: entry.value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: entry.key),
                    validator: (value) =>
                        value == null ||
                            value.trim().isEmpty ||
                            RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value.trim())
                        ? null
                        : 'أدخل مبلغاً موجباً بدقتين عشريتين كحد أقصى.',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: state.submitting ? 'جارٍ الإتمام...' : 'إتمام الإنتاج',
          icon: Icons.check_circle_outline,
          onPressed: state.submitting ? null : () => _complete(context, draft),
        ),
      ],
    ),
  );

  String? _quantityError(String? value, {bool positive = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty && !positive) return null;
    if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(text) ||
        (positive && (double.tryParse(text) ?? 0) <= 0)) {
      return 'أدخل كمية ${positive ? 'أكبر من صفر' : 'غير سالبة'} بثلاث خانات عشرية كحد أقصى.';
    }
    return null;
  }

  Future<void> _complete(
    BuildContext context,
    ManufacturingProductionDraft draft,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ManufacturingProductionCubit cubit = context
        .read<ManufacturingProductionCubit>();
    final List<Map<String, dynamic>> consumption = _actualConsumption.entries
        .map(
          (MapEntry<int, TextEditingController> entry) => <String, dynamic>{
            'materialId': entry.key,
            if (entry.value.text.trim().isNotEmpty)
              'actual': entry.value.text.trim(),
          },
        )
        .toList(growable: false);
    final Map<String, dynamic>? waste = _wasteQty.text.trim().isEmpty
        ? null
        : <String, dynamic>{
            'qty': _wasteQty.text.trim(),
            if (_wasteReason != null) 'reason': _wasteReason,
            if (_wasteNotes.text.trim().isNotEmpty)
              'notes': _wasteNotes.text.trim(),
          };
    final bool ok = await cubit.completeDraft(
      draftId: draft.id,
      actualQty: _actualQty.text.trim(),
      consumption: consumption,
      waste: waste,
      additionalCosts: _costs.entries
          .where((entry) => (double.tryParse(entry.value.text.trim()) ?? 0) > 0)
          .map(
            (entry) => <String, dynamic>{
              'type': entry.key,
              'amount': entry.value.text.trim(),
            },
          )
          .toList(growable: false),
    );
    if (!context.mounted) return;
    if (ok && cubit.state.result != null) {
      context.go(
        AppRoutes.manufacturingProductionResultPath(cubit.state.result!.id),
      );
    }
  }
}
