import 'package:flutter/material.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../models/review_models.dart';
import '../presentation/readiness_issue_filters.dart';
import '../presentation/validation_issue_presentation.dart';

class ReadinessIssueBrowser extends StatefulWidget {
  const ReadinessIssueBrowser({
    super.key,
    required this.validation,
    required this.severityFilter,
    required this.search,
    required this.onFiltersChanged,
    required this.onNavigate,
  });

  final MenuValidationResult validation;
  final ValidationSeverity? severityFilter;
  final String search;
  final void Function({ValidationSeverity? severity, String? search})
  onFiltersChanged;
  final void Function(ValidationIssue issue, ReadinessIssueAction action)
  onNavigate;

  @override
  State<ReadinessIssueBrowser> createState() => _ReadinessIssueBrowserState();
}

class _ReadinessIssueBrowserState extends State<ReadinessIssueBrowser> {
  late final TextEditingController _searchController;
  Set<String> _expandedGroups = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
    _resetExpansion();
  }

  @override
  void didUpdateWidget(covariant ReadinessIssueBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.validation != widget.validation) _resetExpansion();
    if (oldWidget.search != widget.search &&
        _searchController.text != widget.search) {
      _searchController.value = _searchController.value.copyWith(
        text: widget.search,
        selection: TextSelection.collapsed(offset: widget.search.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetExpansion() {
    final List<ReadinessIssueGroup> groups = groupReadinessIssues(
      widget.validation.issues.where(
        (ValidationIssue issue) => issue.code != 'NO_ASSIGNED_MENU',
      ),
    );
    final ReadinessIssueGroup? firstError = groups
        .where(
          (ReadinessIssueGroup group) =>
              group.severity == ValidationSeverity.error,
        )
        .firstOrNull;
    final ReadinessIssueGroup? first = firstError ?? groups.firstOrNull;
    _expandedGroups = first == null ? <String>{} : <String>{first.key};
  }

  void _setSeverity(ValidationSeverity? severity) => widget.onFiltersChanged(
    severity: severity,
    search: _searchController.text,
  );

  void _setSearch(String value) =>
      widget.onFiltersChanged(severity: widget.severityFilter, search: value);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<ValidationIssue> allOrdinaryIssues = widget.validation.issues
        .where((ValidationIssue issue) => issue.code != 'NO_ASSIGNED_MENU')
        .toList(growable: false);
    if (allOrdinaryIssues.isEmpty) return const SizedBox.shrink();
    final List<ValidationIssue> issues = filterReadinessIssues(
      widget.validation.issues,
      severity: widget.severityFilter,
      search: widget.search,
      categoryTitle: (ReadinessIssueCategory category) =>
          _categoryTitle(l10n, category),
    );
    final List<ReadinessIssueGroup> groups = groupReadinessIssues(issues);
    final Widget filterBar = _FilterBar(
      severity: widget.severityFilter,
      controller: _searchController,
      onSeverityChanged: _setSeverity,
      onSearchChanged: _setSearch,
    );
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            filterBar,
            const SizedBox(height: AppSpacing.md),
            _EmptyIssueSearch(),
          ],
        ),
      );
    }

    final bool hasErrors = groups.any(
      (ReadinessIssueGroup group) => group.severity == ValidationSeverity.error,
    );
    final List<Widget> content = <Widget>[filterBar];
    ValidationSeverity? previousSeverity;
    for (final ReadinessIssueGroup group in groups) {
      if (group.severity != previousSeverity) {
        content.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: _SeverityHeading(
              severity: group.severity,
              hasErrors: hasErrors,
            ),
          ),
        );
        previousSeverity = group.severity;
      }
      content.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _IssueGroup(
            group: group,
            expanded: _expandedGroups.contains(group.key),
            onToggle: () => setState(() {
              if (_expandedGroups.contains(group.key)) {
                _expandedGroups.remove(group.key);
              } else {
                _expandedGroups.add(group.key);
              }
            }),
            onNavigate: widget.onNavigate,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.severity,
    required this.controller,
    required this.onSeverityChanged,
    required this.onSearchChanged,
  });

  final ValidationSeverity? severity;
  final TextEditingController controller;
  final ValueChanged<ValidationSeverity?> onSeverityChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget filters = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        _FilterChip(
          label: l10n.reviewIssuesAll,
          selected: severity == null,
          onSelected: () => onSeverityChanged(null),
        ),
        _FilterChip(
          label: l10n.reviewErrors,
          selected: severity == ValidationSeverity.error,
          onSelected: () => onSeverityChanged(ValidationSeverity.error),
        ),
        _FilterChip(
          label: l10n.reviewWarnings,
          selected: severity == ValidationSeverity.warning,
          onSelected: () => onSeverityChanged(ValidationSeverity.warning),
        ),
      ],
    );
    final Widget search = TextField(
      controller: controller,
      onChanged: onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: l10n.reviewSearchIssues,
        prefixIcon: const Icon(Icons.search, size: 19),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.commonClose,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onSearchChanged('');
                },
              ),
        border: const OutlineInputBorder(),
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 580) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              filters,
              const SizedBox(height: AppSpacing.sm),
              search,
            ],
          );
        }
        return Row(
          children: <Widget>[
            filters,
            const SizedBox(width: AppSpacing.md),
            Expanded(child: search),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
    ),
  );
}

class _SeverityHeading extends StatelessWidget {
  const _SeverityHeading({required this.severity, required this.hasErrors});

  final ValidationSeverity severity;
  final bool hasErrors;

  @override
  Widget build(BuildContext context) {
    final bool error = severity == ValidationSeverity.error;
    final Color color = error
        ? AppColors.danger
        : severity == ValidationSeverity.warning
        ? AppColors.warning
        : AppColors.textSecondary;
    return Text(
      _severityTitle(context.l10n, severity),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: color,
        fontWeight: error || hasErrors ? FontWeight.w800 : FontWeight.w700,
      ),
    );
  }
}

class _IssueGroup extends StatelessWidget {
  const _IssueGroup({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onNavigate,
  });

  final ReadinessIssueGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(ValidationIssue issue, ReadinessIssueAction action)
  onNavigate;

  @override
  Widget build(BuildContext context) {
    final bool error = group.severity == ValidationSeverity.error;
    final bool warning = group.severity == ValidationSeverity.warning;
    final Color accent = error
        ? AppColors.danger
        : warning
        ? AppColors.warning
        : AppColors.textSecondary;
    final Color border = error
        ? const Color(0xFFFFC9C5)
        : warning
        ? const Color(0xFFF2D197)
        : AppColors.border;
    final Color background = error
        ? const Color(0xFFFFFBFA)
        : warning
        ? const Color(0xFFFFFCF6)
        : AppColors.surface;
    final String title = _categoryTitle(context.l10n, group.category);
    final String count = context.l10n.reviewIssueCount(group.issues.length);
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(color: border),
      ),
      child: Column(
        children: <Widget>[
          Semantics(
            button: true,
            expanded: expanded,
            label: '$title, $count',
            child: InkWell(
              borderRadius: AppRadius.card,
              onTap: onToggle,
              child: Padding(
                padding: AppSpacing.allMd,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _CountBadge(label: count, color: accent),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            ...group.issues.indexed.map(
              ((int, ValidationIssue) item) => Column(
                children: <Widget>[
                  if (item.$1 > 0)
                    const Divider(height: 1, color: AppColors.border),
                  _IssueRow(
                    issue: item.$2,
                    severity: group.severity,
                    onNavigate: onNavigate,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: AppRadius.pillRadius,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({
    required this.issue,
    required this.severity,
    required this.onNavigate,
  });

  final ValidationIssue issue;
  final ValidationSeverity severity;
  final void Function(ValidationIssue issue, ReadinessIssueAction action)
  onNavigate;

  @override
  Widget build(BuildContext context) {
    final ReadinessIssueAction action = ValidationIssuePresentation.actionFor(
      issue,
    );
    final Color color = severity == ValidationSeverity.error
        ? AppColors.danger
        : severity == ValidationSeverity.warning
        ? AppColors.warning
        : AppColors.textSecondary;
    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          label: _severityTitle(context.l10n, severity),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              end: AppSpacing.sm,
              top: 2,
            ),
            child: Icon(
              severity == ValidationSeverity.error
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color: color,
              size: 18,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Validation messages are backend-authoritative English today.
              // Explicit LTR keeps them readable inside Arabic manager UI.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  issue.message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _issueContext(context.l10n, issue),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
    final Widget? actionButton = action == ReadinessIssueAction.none
        ? null
        : TextButton(
            onPressed: () => onNavigate(issue, action),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(_actionTitle(context.l10n, action)),
          );
    return Padding(
      padding: AppSpacing.allMd,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (actionButton == null) return content;
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                content,
                const SizedBox(height: AppSpacing.xs),
                actionButton,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: content),
              const SizedBox(width: AppSpacing.sm),
              actionButton,
            ],
          );
        },
      ),
    );
  }
}

class _EmptyIssueSearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allLg,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.card,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.reviewNoMatchingIssues,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.reviewTryDifferentSearch,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

String _categoryTitle(dynamic l10n, ReadinessIssueCategory category) =>
    switch (category) {
      ReadinessIssueCategory.menus => l10n.reviewIssueGroupMenus,
      ReadinessIssueCategory.sections => l10n.reviewIssueGroupSections,
      ReadinessIssueCategory.products => l10n.reviewIssueGroupProducts,
      ReadinessIssueCategory.variants => l10n.reviewIssueGroupVariants,
      ReadinessIssueCategory.recipesMaterials =>
        l10n.reviewIssueGroupRecipesMaterials,
      ReadinessIssueCategory.modifiers => l10n.reviewIssueGroupModifiers,
      ReadinessIssueCategory.pricing => l10n.reviewIssueGroupPricing,
      ReadinessIssueCategory.availability => l10n.reviewIssueGroupAvailability,
      ReadinessIssueCategory.assignmentsScope =>
        l10n.reviewIssueGroupAssignmentsScope,
      ReadinessIssueCategory.other => l10n.reviewIssueGroupOther,
    };

String _severityTitle(dynamic l10n, ValidationSeverity severity) =>
    switch (severity) {
      ValidationSeverity.error => l10n.reviewErrors,
      ValidationSeverity.warning => l10n.reviewWarnings,
      _ => l10n.reviewIssueGeneral,
    };

String _actionTitle(dynamic l10n, ReadinessIssueAction action) =>
    switch (action) {
      ReadinessIssueAction.openMenu => l10n.reviewOpenMenu,
      ReadinessIssueAction.openProduct => l10n.reviewOpenProduct,
      ReadinessIssueAction.openSections => l10n.reviewOpenSections,
      ReadinessIssueAction.reviewMenu => l10n.reviewReviewMenu,
      ReadinessIssueAction.goToAssignments => l10n.reviewGoToAssignments,
      ReadinessIssueAction.none => '',
    };

String _issueContext(dynamic l10n, ValidationIssue issue) =>
    switch (issue.entityType) {
      'menu' => l10n.reviewIssueContextMenu,
      'section' => l10n.reviewIssueContextSection,
      'product' => l10n.reviewIssueContextProduct,
      'variant' => l10n.reviewIssueContextVariant,
      'placement' => l10n.reviewIssueContextPlacement,
      'modifier_group' || 'modifier_option' => l10n.reviewIssueContextModifier,
      'recipe' || 'material' => l10n.reviewIssueContextRecipe,
      _ => _contextForCategory(
        l10n,
        ValidationIssuePresentation.categoryFor(issue),
      ),
    };

String _contextForCategory(dynamic l10n, ReadinessIssueCategory category) =>
    switch (category) {
      ReadinessIssueCategory.menus => l10n.reviewIssueContextMenu,
      ReadinessIssueCategory.sections => l10n.reviewIssueContextSection,
      ReadinessIssueCategory.products => l10n.reviewIssueContextProduct,
      ReadinessIssueCategory.variants => l10n.reviewIssueContextVariant,
      ReadinessIssueCategory.recipesMaterials => l10n.reviewIssueContextRecipe,
      ReadinessIssueCategory.modifiers => l10n.reviewIssueContextModifier,
      ReadinessIssueCategory.pricing => l10n.reviewIssueContextVariant,
      ReadinessIssueCategory.availability => l10n.reviewIssueContextProduct,
      ReadinessIssueCategory.assignmentsScope => l10n.reviewIssueContextScope,
      ReadinessIssueCategory.other => l10n.reviewIssueContextGeneral,
    };
