import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../reports/models/reports_overview.dart';
import '../../reports/repositories/reports_repository.dart';
import '../controllers/finance_setup_cubit.dart';
import '../controllers/finance_setup_state.dart';

/// An accounting-foundation home. Setup-readiness figures come from the real
/// setup-status response; today's Net Sales / Gross Profit reuse the same
/// tested aggregation Reports Overview already exposes (Money never
/// recomputed independently here — see docs/finance §30).
class FinanceHomeScreen extends StatefulWidget {
  const FinanceHomeScreen({super.key});
  @override
  State<FinanceHomeScreen> createState() => _FinanceHomeScreenState();
}

class _FinanceHomeScreenState extends State<FinanceHomeScreen> {
  ReportsOverview? _salesOverview;
  String? _salesError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(context.read<FinanceSetupCubit>().loadDashboard);
    Future<void>.microtask(_loadSalesOverview);
  }

  Future<void> _loadSalesOverview() async {
    try {
      final DateTime today = DateTime.now();
      final ReportsOverview overview = await serviceLocator<ReportsRepository>()
          .getOverview(from: today, to: today, comparePrevious: false);
      if (mounted) setState(() => _salesOverview = overview);
    } catch (e) {
      if (mounted) setState(() => _salesError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    child: BlocBuilder<FinanceSetupCubit, FinanceSetupState>(
      builder: (context, state) {
        final status = state.status;
        if (status == null) {
          return state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ManagementMessage(
                  message: state.errorMessage ?? 'تعذر تحميل جاهزية المالية.',
                  error: state.errorMessage != null,
                  onRetry: () =>
                      context.read<FinanceSetupCubit>().loadDashboard(),
                );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ManagementPageHeader(
                title: 'المالية',
                subtitle:
                    'جاهزية الأساس المحاسبي — دون مؤشرات تشغيلية أو بيانات مالية مُنشأة.',
                actions: <Widget>[
                  AppButton(
                    label: 'دليل الحسابات',
                    icon: Icons.account_tree_outlined,
                    onPressed: () =>
                        context.go(AppRoutes.financeAccountsCanonical),
                  ),
                  AppButton(
                    label: 'القيود المحاسبية',
                    icon: Icons.menu_book_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: () =>
                        context.go(AppRoutes.financeJournalEntriesCanonical),
                  ),
                  AppButton(
                    label: 'النقد والبنوك',
                    icon: Icons.account_balance_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.go(AppRoutes.financeCashBanks),
                  ),
                  AppButton(
                    label: 'طرق الدفع',
                    icon: Icons.payment_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: () =>
                        context.go(AppRoutes.financePaymentMethods),
                  ),
                  AppButton(
                    label: 'المصروفات',
                    icon: Icons.receipt_long_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.go(AppRoutes.financeExpenses),
                  ),
                  AppButton(
                    label: 'الموردون والمستحقات',
                    icon: Icons.storefront_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.go(AppRoutes.financeSuppliers),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  ManagementKpiCard(
                    label: 'الحسابات',
                    value: '${status.accountCount}',
                    icon: Icons.account_tree_outlined,
                    detail: 'نشطة: ${status.activeAccountCount}',
                  ),
                  ManagementKpiCard(
                    label: 'القيود',
                    value: '${status.journalCount}',
                    icon: Icons.menu_book_outlined,
                    detail: 'مسودات: ${status.draftJournalCount}',
                  ),
                  ManagementKpiCard(
                    label: 'قيود مُرحّلة',
                    value: '${status.postedJournalCount}',
                    icon: Icons.verified_outlined,
                    detail: 'معكوسة: ${status.reversedOriginalCount}',
                  ),
                  ManagementKpiCard(
                    label: 'النقد والبنوك',
                    value: status.cashBankBalance,
                    icon: Icons.account_balance_outlined,
                    detail: 'حسابات: ${status.cashBankAccountCount}',
                  ),
                  ManagementKpiCard(
                    label: 'طرق الدفع النشطة',
                    value: '${status.activePaymentMethodCount}',
                    icon: Icons.payment_outlined,
                  ),
                  ManagementKpiCard(
                    label: 'مصروفات اليوم',
                    value: status.expensesToday,
                    icon: Icons.receipt_long_outlined,
                    detail: 'هذا الشهر: ${status.expensesThisMonth}',
                  ),
                  ManagementKpiCard(
                    label: 'مصروفات بانتظار الاعتماد',
                    value: '${status.pendingExpenseCount}',
                    icon: Icons.pending_actions_outlined,
                    detail: 'غير مدفوعة: ${status.unpaidExpenseCount}',
                  ),
                  if (_salesOverview != null) ...<Widget>[
                    ManagementKpiCard(
                      label: 'صافي المبيعات اليوم',
                      value: _salesOverview!.kpis.netSales.available
                          ? (_salesOverview!.kpis.netSales.value ?? 0)
                                .toStringAsFixed(2)
                          : 'غير متاح',
                      icon: Icons.point_of_sale_outlined,
                    ),
                    ManagementKpiCard(
                      label: 'الربح الإجمالي اليوم',
                      value: _salesOverview!.kpis.grossProfit.available
                          ? (_salesOverview!.kpis.grossProfit.value ?? 0)
                                .toStringAsFixed(2)
                          : 'التكلفة غير متاحة لكل الطلبات',
                      icon: Icons.trending_up_outlined,
                    ),
                  ] else if (_salesError != null)
                    ManagementKpiCard(
                      label: 'مبيعات اليوم',
                      value: 'تعذر التحميل',
                      icon: Icons.error_outline,
                    ),
                  ManagementKpiCard(
                    label: 'إجمالي المستحقات للموردين',
                    value: status.totalPayables,
                    icon: Icons.account_balance_wallet_outlined,
                    detail: 'موردون نشطون: ${status.activeSupplierCount}',
                  ),
                  ManagementKpiCard(
                    label: 'مستحقات متأخرة',
                    value: status.overduePayables,
                    icon: Icons.warning_amber_outlined,
                    detail: 'فواتير مفتوحة: ${status.openSupplierInvoiceCount}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('الأساس المحاسبي'),
              const SizedBox(height: AppSpacing.sm),
              _ReadinessRow('دليل الحسابات', status.systemAccountsReady),
              _ReadinessRow('محرك القيود', status.journalEngineReady),
              _ReadinessRow('دعم عكس القيود', status.journalReversalReady),
              _ReadinessRow('بنية الترحيل', status.postingInfrastructureReady),
              const SizedBox(height: AppSpacing.xl),
              const Text('جاهزية التكامل'),
              const SizedBox(height: AppSpacing.sm),
              const _IntegrationRow('محاسبة نقاط البيع', 'متصلة'),
              const _IntegrationRow('محاسبة المخزون', 'غير متصلة بعد'),
              const _IntegrationRow('النقد والبنوك', 'متصلة'),
              const _IntegrationRow('المصروفات', 'متصلة'),
              const _IntegrationRow('الموردون والمستحقات', 'متصلة'),
              const _IntegrationRow(
                'التسويات والإقفال اليومي',
                'غير مطبقة بعد',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'إعدادات المالية',
                icon: Icons.settings_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: () => context.go(AppRoutes.financeSettings),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow(this.label, this.ready);
  final String label;
  final bool ready;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: <Widget>[
        Icon(ready ? Icons.check_circle_outline : Icons.pending_outlined),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
        const Spacer(),
        ManagementBadge(
          label: ready ? 'جاهز' : 'قيد الإعداد',
          tone: ready ? ManagementTone.success : ManagementTone.warning,
        ),
      ],
    ),
  );
}

class _IntegrationRow extends StatelessWidget {
  const _IntegrationRow(this.label, this.status);
  final String label;
  final String status;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: <Widget>[
        const Icon(Icons.schedule_outlined),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
        ManagementBadge(label: status, tone: ManagementTone.neutral),
      ],
    ),
  );
}
