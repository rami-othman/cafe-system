import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
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
import '../../pos/controllers/pos_cubit.dart';
import '../../pos/models/payment_method.dart';
import '../../pos/models/payment_result.dart';
import '../../pos/models/payment_summary.dart';
import '../../pos/widgets/payment_dialog.dart';
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
                        if (state.isLoading && state.orders.isEmpty)
                          const Center(child: CircularProgressIndicator())
                        else if (state.errorMessage != null &&
                            state.orders.isEmpty)
                          _OrdersErrorState(
                            message: state.errorMessage!,
                            onRetry: cubit.refreshOrders,
                          )
                        else if (state.filteredOrders.isEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (state.errorMessage != null)
                                _OrdersInlineError(
                                  message: state.errorMessage!,
                                  onRetry: cubit.refreshOrders,
                                ),
                              const AppEmptyState(
                                message: 'No orders match this filter yet.',
                                icon: Icons.receipt_long_outlined,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              _OrdersPagination(
                                currentPage: state.currentPage,
                                lastPage: state.lastPage,
                                total: state.total,
                                isLoading: state.isPageLoading,
                                canGoPrevious: state.canGoPrevious,
                                canGoNext: state.canGoNext,
                                onPrevious: cubit.previousPage,
                                onNext: cubit.nextPage,
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (state.errorMessage != null)
                                _OrdersInlineError(
                                  message: state.errorMessage!,
                                  onRetry: cubit.refreshOrders,
                                ),
                              _OrdersGrid(
                                orders: state.filteredOrders,
                                onDetails: cubit.openOrderDetails,
                                onPay: (String orderId) =>
                                    _showPaymentDialog(context, cubit, orderId),
                                isPaymentBlocked:
                                    state.isPaymentBlocked ||
                                    state.isOrderActionBlocked,
                                isLifecycleActionBlocked:
                                    _isLifecycleActionBlocked(state),
                                onResume: cubit.repository.usesBackend
                                    ? (String orderId) =>
                                          _resumeOrder(context, cubit, orderId)
                                    : null,
                                onCancel: cubit.repository.usesBackend
                                    ? (String orderId) => _showCancelDialog(
                                        context,
                                        cubit,
                                        orderId,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              _OrdersPagination(
                                currentPage: state.currentPage,
                                lastPage: state.lastPage,
                                total: state.total,
                                isLoading: state.isPageLoading,
                                canGoPrevious: state.canGoPrevious,
                                canGoNext: state.canGoNext,
                                onPrevious: cubit.previousPage,
                                onNext: cubit.nextPage,
                              ),
                            ],
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
                  child: AbsorbPointer(
                    absorbing:
                        state.isRefundSubmitting ||
                        state.isPaymentPreparing ||
                        state.isPaymentSubmitting ||
                        state.isOrderActionSubmitting,
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
                        onPay:
                            state.selectedOrderDetail!.canPay &&
                                !state.isPaymentBlocked &&
                                !_isLifecycleActionBlocked(state)
                            ? () => _showPaymentDialog(
                                context,
                                cubit,
                                state.selectedOrderDetail!.id,
                              )
                            : null,
                        onResume:
                            cubit.repository.usesBackend &&
                                state.selectedOrderDetail!.canResume &&
                                !_isLifecycleActionBlocked(state)
                            ? () => _resumeOrder(
                                context,
                                cubit,
                                state.selectedOrderDetail!.id,
                              )
                            : null,
                        onCancel:
                            cubit.repository.usesBackend &&
                                state.selectedOrderDetail!.canCancel &&
                                !_isLifecycleActionBlocked(state)
                            ? () => _showCancelDialog(
                                context,
                                cubit,
                                state.selectedOrderDetail!.id,
                              )
                            : null,
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

  bool _isLifecycleActionBlocked(OrdersState state) {
    return state.isOrderActionBlocked ||
        state.isPaymentBlocked ||
        state.isRefundSubmitting ||
        state.uncertainRefundMessage != null;
  }

  Future<void> _resumeOrder(
    BuildContext context,
    OrdersCubit cubit,
    String orderId,
  ) async {
    if (!context.mounted) {
      return;
    }
    final PosCubit posCubit = context.read<PosCubit>();
    final int? backendId = int.tryParse(orderId);
    if (backendId == null) {
      _showSnackBar(context, 'This order cannot be resumed.');
      return;
    }
    final bool replacingAnotherContext =
        (posCubit.state.currentOrderId != null &&
            posCubit.state.currentOrderId != backendId) ||
        (posCubit.state.hasCartItems &&
            posCubit.state.currentOrderId != backendId);
    if (replacingAnotherContext) {
      final bool confirmed =
          await showDialog<bool>(
            context: context,
            barrierColor: AppColors.black.withValues(alpha: 0.42),
            builder: (BuildContext dialogContext) =>
                const _ResumeReplacementDialog(),
          ) ??
          false;
      if (!confirmed || !context.mounted) {
        return;
      }
    }

    final OrdersActionOutcome outcome = await cubit.resumeOrder(
      orderId,
      loadIntoPos: (String id) => posCubit.loadExistingOrder(
        int.parse(id),
        allowReplace: replacingAnotherContext,
      ),
    );
    if (!context.mounted || outcome == OrdersActionOutcome.stale) {
      return;
    }
    if (outcome == OrdersActionOutcome.confirmed) {
      context.go(AppRoutes.pos);
      return;
    }
    _showSnackBar(
      context,
      cubit.state.uncertainOrderActionMessage ??
          cubit.state.orderActionErrorMessage ??
          'Could not resume this order. Please try again.',
    );
  }

  Future<void> _showCancelDialog(
    BuildContext context,
    OrdersCubit cubit,
    String orderId,
  ) async {
    final OrderSummary? summary = cubit.state.orders
        .cast<OrderSummary?>()
        .firstWhere(
          (OrderSummary? order) => order?.id == orderId,
          orElse: () => null,
        );
    final String displayNumber = summary?.displayNumber ?? '#$orderId';
    final OrdersActionOutcome? outcome = await showDialog<OrdersActionOutcome>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.black.withValues(alpha: 0.42),
      builder: (BuildContext dialogContext) => _CancelOrderDialog(
        displayNumber: displayNumber,
        onConfirm: () => cubit.cancelOrder(orderId),
      ),
    );
    if (!context.mounted ||
        outcome == null ||
        outcome == OrdersActionOutcome.stale) {
      return;
    }
    if (outcome == OrdersActionOutcome.confirmed) {
      context.read<PosCubit>().clearCancelledOrderContext(int.parse(orderId));
      _showSnackBar(context, 'Order cancelled.');
      return;
    }

    _showSnackBar(
      context,
      cubit.state.uncertainOrderActionMessage ??
          cubit.state.orderActionErrorMessage ??
          'Could not cancel this order.',
      action: outcome == OrdersActionOutcome.uncertain
          ? SnackBarAction(
              label: 'Check status',
              onPressed: () async {
                final OrdersActionOutcome checked = await cubit
                    .checkUncertainOrderActionStatus();
                if (!context.mounted) {
                  return;
                }
                if (checked == OrdersActionOutcome.confirmed) {
                  context.read<PosCubit>().clearCancelledOrderContext(
                    int.parse(orderId),
                  );
                  _showSnackBar(context, 'Order cancellation confirmed.');
                } else if (checked == OrdersActionOutcome.retryableFailure) {
                  _showSnackBar(
                    context,
                    cubit.state.orderActionErrorMessage ??
                        'Order is still active. Retry cancellation explicitly.',
                  );
                }
              },
            )
          : null,
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _showPaymentDialog(
    BuildContext context,
    OrdersCubit cubit,
    String orderId,
  ) async {
    final PaymentSummary? summary = await cubit.preparePayment(orderId);
    if (!context.mounted) {
      return;
    }
    if (summary == null) {
      final String? message = cubit.state.paymentErrorMessage;
      if (message != null) {
        _showSnackBar(context, message);
      }
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.black.withValues(alpha: 0.42),
      builder: (BuildContext dialogContext) {
        return PaymentDialog(
          orderNumber: _displayOrderNumber(summary.orderNumber),
          totalDue: summary.amountDue,
          itemCount: summary.itemCount,
          availableMethods: _paymentMethods(summary),
          onSubmit: (PaymentResult payment) async {
            final OrdersPaymentStatus status = await cubit.submitPayment(
              payment,
            );
            final PaymentCompletionStatus dialogStatus = _dialogStatus(status);
            if (!context.mounted || status == OrdersPaymentStatus.confirmed) {
              return dialogStatus;
            }

            final String message =
                cubit.state.uncertainPaymentMessage ??
                cubit.state.paymentErrorMessage ??
                'Could not record payment. Please try again.';
            _showSnackBar(
              context,
              message,
              action: dialogStatus == PaymentCompletionStatus.uncertain
                  ? SnackBarAction(
                      label: 'Check status',
                      onPressed: () async {
                        final OrdersPaymentStatus checked = await cubit
                            .checkUncertainPaymentStatus();
                        if (context.mounted &&
                            checked == OrdersPaymentStatus.confirmed) {
                          _showSnackBar(context, 'Payment confirmed.');
                        }
                      },
                    )
                  : null,
            );
            return _dialogStatus(status);
          },
        );
      },
    );

    if (!context.mounted) {
      return;
    }
    if (cubit.state.paymentStatus == OrdersPaymentStatus.confirmed) {
      final bool receiptPending = cubit.state.receiptErrorMessage != null;
      _showSnackBar(
        context,
        receiptPending
            ? 'Payment confirmed, but the receipt is unavailable.'
            : 'Payment confirmed.',
        action: receiptPending
            ? SnackBarAction(
                label: 'Retry receipt',
                onPressed: cubit.retryPaymentReceipt,
              )
            : null,
      );
    }
  }

  List<PaymentMethod> _paymentMethods(PaymentSummary summary) {
    final List<PaymentMethod> methods = <PaymentMethod>[];
    for (final String value in summary.methods) {
      final PaymentMethod? method = switch (value.toLowerCase()) {
        'cash' => PaymentMethod.cash,
        'card' => PaymentMethod.card,
        'wallet' => PaymentMethod.wallet,
        'split' => PaymentMethod.split,
        _ => null,
      };
      if (method != null && !methods.contains(method)) {
        methods.add(method);
      }
    }
    return methods;
  }

  String _displayOrderNumber(String value) {
    final String trimmed = value.trim();
    return trimmed.startsWith('#') ? trimmed : '#$trimmed';
  }

  PaymentCompletionStatus _dialogStatus(OrdersPaymentStatus status) {
    return paymentCompletionStatusFor(status);
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

    final RefundCompletionStatus status = await cubit.submitRefund(result);
    if (!context.mounted) {
      return;
    }

    if (status == RefundCompletionStatus.completed) {
      _showSnackBar(context, 'Refund recorded.');
      return;
    }

    _showSnackBar(
      context,
      cubit.state.uncertainRefundMessage ??
          cubit.state.refundErrorMessage ??
          'Could not record refund. Please check the order before retrying.',
    );
  }
}

PaymentCompletionStatus paymentCompletionStatusFor(OrdersPaymentStatus status) {
  return switch (status) {
    OrdersPaymentStatus.confirmed => PaymentCompletionStatus.completed,
    OrdersPaymentStatus.retryableFailure =>
      PaymentCompletionStatus.retryableFailure,
    OrdersPaymentStatus.uncertain => PaymentCompletionStatus.uncertain,
    OrdersPaymentStatus.idle ||
    OrdersPaymentStatus.preparing ||
    OrdersPaymentStatus.ready ||
    OrdersPaymentStatus.submitting => PaymentCompletionStatus.uncertain,
  };
}

class _OrdersErrorState extends StatelessWidget {
  const _OrdersErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppEmptyState(message: message, icon: Icons.cloud_off_outlined),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _OrdersInlineError extends StatelessWidget {
  const _OrdersInlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _OrdersPagination extends StatelessWidget {
  const _OrdersPagination({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.isLoading,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int lastPage;
  final int total;
  final bool isLoading;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        OutlinedButton(
          key: const ValueKey<String>('ordersPreviousPage'),
          onPressed: isLoading || !canGoPrevious ? null : onPrevious,
          child: const Text('Previous'),
        ),
        Text('Page $currentPage of $lastPage'),
        OutlinedButton(
          key: const ValueKey<String>('ordersNextPage'),
          onPressed: isLoading || !canGoNext ? null : onNext,
          child: const Text('Next'),
        ),
        if (total > 0) Text('$total orders'),
      ],
    );
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
    required this.isPaymentBlocked,
    required this.isLifecycleActionBlocked,
    required this.onResume,
    required this.onCancel,
  });

  final List<OrderSummary> orders;
  final ValueChanged<String> onDetails;
  final ValueChanged<String> onPay;
  final bool isPaymentBlocked;
  final bool isLifecycleActionBlocked;
  final ValueChanged<String>? onResume;
  final ValueChanged<String>? onCancel;

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
                  onPay: isPaymentBlocked || !order.canPay
                      ? null
                      : () => onPay(order.id),
                  onResume:
                      isLifecycleActionBlocked ||
                          onResume == null ||
                          !order.canResume
                      ? null
                      : () => onResume?.call(order.id),
                  onCancel:
                      isLifecycleActionBlocked ||
                          onCancel == null ||
                          !order.canCancel
                      ? null
                      : () => onCancel?.call(order.id),
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

class _ResumeReplacementDialog extends StatelessWidget {
  const _ResumeReplacementDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Replace current POS cart?'),
      content: const Text(
        'Resuming this held order will replace the current POS cart context. '
        'Unsaved local changes will be discarded.',
      ),
      actions: <Widget>[
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep current cart'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Replace and resume'),
        ),
      ],
    );
  }
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog({
    required this.displayNumber,
    required this.onConfirm,
  });

  final String displayNumber;
  final Future<OrdersActionOutcome> Function() onConfirm;

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  bool _isSubmitting = false;

  Future<void> _confirm() async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    final OrdersActionOutcome outcome = await widget.onConfirm();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: const Text('Cancel order?'),
        content: Text('Cancel ${widget.displayNumber}? This cannot be undone.'),
        actions: <Widget>[
          OutlinedButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Keep order'),
          ),
          Semantics(
            button: true,
            enabled: !_isSubmitting,
            label: _isSubmitting ? 'Cancel order submitting' : 'Cancel order',
            child: FilledButton(
              onPressed: _isSubmitting ? null : _confirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dangerStrong,
                foregroundColor: AppColors.textInverse,
                disabledBackgroundColor: AppColors.surfaceAlt,
                disabledForegroundColor: AppColors.textMuted,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cancel order'),
            ),
          ),
        ],
      ),
    );
  }
}
