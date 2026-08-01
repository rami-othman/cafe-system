import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../assignments/controllers/menu_assignments_cubit.dart'
    show salesChannels;
import '../../widgets/menu_management_tabs.dart';
import '../controllers/menu_review_cubit.dart';
import '../models/review_models.dart';

class MenuReviewScreen extends StatefulWidget {
  const MenuReviewScreen({super.key, this.branchId, this.channel, this.menuId});
  final int? branchId;
  final String? channel;
  final int? menuId;
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
                  length: 2,
                  child: Column(
                    children: <Widget>[
                      const TabBar(
                        tabs: <Widget>[
                          Tab(text: 'Validation'),
                          Tab(text: 'Resolved Preview'),
                        ],
                      ),
                      SizedBox(
                        height: 660,
                        child: TabBarView(
                          children: <Widget>[
                            _ValidationPanel(state: state, cubit: cubit),
                            _PreviewPanel(state: state, cubit: cubit),
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
            decoration: const InputDecoration(labelText: 'Scope'),
            items: <DropdownMenuItem<int?>>[
              const DropdownMenuItem(
                value: null,
                child: Text('Complete assigned Menu collection'),
              ),
              ...state.eligibleMenus.map(
                (a) => DropdownMenuItem(
                  value: a.menuId,
                  child: Text(a.menu?.localizedName ?? 'Menu #${a.menuId}'),
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
    child: Wrap(
      spacing: 16,
      runSpacing: 10,
      children: <Widget>[
        Chip(
          label: Text(result.canPublish ? 'Can Publish' : 'Cannot Publish'),
          backgroundColor: result.canPublish
              ? AppColors.discountGreenBadge
              : const Color(0xFFFFE5E3),
        ),
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
        const Text('Publishability is authoritative from Backend validation.'),
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
                issue.code,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(issue.message),
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
          FilledButton.icon(
            onPressed: state.previewStatus == ReviewRequestStatus.loading
                ? null
                : cubit.preview,
            icon: const Icon(Icons.visibility_outlined),
            label: Text(
              state.preview == null ? 'Load Preview' : 'Refresh Preview',
            ),
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
