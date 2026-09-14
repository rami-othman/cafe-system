import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/branding/app_brand.dart';
import '../core/branding/brand_title_synchronizer.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../shared/widgets/app_sidebar.dart';
import '../features/auth/controllers/auth_session_cubit.dart';
import '../features/auth/models/auth_session.dart';
import '../features/pos/controllers/pos_cubit.dart';
import '../features/pos/controllers/pos_state.dart';
import '../features/pos/models/branch.dart';
import '../l10n/app_localizations.dart';
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
    final AuthUser? user = context
        .watch<AuthSessionCubit>()
        .state
        .session
        ?.user;
    PosState? pos;
    try {
      pos = context.watch<PosCubit>().state;
    } catch (_) {
      // Keeps AppShell independently renderable in previews and shell-only
      // tests. Authenticated application routes always provide PosCubit.
    }
    final AppLocalizations? l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final BrandIdentity identity = AppBrand.resolve(
      user: user,
      branches: pos?.branches ?? const <Branch>[],
      activeBranchId: pos?.branchId,
      localizedSystemName:
          l10n?.appName ??
          (isArabic ? AppBrand.systemNameAr : AppBrand.systemNameEn),
      localizedOperationalHub:
          l10n?.operationalHub ?? (isArabic ? 'مركز العمليات' : 'OPERATIONAL HUB'),
      localizedPos: l10n?.navigationPos ?? (isArabic ? 'نقطة البيع' : 'POS'),
    );

    return BrandTitleSynchronizer(
      identity: identity,
      child: Scaffold(
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
                  actorRole: user?.role,
                  brandIdentity: identity,
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
      ),
    );
  }
}
