import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../controllers/orders_cubit.dart';
import '../controllers/orders_state.dart';
import '../models/order_summary.dart';
import '../widgets/order_filter_tabs.dart';
import '../widgets/order_summary_card.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (BuildContext context, OrdersState state) {
        final OrdersCubit cubit = context.read<OrdersCubit>();

        return DesktopPageLayout(
          padding: AppSpacing.allXxl,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.ordersContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _OrdersHeader(
                    selectedFilter: state.selectedFilter,
                    onFilterSelected: cubit.selectFilter,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (state.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (state.filteredOrders.isEmpty)
                    const AppEmptyState(
                      message: 'No orders match this filter yet.',
                      icon: Icons.receipt_long_outlined,
                    )
                  else
                    _OrdersGrid(
                      orders: state.filteredOrders,
                      onDetails: () => _showSnackBar(
                        context,
                        'Order details will be added later.',
                      ),
                      onPay: () => _showSnackBar(
                        context,
                        'Payment from Orders screen will be added later.',
                      ),
                      onResume: () => _showSnackBar(
                        context,
                        'Resume held order will be connected to POS later.',
                      ),
                      onCancel: cubit.cancelOrder,
                      onComplete: cubit.completeOrder,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final OrdersFilter selectedFilter;
  final ValueChanged<OrdersFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stackFilters = constraints.maxWidth < 760;

        final Widget title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Order Management',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'View and manage all active, held, and recent orders.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        );

        final Widget filters = OrderFilterTabs(
          selectedFilter: selectedFilter,
          onFilterSelected: onFilterSelected,
        );

        if (stackFilters) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title,
              const SizedBox(height: AppSpacing.lg),
              filters,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: title),
            const SizedBox(width: AppSpacing.xl),
            SizedBox(width: 530, child: filters),
          ],
        );
      },
    );
  }
}

class _OrdersGrid extends StatelessWidget {
  const _OrdersGrid({
    required this.orders,
    required this.onDetails,
    required this.onPay,
    required this.onResume,
    required this.onCancel,
    required this.onComplete,
  });

  final List<OrderSummary> orders;
  final VoidCallback onDetails;
  final VoidCallback onPay;
  final VoidCallback onResume;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onComplete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = AppSizes.ordersGridGap;
        final double cardWidth = _cardWidthFor(constraints.maxWidth, gap);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final OrderSummary order in orders)
              SizedBox(
                width: cardWidth,
                child: OrderSummaryCard(
                  order: order,
                  onDetails: onDetails,
                  onPay: onPay,
                  onResume: onResume,
                  onCancel: () => onCancel(order.id),
                  onComplete: () => onComplete(order.id),
                ),
              ),
          ],
        );
      },
    );
  }

  double _cardWidthFor(double availableWidth, double gap) {
    if (availableWidth <= AppSizes.orderCardMinWidth) {
      return availableWidth;
    }

    final int columns =
        ((availableWidth + gap) / (AppSizes.orderCardMinWidth + gap))
            .floor()
            .clamp(1, orders.length)
            .toInt();
    final double fillWidth = (availableWidth - (gap * (columns - 1))) / columns;

    return fillWidth
        .clamp(AppSizes.orderCardMinWidth, AppSizes.orderCardMaxWidth)
        .toDouble();
  }
}
