import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

enum CustomerCreateMode { administrative, posQuickCreate }

/// Shared modal frame for the complete administrative form and the restricted
/// POS quick-create form. The form content remains owned by its feature cubit.
class CustomerCreateDialog extends StatelessWidget {
  const CustomerCreateDialog({
    super.key,
    required this.mode,
    required this.child,
    this.maxWidth = 760,
    this.maxHeight = 760,
    this.fitContent = false,
  });

  final CustomerCreateMode mode;
  final Widget child;
  final double maxWidth;
  final double maxHeight;
  final bool fitContent;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double width = math.min(maxWidth, math.max(280, size.width - 48));
    final double height = math.min(maxHeight, math.max(360, size.height - 48));
    final Widget dialogChild = fitContent
        ? ConstrainedBox(
            key: ValueKey<String>(
              'customer-create-dialog-content-${mode.name}',
            ),
            constraints: BoxConstraints(maxHeight: height),
            child: SizedBox(width: width, child: child),
          )
        : SizedBox(
            key: ValueKey<String>(
              'customer-create-dialog-content-${mode.name}',
            ),
            width: width,
            height: height,
            child: child,
          );

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Center(
        child: Dialog(
          key: ValueKey<String>('customer-create-dialog-${mode.name}'),
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: AppColors.white,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
          child: dialogChild,
        ),
      ),
    );
  }
}
