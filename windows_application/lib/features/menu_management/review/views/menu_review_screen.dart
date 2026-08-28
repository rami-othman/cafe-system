import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../app/menu_management_route_locations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../app/localization/localization_extensions.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../widgets/menu_page_header.dart';
import '../controllers/menu_review_cubit.dart';
import '../models/review_models.dart';
import '../presentation/validation_issue_presentation.dart';
import '../../versions/views/published_version_history_panel.dart';
import '../widgets/current_version_summary.dart';
import '../widgets/menu_preview_panel.dart';
import '../widgets/publish_panel.dart';
import '../widgets/readiness_summary.dart';
import '../widgets/review_selling_context.dart';
import '../widgets/review_workflow_tabs.dart';

class MenuReviewScreen extends StatefulWidget {
  const MenuReviewScreen({
    super.key,
    this.branchId,
    this.channel,
    this.menuId,
    this.evaluationAt,
    this.showVersions = false,
  });
  final int? branchId;
  final String? channel;
  final int? menuId;
  final DateTime? evaluationAt;
  final bool showVersions;
  @override
  State<MenuReviewScreen> createState() => _MenuReviewScreenState();
}

class _MenuReviewScreenState extends State<MenuReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.showVersions ? 3 : 0;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _selectedTab,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MenuReviewCubit>().load(
        branchId: widget.branchId,
        channel: widget.channel,
        menuId: widget.menuId,
        evaluationAt: widget.evaluationAt,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<MenuReviewCubit, MenuReviewState>(
        listener: (BuildContext context, MenuReviewState state) {
          if (_selectedTab == 1 &&
              state.hasContext &&
              state.preview == null &&
              state.previewStatus == ReviewRequestStatus.idle) {
            context.read<MenuReviewCubit>().preview();
          }
        },
        child: BlocBuilder<MenuReviewCubit, MenuReviewState>(
          builder: (context, state) {
            final MenuReviewCubit cubit = context.read<MenuReviewCubit>();
            return DesktopPageLayout(
              child: SingleChildScrollView(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        MenuPageHeader(
                          title: context.l10n.menuManagementReviewPublish,
                          subtitle: context.l10n.reviewPublishPageHelp,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ReviewSellingContext(state: state, cubit: cubit),
                        if (state.contextError != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          _ErrorCard(
                            message: state.contextError!,
                            onRetry: () => cubit.load(
                              branchId: state.selectedBranch?.id,
                              channel: state.channel,
                              menuId: state.menuId,
                            ),
                          ),
                        ],
                        if (state.hasContext) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          ReviewWorkflowTabs(
                            controller: _tabController,
                            onTap: _onTabTap,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (_selectedTab == 0) ...<Widget>[
                            CurrentVersionSummary(
                              state: state,
                              onRetry: cubit.loadCurrentVersion,
                              onViewVersions: _showVersions,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ReadinessSummary(
                              state: state,
                              onCheckAgain: cubit.validate,
                              onAssignments: () => _goToAssignments(state),
                              onIssueFiltersChanged:
                                  ({
                                    ValidationSeverity? severity,
                                    String? search,
                                  }) => cubit.setIssueFilters(
                                    severity: severity,
                                    clearSeverity: severity == null,
                                    search: search,
                                  ),
                              onIssueNavigate: _navigateToIssue,
                            ),
                          ] else
                            SizedBox(
                              height: 660,
                              child: _tabPanel(state, cubit),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _tabPanel(MenuReviewState state, MenuReviewCubit cubit) =>
      switch (_selectedTab) {
        1 => MenuPreviewPanel(
          state: state,
          cubit: cubit,
          onReviewReadiness: () => _onTabTap(0),
          onAssignments: () => _goToAssignments(state),
        ),
        2 => PublishPanel(
          state: state,
          cubit: cubit,
          onReviewReadiness: () => _onTabTap(0),
          onAssignments: () => _goToAssignments(state),
          onViewVersions: _showVersions,
        ),
        3 => PublishedVersionHistoryPanel(
          branchId: state.selectedBranch?.id,
          branchName: state.selectedBranch?.name ?? '-',
          channel: state.channel,
        ),
        _ => const SizedBox.shrink(),
      };

  void _showVersions() {
    _tabController.index = 3;
    setState(() => _selectedTab = 3);
  }

  void _onTabTap(int index) {
    _tabController.index = index;
    setState(() => _selectedTab = index);
    if (index == 1) {
      final MenuReviewState state = context.read<MenuReviewCubit>().state;
      if (state.preview == null &&
          state.previewStatus == ReviewRequestStatus.idle) {
        context.read<MenuReviewCubit>().preview();
      }
    }
  }

  void _goToAssignments(MenuReviewState state) {
    final branchId = state.selectedBranch?.id;
    if (branchId == null) return;
    context.go(
      Uri(
        path: AppRoutes.menuManagementAssignments,
        queryParameters: <String, String>{
          'branchId': '$branchId',
          'channel': state.channel,
        },
      ).toString(),
    );
  }

  void _navigateToIssue(ValidationIssue issue, ReadinessIssueAction action) {
    switch (action) {
      case ReadinessIssueAction.openMenu:
        context.go(MenuManagementRouteLocations.menuWorkspace(issue.menuId));
      case ReadinessIssueAction.openProduct:
        final productId = issue.entityId;
        if (productId != null && productId > 0) {
          context.go(MenuManagementRouteLocations.productWorkspace(productId));
        }
      case ReadinessIssueAction.openSections:
        context.go(
          MenuManagementRouteLocations.menuWorkspace(
            issue.menuId,
            tab: MenuWorkspaceTab.sections,
          ),
        );
      case ReadinessIssueAction.reviewMenu:
        context.go(MenuManagementRouteLocations.menuWorkspace(issue.menuId));
      case ReadinessIssueAction.goToAssignments:
        _goToAssignments(context.read<MenuReviewCubit>().state);
      case ReadinessIssueAction.none:
        break;
    }
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(top: 12),
    child: Row(
      children: <Widget>[
        const Icon(Icons.error_outline, color: AppColors.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
