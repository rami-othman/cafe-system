import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/order_detail.dart';
import 'order_customer_section.dart';
import 'order_detail_items_section.dart';
import 'order_detail_totals_section.dart';
import 'order_details_header.dart';
import 'order_payment_section.dart';
import 'order_timeline_section.dart';

class OrderDetailsPanel extends StatelessWidget {
  const OrderDetailsPanel({
    super.key,
    required this.detail,
    required this.onClose,
    required this.onPrint,
    required this.onCopy,
    required this.onRefund,
  });

  final OrderDetail detail;
  final VoidCallback onClose;
  final VoidCallback onPrint;
  final VoidCallback onCopy;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
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
            height: constraints.maxHeight,
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
              child: Column(
                children: <Widget>[
                  OrderDetailsHeader(
                    detail: detail,
                    onClose: onClose,
                    onPrint: onPrint,
                    onCopy: onCopy,
                    onRefund: onRefund,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: AppSpacing.allXl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          OrderCustomerSection(detail: detail),
                          const SizedBox(height: AppSpacing.xl),
                          OrderDetailItemsSection(items: detail.items),
                          const SizedBox(height: AppSpacing.xl),
                          OrderDetailTotalsSection(detail: detail),
                          const SizedBox(height: AppSpacing.xl),
                          OrderPaymentSection(detail: detail),
                          const SizedBox(height: AppSpacing.xl),
                          OrderTimelineSection(events: detail.timeline),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
