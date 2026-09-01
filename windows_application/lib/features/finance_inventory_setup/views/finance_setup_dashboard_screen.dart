import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../controllers/finance_setup_state.dart';

class FinanceSetupDashboardScreen extends StatefulWidget {
  const FinanceSetupDashboardScreen({super.key});
  @override
  State<FinanceSetupDashboardScreen> createState() => _SetupState();
}

class _SetupState extends State<FinanceSetupDashboardScreen> {
  @override
  void initState() {
    super.initState();
    final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
    Future<void>.microtask(cubit.loadDashboard);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      child: BlocBuilder<FinanceSetupCubit, FinanceSetupState>(
        builder: (context, state) {
          final status = state.status;
          if (status == null) {
            return state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ManagementMessage(
                    message: state.errorMessage ?? 'تعذر تحميل حالة الإعداد.',
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
                  title: 'إعداد النظام المالي والمخزني',
                  subtitle:
                      'تابع جاهزية الأساسيات قبل تشغيل عمليات المخزون والمالية.',
                  actions: <Widget>[
                    AppButton(
                      label: 'تهيئة المخازن',
                      icon: Icons.warehouse_outlined,
                      onPressed: () => context.go(AppRoutes.financeWarehouses),
                    ),
                    AppButton(
                      label: 'دليل الحسابات',
                      icon: Icons.account_tree_outlined,
                      variant: AppButtonVariant.outlined,
                      onPressed: () =>
                          context.go(AppRoutes.financeAccountsCanonical),
                    ),
                    AppButton(
                      label: 'فئات المصروفات',
                      icon: Icons.category_outlined,
                      variant: AppButtonVariant.outlined,
                      onPressed: () =>
                          context.go(AppRoutes.financeExpenseCategories),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ManagementTableShell(
                  minWidth: 0,
                  child: Padding(
                    padding: AppSpacing.allXl,
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: status.financialSetupReady
                                ? AppColors.discountGreenBadge
                                : AppColors.discountOrangeBadge,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            status.financialSetupReady
                                ? Icons.verified_outlined
                                : Icons.pending_actions_outlined,
                            color: status.financialSetupReady
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                status.financialSetupReady
                                    ? 'الإعداد المالي جاهز'
                                    : 'الإعداد يحتاج إلى استكمال',
                                style: AppTextStyles.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                status.financialSetupReady
                                    ? 'تم إعداد الحسابات والمستودعات الأساسية.'
                                    : 'راجع قائمة الجاهزية وأكمل العناصر المطلوبة.',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('قائمة الجاهزية', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _Readiness(
                  label: 'دليل الحسابات الأساسي',
                  ready: status.systemAccountsReady,
                  onTap: () => context.go(AppRoutes.financeAccountsCanonical),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Readiness(
                  label: 'المستودع المركزي',
                  ready: status.centralWarehouseReady,
                  onTap: () => context.go(AppRoutes.financeWarehouses),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Readiness(
                  label: 'تغطية مخازن الفروع',
                  detail: status.missingBranchWarehouses.isEmpty
                      ? null
                      : 'الفروع الناقصة: ${status.missingBranchWarehouses.join('، ')}',
                  ready: status.branchWarehouseCoverageReady,
                  onTap: () => context.go(AppRoutes.financeWarehouses),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'قيود اليومية',
                  icon: Icons.menu_book_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: () =>
                      context.go(AppRoutes.financeJournalEntriesCanonical),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'الحسابات الافتراضية الحالية',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ManagementTableShell(
                  minWidth: 0,
                  child: Padding(
                    padding: AppSpacing.allLg,
                    child: Column(
                      children: status.defaultAccounts.isEmpty
                          ? const <Widget>[
                              Text('لم يتم العثور على حسابات افتراضية مُهيأة.'),
                            ]
                          : status.defaultAccounts
                                .map(
                                  (account) => ListTile(
                                    dense: true,
                                    title: Text(
                                      '${account.code} — ${account.nameAr}',
                                    ),
                                    trailing: ManagementBadge(
                                      label: account.isActive
                                          ? 'نشط'
                                          : 'غير نشط',
                                      tone: account.isActive
                                          ? ManagementTone.success
                                          : ManagementTone.neutral,
                                    ),
                                  ),
                                )
                                .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'جاهزية التكاملات المستقبلية',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'النقد والبنوك، المصروفات، نقاط البيع، الموردون، محاسبة المخزون، التسويات والتقارير المالية: مؤجلة للمراحل التالية ولا توجد إعدادات صورية لها.',
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _Readiness extends StatelessWidget {
  const _Readiness({
    required this.label,
    required this.ready,
    required this.onTap,
    this.detail,
  });
  final String label;
  final String? detail;
  final bool ready;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ManagementTableShell(
    minWidth: 0,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.allLg,
        child: Row(
          children: <Widget>[
            Icon(
              ready ? Icons.check_circle_outline : Icons.radio_button_unchecked,
              color: ready ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: AppTextStyles.titleMedium),
                  if (detail != null)
                    Text(detail!, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Text(
              ready ? 'مكتمل' : 'إكمال',
              style: AppTextStyles.labelLarge.copyWith(
                color: ready ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
