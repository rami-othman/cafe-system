import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/branding/app_brand.dart';
import '../core/branding/brand_title_synchronizer.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../features/auth/controllers/auth_session_cubit.dart';
import '../features/auth/models/auth_session.dart';
import '../features/customer_management/models/customer_management_access.dart';
import '../features/pos/controllers/pos_cubit.dart';
import '../features/pos/controllers/pos_state.dart';
import '../features/pos/models/branch.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/app_sidebar.dart';
import '../shared/widgets/app_top_bar.dart';

class AppShell extends StatefulWidget {
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
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const String _sidebarWidthPreference = 'app_sidebar_width';
  static const String _sidebarCollapsedPreference = 'app_sidebar_collapsed';
  static const double _sidebarMinWidth = 180;
  static const double _sidebarMaxWidth = 360;

  double _sidebarWidth = AppSizes.sidebarWidth;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _restoreSidebarPreference();
  }

  Future<void> _restoreSidebarPreference() async {
    try {
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      final double width = preferences.getDouble(_sidebarWidthPreference) ?? _sidebarWidth;
      final bool collapsed =
          preferences.getBool(_sidebarCollapsedPreference) ?? _sidebarCollapsed;
      if (!mounted) return;
      setState(() {
        _sidebarWidth =
            width.clamp(_sidebarMinWidth, _sidebarMaxWidth).toDouble();
        _sidebarCollapsed = collapsed;
      });
    } catch (_) {
      // Preference storage is optional; the shell remains fully usable when
      // an embedding (such as a widget test) does not provide it.
    }
  }

  Future<void> _saveSidebarPreference() async {
    try {
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_sidebarWidthPreference, _sidebarWidth);
      await preferences.setBool(_sidebarCollapsedPreference, _sidebarCollapsed);
    } catch (_) {
      // A failed preference write must never prevent navigation or resizing.
    }
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    _saveSidebarPreference();
  }

  void _resizeSidebar(double delta, TextDirection direction) {
    final double directionalDelta =
        direction == TextDirection.rtl ? -delta : delta;
    setState(() {
      if (_sidebarCollapsed) {
        _sidebarCollapsed = false;
      }
      _sidebarWidth =
          (_sidebarWidth + directionalDelta)
              .clamp(_sidebarMinWidth, _sidebarMaxWidth)
              .toDouble();
    });
    _saveSidebarPreference();
  }

  @override
  Widget build(BuildContext context) {
    final AuthSession? session =
        context.watch<AuthSessionCubit>().state.session;

    final AuthUser? user = session?.user;

    PosState? pos;
    try {
      pos = context.watch<PosCubit>().state;
    } catch (_) {
      // Keeps AppShell independently renderable in previews and shell-only
      // tests. Authenticated application routes normally provide PosCubit.
    }

    final AppLocalizations? l10n =
        Localizations.of<AppLocalizations>(
          context,
          AppLocalizations,
        );

    final bool isArabic =
        Localizations.localeOf(context).languageCode == 'ar';

    final BrandIdentity identity = AppBrand.resolve(
      user: user,
      branches: pos?.branches ?? const <Branch>[],
      activeBranchId: pos?.branchId,
      localizedSystemName:
          l10n?.appName ??
          (isArabic ? AppBrand.systemNameAr : AppBrand.systemNameEn),
      localizedOperationalHub:
          l10n?.operationalHub ??
          (isArabic ? 'مركز العمليات' : 'OPERATIONAL HUB'),
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
                (!widget.prioritizeContentWidth ||
                    width >= AppSizes.menuModuleSidebarExpandedBreakpoint);
            final bool isCompact = Responsive.isCompactWidth(width);

            final double rightPanelWidth = isLarge
                ? AppSizes.rightPanelWidth
                : AppSizes.mediumRightPanelWidth;
            final bool sidebarCollapsed = !isLarge || _sidebarCollapsed;
            final double sidebarWidth = sidebarCollapsed
                ? AppSizes.sidebarRailWidth
                : _sidebarWidth;

            return Row(
              children: <Widget>[
                SizedBox(
                  width: sidebarWidth,
                  child: AppSidebar(
                    activeLabel: widget.activeLabel,
                    isCollapsed: sidebarCollapsed,
                    width: sidebarWidth,
                    actorRole: user?.role,
                    financeCapabilities:
                        user?.financeCapabilities ?? const <String>{},
                    brandIdentity: identity,
                    canManageCustomers:
                        CustomerManagementAccess.allows(session),
                  ),
                ),
                if (isLarge)
                  _SidebarResizeHandle(
                    isCollapsed: _sidebarCollapsed,
                    onToggle: _toggleSidebar,
                    onResize: (double delta) =>
                        _resizeSidebar(delta, Directionality.of(context)),
                  ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      widget.topBar ??
                          AppTopBar(
                            showCartButton:
                                isCompact && widget.rightPanel != null,
                            onRefresh: widget.onRefresh,
                          ),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
                if (!isCompact && widget.rightPanel != null)
                  SizedBox(width: rightPanelWidth, child: widget.rightPanel),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SidebarResizeHandle extends StatelessWidget {
  const _SidebarResizeHandle({
    required this.isCollapsed,
    required this.onToggle,
    required this.onResize,
  });

  final bool isCollapsed;
  final VoidCallback onToggle;
  final ValueChanged<double> onResize;

  @override
  Widget build(BuildContext context) {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (DragUpdateDetails details) =>
            onResize(details.delta.dx),
        child: SizedBox(
          width: 20,
          child: Center(
            child: Tooltip(
              message: isCollapsed
                  ? (isArabic ? 'توسيع الشريط الجانبي' : 'Expand sidebar')
                  : (isArabic ? 'طي الشريط الجانبي' : 'Collapse sidebar'),
              child: IconButton(
                constraints: const BoxConstraints.tightFor(width: 20, height: 32),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                color: AppColors.textMuted,
                onPressed: onToggle,
                icon: Icon(
                  isCollapsed
                      ? Icons.keyboard_double_arrow_right
                      : Icons.keyboard_double_arrow_left,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
