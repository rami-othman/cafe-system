import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/manufacturing_production_cubit.dart';
import '../controllers/manufacturing_production_state.dart';
import '../models/manufacturing_production_models.dart';
import '../widgets/manufacturing_cost_summary.dart';

/// Production order detail + reversal. Reversibility is entirely
/// backend-decided: a reversal attempt is submitted as-is, and a
/// `PRODUCTION_NOT_REVERSIBLE` (or any other domain) conflict is shown using
/// the Arabic message the backend already returns
/// (`DomainErrorMessages::forCode()`) - this screen never guesses locally
/// whether an order "looks reversible" before the backend confirms, and never
/// mutates the displayed order optimistically on a failed attempt.
class ManufacturingProductionDetailsScreen extends StatefulWidget {
  const ManufacturingProductionDetailsScreen({
    super.key,
    required this.idOrReference,
  });
  final String idOrReference;

  @override
  State<ManufacturingProductionDetailsScreen> createState() =>
      _ManufacturingProductionDetailsScreenState();
}

class _ManufacturingProductionDetailsScreenState
    extends State<ManufacturingProductionDetailsScreen> {
  @override
  void initState() {
    super.initState();
    final ManufacturingProductionCubit cubit = context
        .read<ManufacturingProductionCubit>();
    Future<void>.microtask(() => cubit.loadOrder(widget.idOrReference));
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ManufacturingProductionCubit, ManufacturingProductionState>(
    builder: (BuildContext context, ManufacturingProductionState state) {
      final ManufacturingProductionOrder? order =
          state.selected?.id == widget.idOrReference ? state.selected : null;
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
            ManagementPageHeader(
              title: order?.product ?? 'تفاصيل الإنتاج',
              subtitle: order == null ? '' : order.id,
              actions: order == null || !order.isCompleted
                  ? const <Widget>[]
                  : <Widget>[
                      AppButton(
                        label: 'عكس العملية',
                        variant: AppButtonVariant.danger,
                        icon: Icons.undo_outlined,
                        onPressed: state.submitting
                            ? null
                            : () => _reverse(context, order),
                      ),
                    ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ManagementMessage(message: state.error!, error: true),
              ),
            if (state.loading && order == null)
              const Padding(padding: AppSpacing.allXxl, child: AppLoading())
            else if (order == null)
              const ManagementMessage(message: 'عملية الإنتاج غير موجودة.')
            else
              _DetailsBody(order: order),
          ],
        ),
      );
    },
  );

  Future<void> _reverse(
    BuildContext context,
    ManufacturingProductionOrder order,
  ) async {
    final TextEditingController reasonController = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('عكس عملية الإنتاج'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'سبب العكس'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'تأكيد العكس',
            variant: AppButtonVariant.danger,
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
          ),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty || !context.mounted) return;
    final ManufacturingProductionCubit cubit = context
        .read<ManufacturingProductionCubit>();
    await cubit.reverseOrder(idOrReference: order.id, reason: reason.trim());
    if (!context.mounted) return;
    if (cubit.state.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cubit.state.error!)));
    }
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.order});
  final ManufacturingProductionOrder order;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      AppCard(
        child: Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            _Stat(label: 'الحالة', value: _statusLabel(order.status)),
            _Stat(label: 'المخطط', value: '${order.planned} ${order.unit}'),
            _Stat(
              label: 'الفعلي',
              value: order.actual == null
                  ? '—'
                  : '${order.actual} ${order.unit}',
            ),
            _Stat(label: 'التكلفة المخططة', value: order.plannedCost ?? '—'),
            _Stat(label: 'التكلفة الفعلية', value: order.actualCost ?? '—'),
            _Stat(label: 'إصدار الوصفة', value: order.recipeVersion ?? '—'),
            _Stat(label: 'التاريخ', value: order.date ?? '—'),
            if (order.user != null)
              _Stat(label: 'المستخدم', value: order.user!),
          ],
        ),
      ),
      if (order.isReversed && order.reverseReason != null) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Row(
            children: <Widget>[
              const Icon(Icons.undo_outlined, color: AppColors.danger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('سبب العكس: ${order.reverseReason}')),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      if (order.actualCost != null) ...[
        ManufacturingCostSummary(order: order),
        const SizedBox(height: AppSpacing.lg),
      ],
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('المواد المستهلكة', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (order.materialsConsumed.isEmpty)
              const ManagementMessage(message: 'لا يوجد استهلاك مسجل.')
            else
              ...order.materialsConsumed.map(
                (ManufacturingOrderConsumedLine line) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(line.name),
                  subtitle: Text('مخطط ${line.planned} ${line.unit}'),
                  trailing: Text(
                    line.actual == null ? '—' : '${line.actual} ${line.unit}',
                  ),
                ),
              ),
          ],
        ),
      ),
      if (order.batch != null) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('الدفعة والصلاحية', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text('المرجع: ${order.batch!.ref ?? '—'}'),
              Text('تاريخ الانتهاء: ${order.batch!.expiry ?? '—'}'),
            ],
          ),
        ),
      ],
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
      ),
      Text(value, style: AppTextStyles.labelLarge),
    ],
  );
}

String _statusLabel(String status) => switch (status) {
  'completed' => 'مكتمل',
  'draft' => 'مسودة',
  'reversed' => 'ملغي',
  _ => status,
};
