import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../app/localization/localization_extensions.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../assignments/controllers/menu_assignments_cubit.dart'
    show salesChannels;
import '../../widgets/menu_management_tabs.dart';
import '../controllers/menu_review_cubit.dart';
import '../models/review_models.dart';
import '../../versions/views/published_version_history_panel.dart';

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

class _MenuReviewScreenState extends State<MenuReviewScreen> {
  @override
  void initState() {
    super.initState();
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
  Widget build(
    BuildContext context,
  ) => BlocBuilder<MenuReviewCubit, MenuReviewState>(
    builder: (context, state) {
      final MenuReviewCubit cubit = context.read<MenuReviewCubit>();
      return DesktopPageLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Menu Management',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review & Preview',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const MenuManagementTabs(selected: 'review'),
              const SizedBox(height: 20),
              AppCard(child: Text(context.l10n.reviewWorkflowHelp)),
              const SizedBox(height: 12),
              _ContextPanel(state: state, cubit: cubit),
              if (state.contextError != null)
                _ErrorCard(
                  message: state.contextError!,
                  onRetry: () => cubit.load(
                    branchId: state.selectedBranch?.id,
                    channel: state.channel,
                    menuId: state.menuId,
                  ),
                ),
              if (state.contextStatus == ReviewLoadStatus.loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.branches.isEmpty)
                const _MessageCard(
                  'No active branches are available for menu review.',
                )
              else if (state.hasContext) ...<Widget>[
                if (state.eligibleMenus.isEmpty)
                  const _MessageCard(
                    'No assigned Menus are available for the selected Branch and Sales Channel.',
                  ),
                const SizedBox(height: 20),
                DefaultTabController(
                  length: 4,
                  initialIndex: widget.showVersions ? 3 : 0,
                  child: Column(
                    children: <Widget>[
                      TabBar(
                        tabs: <Widget>[
                          Tab(text: context.l10n.reviewCheckMenu),
                          Tab(text: context.l10n.reviewPreviewStep),
                          Tab(text: context.l10n.reviewPublishStep),
                          Tab(text: context.l10n.reviewVersionsStep),
                        ],
                      ),
                      SizedBox(
                        height: 660,
                        child: TabBarView(
                          children: <Widget>[
                            _ValidationPanel(state: state, cubit: cubit),
                            _PreviewPanel(state: state, cubit: cubit),
                            _PublishPanel(state: state, cubit: cubit),
                            PublishedVersionHistoryPanel(
                              branchId: state.selectedBranch?.id,
                              branchName: state.selectedBranch?.name ?? '-',
                              channel: state.channel,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({required this.state, required this.cubit});
  final MenuReviewState state;
  final MenuReviewCubit cubit;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 230,
          child: DropdownButtonFormField<int>(
            initialValue: state.selectedBranch?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Branch'),
            items: state.branches
                .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                .toList(),
            onChanged: state.isBusy
                ? null
                : (v) {
                    if (v != null) cubit.selectBranch(v);
                  },
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            initialValue: state.channel,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sales channel'),
            items: salesChannels
                .map((c) => DropdownMenuItem(value: c, child: Text(_label(c))))
                .toList(),
            onChanged: state.isBusy
                ? null
                : (v) {
                    if (v != null) cubit.selectChannel(v);
                  },
          ),
        ),
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<int?>(
            initialValue: state.menuId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Scope'),
            items: <DropdownMenuItem<int?>>[
              const DropdownMenuItem(
                value: null,
                child: Text(
                  'Complete assigned Menu collection',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...state.eligibleMenus.map(
                (a) => DropdownMenuItem(
                  value: a.menuId,
                  child: Text(
                    a.menu?.localizedName ?? 'Menu #${a.menuId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: state.isBusy ? null : cubit.selectScope,
          ),
        ),
        OutlinedButton.icon(
          onPressed: state.isBusy
              ? null
              : () => cubit.load(
                  branchId: state.selectedBranch?.id,
                  channel: state.channel,
                  menuId: state.menuId,
                  evaluationAt: state.evaluationAt,
                ),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh context'),
        ),
      ],
    ),
  );
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.state, required this.cubit});
  final MenuReviewState state;
  final MenuReviewCubit cubit;
  @override
  Widget build(BuildContext context) {
    final MenuValidationResult? result = state.validation;
    return ListView(
      padding: const EdgeInsets.only(top: 20),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                state.isCollection
                    ? 'Complete assigned Menu collection'
                    : 'Menu #${state.menuId}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton.icon(
              onPressed: state.validationStatus == ReviewRequestStatus.loading
                  ? null
                  : cubit.validate,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                result == null ? 'Run Validation' : 'Refresh Validation',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.validationStatus == ReviewRequestStatus.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (state.validationError != null)
          _ErrorCard(message: state.validationError!, onRetry: cubit.validate)
        else if (result == null)
          const _MessageCard(
            'Run validation to review publishability and diagnostics.',
          )
        else ...<Widget>[
          _ValidationSummary(result: result),
          const SizedBox(height: 16),
          _IssueFilters(state: state, cubit: cubit),
          const SizedBox(height: 12),
          if (state.filteredIssues.isEmpty)
            const _MessageCard(
              'No validation issues were found for the selected scope.',
            )
          else
            ..._issueGroups(context, state.filteredIssues),
        ],
      ],
    );
  }
}

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.result});
  final MenuValidationResult result;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          result.canPublish ? 'Can Publish' : 'Cannot Publish',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: result.canPublish ? AppColors.success : AppColors.danger,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          result.canPublish
              ? context.l10n.validationNoBlockingErrors
              : context.l10n.validationResolveErrors,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: <Widget>[
            _Count(
              label: 'Errors',
              count: result.errorCount,
              color: AppColors.danger,
            ),
            _Count(
              label: 'Warnings',
              count: result.warningCount,
              color: AppColors.warning,
            ),
            _Count(
              label: 'Information',
              count: result.informationCount,
              color: AppColors.info,
            ),
          ],
        ),
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text('$label: $count'),
    side: BorderSide(color: color),
  );
}

class _IssueFilters extends StatelessWidget {
  const _IssueFilters({required this.state, required this.cubit});
  final MenuReviewState state;
  final MenuReviewCubit cubit;
  @override
  Widget build(BuildContext context) {
    final types =
        state.validation?.issues.map((i) => i.entityType).toSet().toList() ??
        const <String>[];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: <Widget>[
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<ValidationSeverity?>(
            initialValue: state.severityFilter,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: <DropdownMenuItem<ValidationSeverity?>>[
              const DropdownMenuItem(
                value: null,
                child: Text('All severities'),
              ),
              ...ValidationSeverity.values.map(
                (s) => DropdownMenuItem(value: s, child: Text(_label(s.name))),
              ),
            ],
            onChanged: (v) =>
                cubit.setIssueFilters(severity: v, clearSeverity: v == null),
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String?>(
            initialValue: state.entityTypeFilter,
            decoration: const InputDecoration(labelText: 'Entity type'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem(
                value: null,
                child: Text('All entity types'),
              ),
              ...types.map(
                (t) => DropdownMenuItem(value: t, child: Text(_label(t))),
              ),
            ],
            onChanged: (v) => cubit.setIssueFilters(
              entityType: v,
              clearEntityType: v == null,
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: TextFormField(
            initialValue: state.search,
            onChanged: (v) => cubit.setIssueFilters(search: v),
            decoration: const InputDecoration(
              labelText: 'Search issue code or message',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
      ],
    );
  }
}

Iterable<Widget> _issueGroups(
  BuildContext context,
  List<ValidationIssue> issues,
) sync* {
  for (final severity in <ValidationSeverity>[
    ValidationSeverity.error,
    ValidationSeverity.warning,
    ValidationSeverity.information,
    ValidationSeverity.unknown,
  ]) {
    final group = issues.where((i) => i.severityValue == severity).toList();
    if (group.isEmpty) continue;
    yield Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        _label(severity.name),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
    for (final issue in group) {
      yield _IssueCard(issue: issue);
    }
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});
  final ValidationIssue issue;
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Chip(
          label: Text(_label(issue.severity)),
          backgroundColor: _severityColor(issue.severityValue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                issue.message,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                context.l10n.validationIssueCode(issue.code),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Entity: ${_label(issue.entityType)}${issue.entityId == null ? '' : ' #${issue.entityId}'} · Menu #${issue.menuId}${issue.sectionId == null ? '' : ' · Section #${issue.sectionId}'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (issue.entityType == 'product' && issue.entityId != null)
          TextButton(
            onPressed: () =>
                context.go('/menu-management/products/${issue.entityId}'),
            child: const Text('Open Product'),
          )
        else if (issue.entityType == 'menu' ||
            issue.entityType == 'section' ||
            issue.entityType == 'placement')
          TextButton(
            onPressed: () =>
                context.go('/menu-management/menus/${issue.menuId}'),
            child: const Text('Open Menu'),
          ),
      ],
    ),
  );
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.state, required this.cubit});
  final MenuReviewState state;
  final MenuReviewCubit cubit;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(top: 20),
    children: <Widget>[
      FilledButton.icon(
        onPressed: state.previewStatus == ReviewRequestStatus.loading
            ? null
            : cubit.preview,
        icon: const Icon(Icons.visibility_outlined),
        label: Text(state.preview == null ? 'Load Preview' : 'Refresh Preview'),
      ),
      const SizedBox(height: 12),
      Text(
        context.l10n.reviewAdvancedOptions,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              initialValue: state.language,
              decoration: const InputDecoration(labelText: 'Language'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'default', child: Text('Default')),
                DropdownMenuItem(value: 'ar', child: Text('Arabic')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                if (v != null) cubit.setLanguage(v);
              },
            ),
          ),
          FilterChip(
            label: const Text('Include hidden'),
            selected: state.includeHidden,
            onSelected: cubit.setIncludeHidden,
          ),
          FilterChip(
            label: const Text('Include unavailable'),
            selected: state.includeUnavailable,
            onSelected: cubit.setIncludeUnavailable,
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (state.validation?.canPublish == false)
        const _MessageCard(
          'Preview is diagnostic. This selected scope cannot be published until Backend validation passes.',
        ),
      if (state.previewStatus == ReviewRequestStatus.loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        )
      else if (state.previewError != null)
        _ErrorCard(message: state.previewError!, onRetry: cubit.preview)
      else if (state.preview == null)
        const _MessageCard(
          'Load the authoritative resolved Menu preview for the selected scope.',
        )
      else
        _PreviewTree(preview: state.preview!),
    ],
  );
}

class _PublishPanel extends StatelessWidget {
  const _PublishPanel({required this.state, required this.cubit});

  final MenuReviewState state;
  final MenuReviewCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final MenuValidationResult? validation = state.validation;
    final bool validationReady =
        state.validationStatus == ReviewRequestStatus.loaded &&
        validation != null;
    final bool canPublish = validationReady && validation.canPublish;
    final String scope = state.isCollection
        ? l10n.menuPublishCollectionScope
        : '${l10n.menuPublishOneMenu} #${state.menuId}';
    return ListView(
      padding: const EdgeInsets.only(top: 20),
      children: <Widget>[
        AppCard(
          child: Wrap(
            spacing: 16,
            runSpacing: 10,
            children: <Widget>[
              _PublishDetail(
                label: l10n.menuPublishBranch,
                value: state.selectedBranch?.name ?? '-',
              ),
              _PublishDetail(
                label: l10n.menuPublishChannel,
                value: _label(state.channel),
              ),
              _PublishDetail(label: l10n.menuPublishScope, value: scope),
              _PublishDetail(
                label: l10n.menuPublishValidation,
                value: !validationReady
                    ? l10n.menuPublishValidationRequired
                    : validation.canPublish
                    ? l10n.menuPublishCanPublish
                    : l10n.menuPublishCannotPublish,
              ),
              _PublishDetail(
                label: l10n.menuPublishErrors,
                value: '${validation?.errorCount ?? 0}',
              ),
              _PublishDetail(
                label: l10n.menuPublishWarnings,
                value: '${validation?.warningCount ?? 0}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CurrentVersionPanel(state: state, cubit: cubit),
        const SizedBox(height: 12),
        if (!validationReady)
          _MessageCard(l10n.menuPublishRunValidationFirst)
        else if (!canPublish)
          _MessageCard(l10n.menuPublishBlockedByValidation)
        else if (validation.warningCount > 0)
          _MessageCard(l10n.menuPublishWarningsAllowed),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed:
              !canPublish ||
                  state.publicationStatus == PublicationActionStatus.publishing
              ? null
              : () => _confirmPublish(context, scope),
          icon: state.publicationStatus == PublicationActionStatus.publishing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.publish_outlined),
          label: Text(
            state.publicationStatus == PublicationActionStatus.publishing
                ? l10n.menuPublishPublishing
                : l10n.menuPublishAction,
          ),
        ),
        if (state.publicationError != null) ...<Widget>[
          const SizedBox(height: 12),
          _MessageCard(state.publicationError!),
        ],
        if (state.publicationStatus ==
            PublicationActionStatus.validationBlocked) ...<Widget>[
          const SizedBox(height: 12),
          _MessageCard(l10n.menuPublishBackendBlocked),
          if (state.validation != null)
            ..._issueGroups(context, state.validation!.issues),
        ],
        if (state.lastPublication != null) ...<Widget>[
          const SizedBox(height: 12),
          _PublicationResultCard(result: state.lastPublication!),
        ],
      ],
    );
  }

  Future<void> _confirmPublish(BuildContext context, String scope) async {
    final l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.menuPublishConfirmTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${l10n.menuPublishBranch}: ${state.selectedBranch?.name ?? '-'}',
                ),
                Text('${l10n.menuPublishChannel}: ${_label(state.channel)}'),
                Text('${l10n.menuPublishScope}: $scope'),
                Text(
                  '${l10n.menuPublishWarnings}: ${state.validation?.warningCount ?? 0}',
                ),
                if (state.currentVersion != null)
                  Text(
                    '${l10n.menuPublishCurrentVersion}: ${state.currentVersion!.versionNumber}',
                  ),
                const SizedBox(height: 16),
                Text(l10n.menuPublishConfirmationExplanation),
                if ((state.validation?.warningCount ?? 0) > 0) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    l10n.menuPublishWarningsAllowed,
                    style: const TextStyle(color: AppColors.warning),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.menuPublishAction),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) cubit.publish();
  }
}

class _CurrentVersionPanel extends StatelessWidget {
  const _CurrentVersionPanel({required this.state, required this.cubit});

  final MenuReviewState state;
  final MenuReviewCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.currentVersionStatus == ReviewRequestStatus.loading) {
      return AppCard(
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(l10n.menuPublishLoadingCurrentVersion),
          ],
        ),
      );
    }
    if (state.currentVersionStatus == ReviewRequestStatus.failure) {
      return _ErrorCard(
        message: state.currentVersionError ?? l10n.commonError,
        onRetry: cubit.loadCurrentVersion,
      );
    }
    final PublishedMenuVersion? version = state.currentVersion;
    if (version == null) {
      return AppCard(
        child: Row(
          children: <Widget>[
            Expanded(child: Text(l10n.menuPublishNoCurrentVersion)),
            TextButton(
              onPressed: cubit.loadCurrentVersion,
              child: Text(l10n.commonRefresh),
            ),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.menuPublishCurrentVersion,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: cubit.loadCurrentVersion,
                child: Text(l10n.commonRefresh),
              ),
              TextButton(
                onPressed: () => context.go(
                  '/menu-management/review?branchId=${state.selectedBranch?.id}&channel=${state.channel}&tab=versions',
                ),
                child: const Text('View Version History'),
              ),
            ],
          ),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: <Widget>[
              _PublishDetail(
                label: l10n.menuPublishVersionNumber,
                value: '${version.versionNumber}',
              ),
              _PublishDetail(
                label: l10n.menuPublishStatus,
                value: _label(version.status),
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.technicalDetails),
            children: <Widget>[
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: <Widget>[
                  _PublishDetail(
                    label: l10n.menuPublishPublishedAt,
                    value: version.publishedAt.isEmpty
                        ? '-'
                        : version.publishedAt,
                    technical: true,
                  ),
                  _PublishDetail(
                    label: l10n.menuPublishChecksum,
                    value: version.checksum,
                    technical: true,
                  ),
                  if (version.publicationId != null)
                    _PublishDetail(
                      label: l10n.menuPublishPublicationId,
                      value: '${version.publicationId}',
                      technical: true,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublicationResultCard extends StatelessWidget {
  const _PublicationResultCard({required this.result});
  final MenuPublicationResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            result.noChanges
                ? l10n.menuPublishNoChanges
                : l10n.menuPublishSuccess,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (result.noChanges) Text(l10n.menuPublishNoChangesExplanation),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: <Widget>[
              _PublishDetail(
                label: l10n.menuPublishVersionNumber,
                value: '${result.version.versionNumber}',
              ),
              _PublishDetail(
                label: l10n.menuPublishWarnings,
                value: '${result.validation.warningCount}',
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.technicalDetails),
            children: <Widget>[
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: <Widget>[
                  _PublishDetail(
                    label: l10n.menuPublishPublishedAt,
                    value: result.version.publishedAt,
                    technical: true,
                  ),
                  _PublishDetail(
                    label: l10n.menuPublishChecksum,
                    value: result.version.checksum,
                    technical: true,
                  ),
                  if (result.publicationId != null)
                    _PublishDetail(
                      label: l10n.menuPublishPublicationId,
                      value: '${result.publicationId}',
                      technical: true,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublishDetail extends StatelessWidget {
  const _PublishDetail({
    required this.label,
    required this.value,
    this.technical = false,
  });
  final String label;
  final String value;
  final bool technical;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: technical ? 240 : 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Directionality(
          textDirection: technical
              ? TextDirection.ltr
              : Directionality.of(context),
          child: Text(value, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

class _PreviewTree extends StatelessWidget {
  const _PreviewTree({required this.preview});
  final ResolvedPreview preview;
  @override
  Widget build(BuildContext context) {
    if (preview.menus.isEmpty) {
      return const _MessageCard(
        'No resolved Menu content is available for the selected scope.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Evaluated: ${preview.evaluatedAt.isEmpty ? 'Backend current time' : preview.evaluatedAt} · ${preview.timezone}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        ...preview.menus.map((menu) => _MenuTree(menu: menu)),
      ],
    );
  }
}

class _MenuTree extends StatelessWidget {
  const _MenuTree({required this.menu});
  final ResolvedMenu menu;
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      initiallyExpanded: true,
      title: Text(
        menu.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Assignment order ${menu.priority} · ${menu.isAssigned ? 'Assigned' : 'Not assigned'} · Schedule: ${menu.isScheduledAvailable ? 'Available' : menu.scheduleReason}',
      ),
      children: menu.sections
          .map(
            (section) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: ExpansionTile(
                title: Text('${section.sortOrder}. ${section.name}'),
                children: section.products
                    .map((product) => _ProductTree(product: product))
                    .toList(),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _ProductTree extends StatelessWidget {
  const _ProductTree({required this.product});
  final ResolvedProduct product;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(product.name),
    subtitle: Text(
      'Scheduled: ${_yesNo(product.isScheduledAvailable)} · Operational: ${_yesNo(product.isOperationallyAvailable)} · Sellable: ${_yesNo(product.isSellable)}${product.reasons.isEmpty ? '' : ' · ${product.reasons.join(', ')}'}',
    ),
    children: <Widget>[
      ...product.variants.map(
        (variant) => ListTile(
          title: Text(variant.name),
          subtitle: Text(
            'Effective price: ${CurrencyFormatter.format(variant.effectivePrice)} (${variant.priceScope}) · Scheduled: ${_yesNo(variant.isScheduledAvailable)} · Operational: ${_yesNo(variant.isOperationallyAvailable)} · Sellable: ${_yesNo(variant.isSellable)}${variant.reasons.isEmpty ? '' : ' · ${variant.reasons.join(', ')}'}${variant.isDefault ? ' · Default' : ''}',
          ),
        ),
      ),
      ...product.modifiers.map(
        (group) => ExpansionTile(
          title: Text('Modifier: ${group.name}'),
          subtitle: Text(
            '${group.isRequired ? 'Required' : 'Optional'} · ${group.minSelections}–${group.maxSelections} · Quantity: ${_yesNo(group.allowQuantity)}',
          ),
          children: group.options
              .map(
                (option) => ListTile(
                  title: Text(option.name),
                  subtitle: Text(
                    'Price delta: ${CurrencyFormatter.format(option.priceDelta)} · Available: ${_yesNo(option.isAvailable)}',
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
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

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) =>
      AppCard(margin: const EdgeInsets.only(top: 12), child: Text(message));
}

Color _severityColor(ValidationSeverity severity) => switch (severity) {
  ValidationSeverity.error => const Color(0xFFFFE5E3),
  ValidationSeverity.warning => const Color(0xFFFFE6D1),
  ValidationSeverity.information => const Color(0xFFE4EEFF),
  ValidationSeverity.unknown => AppColors.surfaceAlt,
};
String _yesNo(bool value) => value ? 'Available' : 'Unavailable';
String _label(String value) => value
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
