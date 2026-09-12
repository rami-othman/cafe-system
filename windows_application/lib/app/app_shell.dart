import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/constants/app_sizes.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../shared/widgets/app_sidebar.dart';
import '../features/auth/controllers/auth_session_cubit.dart';
import '../features/auth/models/auth_session.dart';
import '../features/customer_management/models/customer_management_access.dart';
import '../shared/widgets/app_top_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.activeLabel,
    this.rightPanel,
    this.topBar,
    this.onRefresh,
    this.prioritizeContentWidth = false,
  });

  final Widget child;
  final String activeLabel;
  final Widget? rightPanel;
  final Widget? topBar;
  final Future<void> Function(BuildContext context)? onRefresh;
  final bool prioritizeContentWidth;

  @override
  Widget build(BuildContext context) {
    final AuthSession? session = context
        .select<AuthSessionCubit?, AuthSession?>(
          (AuthSessionCubit? cubit) => cubit?.state.session,
        );
    return Scaffold(
      backgroundColor: AppColors.shellBackground,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final bool isLarge =
              Responsive.isLargeWidth(width) &&
              (!prioritizeContentWidth ||
                  width >= AppSizes.menuModuleSidebarExpandedBreakpoint);
          final bool isCompact = Responsive.isCompactWidth(width);
          final double rightPanelWidth = isLarge
              ? AppSizes.rightPanelWidth
              : AppSizes.mediumRightPanelWidth;

          return Row(
            children: <Widget>[
              AppSidebar(
                activeLabel: activeLabel,
                isCollapsed: !isLarge,
                actorRole: session?.user.role,
                canManageCustomers: CustomerManagementAccess.allows(session),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    topBar ??
                        AppTopBar(
                          showCartButton: isCompact && rightPanel != null,
                          onRefresh: onRefresh,
                        ),
                    Expanded(child: child),
                  ],
                ),
              ),
              if (!isCompact && rightPanel != null)
                SizedBox(width: rightPanelWidth, child: rightPanel),
            ],
          );
        },
      ),
    );
  }
}
