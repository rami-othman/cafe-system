import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/manufacturing_cubit.dart';
import '../controllers/manufacturing_state.dart';
import '../models/manufacturing_models.dart';

/// Phase 1 Manufacturing screen: a read-only overview built from
/// `GET /manufacturing/overview`. Mirrors the information hierarchy of the
/// manufacturing_web reference page (today's production, cost, average
/// yield, waste, low-material attention, expiring batches, recent
/// production, and highest-cost manufactured products) using the app's own
/// widgets rather than that page's HTML/CSS.
class ManufacturingOverviewScreen extends StatefulWidget {
  const ManufacturingOverviewScreen({super.key});

  @override
  State<ManufacturingOverviewScreen> createState() =>
      _ManufacturingOverviewScreenState();
}

class _ManufacturingOverviewScreenState
    extends State<ManufacturingOverviewScreen> {
  @override
  void initState() {
    super.initState();
    final ManufacturingCubit cubit = context.read<ManufacturingCubit>();
    Future<void>.microtask(cubit.loadOverview);
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ManufacturingCubit, ManufacturingState>(
        builder: (BuildContext context, ManufacturingState state) {
          final ManufacturingOverview? overview = state.overview;
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
                  title: 'نظرة عامة',
                  subtitle: 'نظرة عامة على الإنتاج اليومي وتكلفته وتنبيهاته.',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (overview == null)
                  _OverviewLoadState(
                    loading: state.loading,
                    error: state.error,
                    onRetry: () => context.read<ManufacturingCubit>().refresh(),
                  )
                else
                  _OverviewBody(
                    overview: overview,
                    refreshing: state.loading,
                    onRetry: () => context.read<ManufacturingCubit>().refresh(),
                  ),
              ],
            ),
          );
        },
      );
}

class _OverviewLoadState extends StatelessWidget {
  const _OverviewLoadState({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(padding: AppSpacing.allXxl, child: AppLoading());
    }
    if (error != null) {
      return AppCard(
        child: Column(
          children: <Widget>[
            const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    return const AppEmptyState(
      message: 'لا تتوفر بيانات تصنيع حالياً.',
      icon: Icons.precision_manufacturing_outlined,
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.overview,
    required this.refreshing,
    required this.onRetry,
  });

  final ManufacturingOverview overview;
  final bool refreshing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ManufacturingOverviewKpis kpis = overview.kpis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            _KpiCard(
              label: 'الإنتاج اليوم',
              value: kpis.producedToday,
              icon: Icons.factory_outlined,
            ),
            _KpiCard(
              label: 'تكلفة الإنتاج اليوم',
              value: kpis.productionCostToday,
              icon: Icons.payments_outlined,
            ),
            _KpiCard(
              label: 'متوسط الكفاءة',
              value: kpis.avgEfficiency == null
                  ? '—'
                  : '${kpis.avgEfficiency}%',
              icon: Icons.trending_up_outlined,
            ),
            _KpiCard(
              label: 'الهدر اليوم',
              value: '${kpis.wasteToday}',
              icon: Icons.delete_outline,
              tone: kpis.wasteToday > 0 ? AppColors.warning : null,
            ),
            _KpiCard(
              label: 'تنبيهات المواد',
              value: '${kpis.attentionCount}',
              icon: Icons.warning_amber_outlined,
              tone: kpis.attentionCount > 0 ? AppColors.danger : null,
            ),
            _KpiCard(
              label: 'دفعات قاربت الانتهاء',
              value: '${kpis.expiringCount}',
              icon: Icons.schedule_outlined,
              tone: kpis.expiringCount > 0 ? AppColors.warning : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 900;
            final List<Widget> sections = <Widget>[
              _AttentionSection(items: overview.attention),
              _ExpiringSection(items: overview.expiring),
            ];
            if (!wide) {
              return Column(
                children: <Widget>[
                  sections[0],
                  const SizedBox(height: AppSpacing.md),
                  sections[1],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: sections[0]),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: sections[1]),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _RecentProductionSection(orders: overview.recent),
        const SizedBox(height: AppSpacing.md),
        _TopCostSection(items: overview.topCost),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: tone ?? AppColors.primary, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              color: tone ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}

class _AttentionSection extends StatelessWidget {
  const _AttentionSection({required this.items});
  final List<ManufacturingAttentionItem> items;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'مواد تحتاج انتباه',
    child: items.isEmpty
        ? const AppEmptyState(
            message: 'لا توجد تنبيهات مواد حالياً.',
            icon: Icons.check_circle_outline,
          )
        : Column(
            children: items
                .map(
                  (ManufacturingAttentionItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          item.level == 'critical'
                              ? Icons.error_outline
                              : Icons.warning_amber_outlined,
                          size: 18,
                          color: item.level == 'critical'
                              ? AppColors.danger
                              : AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(item.name, style: AppTextStyles.labelLarge),
                              Text(
                                '${item.available} · ${item.need}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          item.status,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: item.level == 'critical'
                                ? AppColors.danger
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
  );
}

class _ExpiringSection extends StatelessWidget {
  const _ExpiringSection({required this.items});
  final List<ManufacturingExpiringBatch> items;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'دفعات قاربت الانتهاء',
    child: items.isEmpty
        ? const AppEmptyState(
            message: 'لا توجد دفعات قاربت على الانتهاء.',
            icon: Icons.inventory_outlined,
          )
        : Column(
            children: items
                .map(
                  (ManufacturingExpiringBatch batch) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.schedule_outlined,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                batch.product,
                                style: AppTextStyles.labelLarge,
                              ),
                              Text(
                                batch.remaining,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (batch.date != null)
                          Text(
                            batch.date!,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
  );
}

class _RecentProductionSection extends StatelessWidget {
  const _RecentProductionSection({required this.orders});
  final List<ManufacturingRecentOrder> orders;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'أحدث عمليات الإنتاج',
    child: orders.isEmpty
        ? const AppEmptyState(
            message: 'لا توجد عمليات إنتاج مسجلة بعد.',
            icon: Icons.receipt_long_outlined,
          )
        : Column(
            children: orders
                .map(
                  (ManufacturingRecentOrder order) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                order.product,
                                style: AppTextStyles.labelLarge,
                              ),
                              Text(
                                '${order.id} · ${_statusLabel(order.status)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (order.actual != null)
                          Text(
                            '${order.actual} ${order.unit}',
                            style: AppTextStyles.labelMedium,
                          ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
  );
}

class _TopCostSection extends StatelessWidget {
  const _TopCostSection({required this.items});
  final List<ManufacturingTopCostProduct> items;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'الأعلى تكلفة تصنيعاً',
    child: items.isEmpty
        ? const AppEmptyState(
            message: 'لا توجد بيانات تكلفة لليوم.',
            icon: Icons.bar_chart_outlined,
          )
        : Column(
            children: items
                .map(
                  (ManufacturingTopCostProduct item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(item.product, style: AppTextStyles.labelLarge),
                            Text(item.cost, style: AppTextStyles.labelMedium),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (item.pct.clamp(0, 100)) / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
  );
}

/// The backend keeps order status strings in English (e.g. `completed`,
/// `draft`); Arabic labels are applied only here, at render time.
String _statusLabel(String status) => switch (status) {
  'completed' => 'مكتمل',
  'draft' => 'مسودة',
  'reversed' => 'ملغي',
  _ => status,
};
