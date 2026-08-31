import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../pos/controllers/pos_cubit.dart';
import '../controllers/daily_report_cubit.dart';
import '../controllers/daily_report_state.dart';
import '../models/daily_report_data.dart';
import '../widgets/report_analytics_cards.dart';
import '../widgets/report_header.dart';
import '../widgets/report_kpi_grid.dart';
import '../widgets/report_tables.dart';

class DailyOperationalReportScreen extends StatelessWidget {
  const DailyOperationalReportScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DailyReportCubit, DailyReportState>(
        builder: (BuildContext context, DailyReportState state) {
          return DesktopPageLayout(
            padding: EdgeInsets.zero,
            child: switch (state.status) {
              DailyReportStatus.loading => const AppLoading(),
              DailyReportStatus.empty => const AppEmptyState(
                message: 'No report data is available for this date.',
                icon: Icons.bar_chart_outlined,
              ),
              DailyReportStatus.error => _ReportError(
                message:
                    state.errorMessage ?? 'The report could not be loaded.',
              ),
              DailyReportStatus.loaded => _ReportContent(
                data: state.data!,
                dateLabel: state.dateLabel,
              ),
            },
          );
        },
      );
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.data, required this.dateLabel});
  final DailyReportData data;
  final String dateLabel;
  @override
  Widget build(BuildContext context) {
    final DailyReportCubit cubit = context.read<DailyReportCubit>();
    return SingleChildScrollView(
      key: const Key('daily-report-scroll-view'),
      padding: AppSpacing.allXxl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.ordersContentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ReportHeader(
                dateLabel: dateLabel,
                onDateTap: () => _chooseDate(context, cubit),
                onPrint: () => _showMessage(
                  context,
                  'Print the report from your system print dialog.',
                ),
                onExport: () => _showMessage(
                  context,
                  'Report data is loaded from the current branch and date.',
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ReportKpiGrid(items: data.kpis),
              const SizedBox(height: AppSpacing.xxl),
              HourlySalesChart(points: data.hourlySales),
              const SizedBox(height: AppSpacing.xxl),
              _PairedSections(
                left: PaymentMethodBreakdownCard(items: data.paymentMethods),
                right: OrdersByTypeCard(items: data.orderTypes),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _PairedSections(
                left: TopSellingProductsTable(items: data.topProducts),
                right: RefundSummaryCard(items: data.refunds),
                leftFlex: 2,
              ),
              const SizedBox(height: AppSpacing.xxl),
              DiscountsUsageTable(items: data.discounts),
              const SizedBox(height: AppSpacing.xxl),
              RecentTransactionsTable(
                items: data.transactions,
                onViewAll: () => context.go(AppRoutes.orders),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseDate(BuildContext context, DailyReportCubit cubit) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null && context.mounted) {
      cubit.selectDate(date, branchId: context.read<PosCubit>().state.branchId);
    }
  }

  void _showMessage(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
}

class _PairedSections extends StatelessWidget {
  const _PairedSections({
    required this.left,
    required this.right,
    this.leftFlex = 1,
  });
  final Widget left;
  final Widget right;
  final int leftFlex;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      if (constraints.maxWidth < 880) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            left,
            const SizedBox(height: AppSpacing.xxl),
            right,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: leftFlex, child: left),
          const SizedBox(width: AppSpacing.xxl),
          Expanded(child: right),
        ],
      );
    },
  );
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppEmptyState(message: message, icon: Icons.cloud_off_outlined),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Retry',
          icon: Icons.refresh_outlined,
          onPressed: context.read<DailyReportCubit>().loadReport,
        ),
      ],
    ),
  );
}
