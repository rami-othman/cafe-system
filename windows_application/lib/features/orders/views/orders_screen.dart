import 'dart:ui';

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
import '../models/order_detail.dart';
import '../models/order_summary.dart';
import '../models/refund_result.dart';
import '../widgets/order_filter_tabs.dart';
import '../widgets/order_details_panel.dart';
import '../widgets/order_summary_card.dart';
import '../widgets/refund_dialog.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (BuildContext context, OrdersState state) {
        final OrdersCubit cubit = context.read<OrdersCubit>();

        return DesktopPageLayout(
          padding: EdgeInsets.zero,
          child: Stack(
            children: <Widget>[
              Padding(
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
                        else if (state.errorMessage != null)
                          AppEmptyState(
                            message: state.errorMessage!,
                            icon: Icons.cloud_off_outlined,
                          )
                        else if (state.filteredOrders.isEmpty)
                          const AppEmptyState(
                            message: 'No orders match this filter yet.',
                            icon: Icons.receipt_long_outlined,
                          )
                        else
                          _OrdersGrid(
                            orders: state.filteredOrders,
                            onDetails: cubit.openOrderDetails,
                            onPay: () => _showSnackBar(
                              context,
                              'Payment from Orders screen will be connected later.',
                            ),
                            onResume: () => _showSnackBar(
                              context,
                              'Resume held order will be connected to POS later.',
                            ),
                            onCancel: () => _showSnackBar(
                              context,
                              'Cancel order from Orders screen will be connected later.',
                            ),
                            onComplete: () => _showSnackBar(
                              context,
                              'Complete order from Orders screen will be connected later.',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.isDetailsLoading || state.detailsErrorMessage != null)
                Positioned.fill(
                  child: _OrderDetailsOverlay(
                    onClose: cubit.closeOrderDetails,
                    child: _OrderDetailsStatusPanel(
                      message: state.detailsErrorMessage,
                    ),
                  ),
                )
              else if (state.selectedOrderDetail != null)
                Positioned.fill(
                  child: _OrderDetailsOverlay(
                    onClose: cubit.closeOrderDetails,
                    child: OrderDetailsPanel(
                      detail: state.selectedOrderDetail!,
                      onClose: cubit.closeOrderDetails,
                      onPrint: () => _showSnackBar(
                        context,
                        'Printing will be added later.',
                      ),
                      onCopy: () => _showSnackBar(
                        context,
                        'Copy order will be added later.',
                      ),
                      onRefund: () => _showRefundDialog(
                        context,
                        state.selectedOrderDetail!,
                        cubit,
                      ),
                    ),
                  ),
                ),
            ],
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

  Future<void> _showRefundDialog(
    BuildContext context,
    OrderDetail detail,
    OrdersCubit cubit,
  ) async {
    final RefundResult? result = await showDialog<RefundResult>(
      context: context,
      barrierColor: AppColors.black.withValues(alpha: 0.42),
      builder: (BuildContext dialogContext) {
        return RefundDialog(orderDetail: detail);
      },
    );

    if (result == null || !context.mounted) {
      return;
    }

    cubit.confirmRefund(result);
    _showSnackBar(context, 'Refund recorded locally.');
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
  final ValueChanged<String> onDetails;
  final VoidCallback onPay;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

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
                  onDetails: () => onDetails(order.id),
                  onPay: onPay,
                  onResume: onResume,
                  onCancel: onCancel,
                  onComplete: onComplete,
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

class _OrderDetailsStatusPanel extends StatelessWidget {
  const _OrderDetailsStatusPanel({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final bool hasError = message != null;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double compactWidth =
            constraints.maxWidth - AppSizes.orderDetailsCompactGutter;
        final double panelWidth = AppSizes.orderDetailsPanelWidth.clamp(
          0,
          compactWidth > 0 ? compactWidth : constraints.maxWidth,
        );

        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(left: BorderSide(color: AppColors.border)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x26000000),
                    offset: Offset(-8, 0),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Center(
                child: hasError
                    ? Padding(
                        padding: AppSpacing.allXl,
                        child: AppEmptyState(
                          message: message!,
                          icon: Icons.cloud_off_outlined,
                        ),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrderDetailsOverlay extends StatelessWidget {
  const _OrderDetailsOverlay({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: const ColoredBox(color: AppColors.orderDetailsBackdrop),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
