import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
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

/// Renders the exact response fields `ManufacturingProductionService::get()`
/// returns for a completed order - never a client-derived number.
class ManufacturingProductionResultScreen extends StatefulWidget {
  const ManufacturingProductionResultScreen({
    super.key,
    required this.idOrReference,
  });
  final String idOrReference;

  @override
  State<ManufacturingProductionResultScreen> createState() =>
      _ManufacturingProductionResultScreenState();
}

class _ManufacturingProductionResultScreenState
    extends State<ManufacturingProductionResultScreen> {
  @override
  void initState() {
    super.initState();
    final ManufacturingProductionCubit cubit = context
        .read<ManufacturingProductionCubit>();
    final ManufacturingProductionOrder? cached = cubit.state.result;
    if (cached == null || cached.id != widget.idOrReference) {
      Future<void>.microtask(() => cubit.loadOrder(widget.idOrReference));
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ManufacturingProductionCubit, ManufacturingProductionState>(
        builder: (BuildContext context, ManufacturingProductionState state) {
          final ManufacturingProductionOrder? order =
              (state.result?.id == widget.idOrReference)
              ? state.result
              : (state.selected?.id == widget.idOrReference
                    ? state.selected
                    : null);

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
                  title: 'تم إتمام الإنتاج',
                  subtitle: 'ملخص عملية الإنتاج المكتملة.',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (state.loading && order == null)
                  const Padding(padding: AppSpacing.allXxl, child: AppLoading())
                else if (order == null)
                  ManagementMessage(
                    message: state.error ?? 'تعذر تحميل نتيجة الإنتاج.',
                    error: true,
                  )
                else
                  _ResultBody(order: order),
              ],
            ),
          );
        },
      );
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.order});
  final ManufacturingProductionOrder order;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(order.product, style: AppTextStyles.titleLarge),
                Text(order.id, style: AppTextStyles.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                _StatRow(
                  label: 'الكمية الفعلية',
                  value: '${order.actual ?? '—'} ${order.unit}',
                ),
                _StatRow(
                  label: 'التكلفة الفعلية',
                  value: order.actualCost ?? '—',
                ),
                _StatRow(label: 'التاريخ', value: order.date ?? '—'),
                if (order.recipeVersion != null)
                  _StatRow(label: 'إصدار الوصفة', value: order.recipeVersion!),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      ManufacturingCostSummary(order: order),
      const SizedBox(height: AppSpacing.lg),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('المواد المستهلكة', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
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
      if (order.waste != null) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline, color: AppColors.warning),
            title: Text('هدر: ${order.waste!.qty} ${order.waste!.unit}'),
            subtitle: Text(order.waste!.reason ?? ''),
          ),
        ),
      ],
      if (order.batch != null) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('الدفعة والصلاحية', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text('المرجع: ${order.batch!.ref ?? '—'}'),
              Text('تاريخ الإنتاج: ${order.batch!.mfgDate ?? '—'}'),
              Text('الصلاحية: ${order.batch!.shelfLife ?? '—'}'),
              Text('تاريخ الانتهاء: ${order.batch!.expiry ?? '—'}'),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      AppButton(
        label: 'عرض سجل الإنتاج',
        icon: Icons.list_alt_outlined,
        onPressed: () => context.go(AppRoutes.manufacturingProduction),
      ),
    ],
  );
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
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
