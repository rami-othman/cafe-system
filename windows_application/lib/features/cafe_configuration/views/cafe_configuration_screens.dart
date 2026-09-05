import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../controllers/cafe_configuration_cubits.dart';
import '../controllers/cafe_configuration_overview_cubit.dart';
import '../models/cafe_configuration_models.dart';
import '../widgets/cafe_configuration_form_widgets.dart';

class CafeConfigurationOverviewScreen extends StatelessWidget {
  const CafeConfigurationOverviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final _Copy c = _Copy(context);
    return BlocBuilder<
      CafeConfigurationOverviewCubit,
      CafeConfigurationOverviewState
    >(
      builder: (context, state) {
        if (state.status == CafeConfigurationLoadStatus.failure) {
          return FeatureError(
            title: c.overview,
            message: c.couldNotLoad,
            retryLabel: c.retry,
            onRetry: () =>
                context.read<CafeConfigurationOverviewCubit>().load(),
          );
        }
        final List<_OverviewCard> cards = <_OverviewCard>[
          _OverviewCard(
            icon: Icons.storefront_outlined,
            title: c.profile,
            value: state.profile?.name ?? '—',
            detail: state.profile == null ? c.loading : c.configured,
            route: '/cafe-configuration/profile',
          ),
          _OverviewCard(
            icon: Icons.account_tree_outlined,
            title: c.branches,
            value: state.status == CafeConfigurationLoadStatus.loading
                ? '—'
                : '${state.branches.where((b) => b.isActive).length} ${c.active}',
            detail: state.status == CafeConfigurationLoadStatus.loading
                ? c.loading
                : '${state.branches.length} ${c.total}',
            route: '/cafe-configuration/branches',
          ),
          _OverviewCard(
            icon: Icons.groups_outlined,
            title: c.team,
            value: state.status == CafeConfigurationLoadStatus.loading
                ? 'â€”'
                : '${state.activeTeamCount} ${c.active}',
            detail: state.status == CafeConfigurationLoadStatus.loading
                ? c.loading
                : '${state.teamCount} ${c.total}',
            route: '/cafe-configuration/team',
          ),
          _OverviewCard(
            icon: Icons.percent_outlined,
            title: c.tax,
            value: state.tax == null
                ? 'â€”'
                : '${state.tax!.percentage.toStringAsFixed(2)} %',
            detail: state.tax == null ? c.loading : c.taxSummary,
            route: '/cafe-configuration/tax',
          ),
        ];
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(title: c.overview, subtitle: c.overviewSubtitle),
              const SizedBox(height: AppSpacing.xl),
              Skeletonizer(
                enabled: state.status == CafeConfigurationLoadStatus.loading,
                child: LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: cards
                        .map(
                          (card) => SizedBox(
                            width: constraints.maxWidth >= 900
                                ? (constraints.maxWidth - AppSpacing.lg) / 2
                                : constraints.maxWidth,
                            child: card,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CafeProfileScreen extends StatefulWidget {
  const CafeProfileScreen({super.key});
  @override
  State<CafeProfileScreen> createState() => _CafeProfileScreenState();
}

class _CafeProfileScreenState extends State<CafeProfileScreen> {
  final TextEditingController _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController();
  bool _seeded = false;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _seed(CafeProfileDraft d) {
    if (_seeded) return;
    _seeded = true;
    _name.text = d.name;
    _email.text = d.email;
    _phone.text = d.phone;
  }

  @override
  Widget build(BuildContext context) {
    final _Copy c = _Copy(context);
    return BlocConsumer<CafeProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state.status == CafeConfigurationLoadStatus.success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(c.profileSaved)));
        }
      },
      builder: (context, state) {
        if (state.profile == null &&
            state.status == CafeConfigurationLoadStatus.failure) {
          return FeatureError(
            title: c.profile,
            message: c.couldNotLoad,
            retryLabel: c.retry,
            onRetry: () => context.read<CafeProfileCubit>().load(),
          );
        }
        if (state.profile == null) return const _FormSkeleton();
        _seed(state.draft);
        final CafeProfileCubit cubit = context.read<CafeProfileCubit>();
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(title: c.profile, subtitle: c.profileSubtitle),
              const SizedBox(height: AppSpacing.xl),
              _ErrorBanner(
                show:
                    state.status == CafeConfigurationLoadStatus.failure &&
                    state.errorMessage == 'save',
                text: c.saveFailed,
              ),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      c.businessInformation,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _name,
                      label: c.cafeName,
                      onChanged: (v) =>
                          cubit.update(state.draft.copyWith(name: v)),
                    ),
                    _FieldError(state.errors['name']),
                    const SizedBox(height: AppSpacing.lg),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: AppTextField(
                        controller: _email,
                        label: c.email,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (v) =>
                            cubit.update(state.draft.copyWith(email: v)),
                      ),
                    ),
                    _FieldError(state.errors['email']),
                    const SizedBox(height: AppSpacing.lg),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: AppTextField(
                        controller: _phone,
                        label: c.phone,
                        keyboardType: TextInputType.phone,
                        onChanged: (v) =>
                            cubit.update(state.draft.copyWith(phone: v)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: IanaTimezoneField(
                        label: c.timezone,
                        value: state.draft.timezone,
                        errorText: state.errors['timezone'],
                        onChanged: (v) =>
                            cubit.update(state.draft.copyWith(timezone: v)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      c.readOnly,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xxl,
                      runSpacing: AppSpacing.lg,
                      children: <Widget>[
                        _Fact(
                          label: c.currency,
                          value: state.profile!.currency,
                        ),
                        _Fact(
                          label: c.status,
                          child: CafeStatusBadge(
                            active:
                                state.profile!.status.toLowerCase() == 'active',
                            activeLabel: c.active,
                            inactiveLabel: state.profile!.status,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Actions(
                dirty: state.isDirty,
                saving: state.status == CafeConfigurationLoadStatus.submitting,
                resetLabel: c.reset,
                saveLabel: c.saveChanges,
                onReset: () {
                  cubit.reset();
                  _seeded = false;
                },
                onSave: cubit.save,
              ),
            ],
          ),
        );
      },
    );
  }
}

class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final _Copy c = _Copy(context);
    return BlocBuilder<CafeBranchesCubit, BranchesState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Header(
              title: c.branches,
              subtitle: c.branchesSubtitle,
              action: FilledButton.icon(
                onPressed: () => context.go('/cafe-configuration/branches/new'),
                icon: const Icon(Icons.add),
                label: Text(c.addBranch),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: state.status == CafeConfigurationLoadStatus.failure
                  ? FeatureError(
                      title: c.branches,
                      message: c.couldNotLoad,
                      retryLabel: c.retry,
                      onRetry: () => context.read<CafeBranchesCubit>().load(),
                    )
                  : state.status == CafeConfigurationLoadStatus.loading
                  ? const _BranchesSkeleton()
                  : state.branches.isEmpty
                  ? _EmptyBranches(copy: c)
                  : _BranchesTable(branches: state.branches, copy: c),
            ),
          ],
        );
      },
    );
  }
}

class BranchEditorScreen extends StatefulWidget {
  const BranchEditorScreen({super.key, required this.isEdit});
  final bool isEdit;
  @override
  State<BranchEditorScreen> createState() => _BranchEditorScreenState();
}

class _BranchEditorScreenState extends State<BranchEditorScreen> {
  final TextEditingController _name = TextEditingController(),
      _address = TextEditingController(),
      _phone = TextEditingController();
  bool _seeded = false;
  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _seed(BranchDraft d) {
    if (_seeded) return;
    _seeded = true;
    _name.text = d.name;
    _address.text = d.address;
    _phone.text = d.phone;
  }

  @override
  Widget build(BuildContext context) {
    final _Copy c = _Copy(context);
    return BlocConsumer<BranchEditorCubit, BranchEditorState>(
      listener: (context, state) {
        if (state.status == CafeConfigurationLoadStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isEdit ? c.branchSaved : c.branchCreated),
            ),
          );
          context.go('/cafe-configuration/branches');
        }
      },
      builder: (context, state) {
        if (state.status == CafeConfigurationLoadStatus.loading) {
          return const _FormSkeleton();
        }
        if (state.branch == null &&
            widget.isEdit &&
            state.status == CafeConfigurationLoadStatus.failure) {
          return FeatureError(
            title: c.editBranch,
            message: c.couldNotLoad,
            retryLabel: c.retry,
            onRetry: () => context.read<BranchEditorCubit>().initialize(),
          );
        }
        _seed(state.draft);
        final BranchEditorCubit cubit = context.read<BranchEditorCubit>();
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(
                title: widget.isEdit ? c.editBranch : c.createBranch,
                subtitle: widget.isEdit
                    ? c.editBranchSubtitle
                    : c.createBranchSubtitle,
              ),
              const SizedBox(height: AppSpacing.xl),
              _ErrorBanner(
                show:
                    state.status == CafeConfigurationLoadStatus.failure &&
                    state.errorMessage == 'save',
                text: c.saveFailed,
              ),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppTextField(
                      controller: _name,
                      label: '${c.branchName} *',
                      onChanged: (v) =>
                          cubit.update(state.draft.copyWith(name: v)),
                    ),
                    _FieldError(state.errors['name']),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _address,
                      label: c.address,
                      maxLines: 3,
                      onChanged: (v) =>
                          cubit.update(state.draft.copyWith(address: v)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: AppTextField(
                        controller: _phone,
                        label: c.phone,
                        keyboardType: TextInputType.phone,
                        onChanged: (v) =>
                            cubit.update(state.draft.copyWith(phone: v)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: IanaTimezoneField(
                        label: '${c.timezone} *',
                        value: state.draft.timezone,
                        errorText: state.errors['timezone'],
                        onChanged: (v) =>
                            cubit.update(state.draft.copyWith(timezone: v)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),
                    _Fact(
                      label: c.currency,
                      value: state.branch?.currency ?? 'SYP',
                    ),
                    if (state.branch != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      _Fact(
                        label: c.status,
                        child: CafeStatusBadge(
                          active: state.branch!.isActive,
                          activeLabel: c.active,
                          inactiveLabel: c.inactive,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Actions(
                dirty: state.isDirty || !widget.isEdit,
                saving: state.status == CafeConfigurationLoadStatus.submitting,
                resetLabel: c.cancel,
                saveLabel: widget.isEdit ? c.saveChanges : c.createBranch,
                onReset: () {
                  if (widget.isEdit) {
                    cubit.reset();
                    _seeded = false;
                  } else {
                    context.go('/cafe-configuration/branches');
                  }
                },
                onSave: cubit.save,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final Widget heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
      return constraints.maxWidth < 700 || action == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                heading,
                if (action != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  action!,
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: heading),
                action!,
              ],
            );
    },
  );
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    this.route,
  });
  final IconData icon;
  final String title, value, detail;
  final String? route;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: route == null ? null : () => context.go(route!),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (route != null)
              const Icon(Icons.arrow_forward_ios_outlined, size: 16),
          ],
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, this.value, this.child});
  final String label;
  final String? value;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: AppSpacing.xs),
      if (child != null)
        child!
      else
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            value ?? '—',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
    ],
  );
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.error);
  final String? error;
  @override
  Widget build(BuildContext context) => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
          child: Text(
            error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
        );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.show, required this.text});
  final bool show;
  final String text;
  @override
  Widget build(BuildContext context) => show
      ? Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.refundWarningBackground,
            child: Row(
              children: <Widget>[
                const Icon(Icons.error_outline, color: AppColors.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(text)),
              ],
            ),
          ),
        )
      : const SizedBox.shrink();
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.dirty,
    required this.saving,
    required this.resetLabel,
    required this.saveLabel,
    required this.onReset,
    required this.onSave,
  });
  final bool dirty, saving;
  final String resetLabel, saveLabel;
  final VoidCallback onReset;
  final Future<void> Function() onSave;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      if (dirty && !saving)
        Expanded(
          child: Text(
            'Unsaved changes',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
          ),
        )
      else
        const Spacer(),
      TextButton(onPressed: saving ? null : onReset, child: Text(resetLabel)),
      const SizedBox(width: AppSpacing.sm),
      FilledButton(
        onPressed: dirty && !saving ? onSave : null,
        child: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(saveLabel),
      ),
    ],
  );
}

class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();
  @override
  Widget build(BuildContext context) => Skeletonizer(
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Header(title: 'Loading', subtitle: 'Loading configuration…'),
          const SizedBox(height: AppSpacing.xl),
          _Panel(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < 4; i++)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
                    child: TextField(
                      decoration: InputDecoration(labelText: 'Loading field'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BranchesSkeleton extends StatelessWidget {
  const _BranchesSkeleton();
  @override
  Widget build(BuildContext context) => Skeletonizer(
    child: _Panel(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < 4; i++)
            const ListTile(
              title: Text('Downtown branch'),
              subtitle: Text('Address • Asia/Damascus'),
              trailing: Icon(Icons.edit_outlined),
            ),
        ],
      ),
    ),
  );
}

class _EmptyBranches extends StatelessWidget {
  const _EmptyBranches({required this.copy});
  final _Copy copy;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.account_tree_outlined,
          size: 42,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(copy.noBranches, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          copy.noBranchesHelp,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () => context.go('/cafe-configuration/branches/new'),
          icon: const Icon(Icons.add),
          label: Text(copy.addBranch),
        ),
      ],
    ),
  );
}

class _BranchesTable extends StatelessWidget {
  const _BranchesTable({required this.branches, required this.copy});
  final List<CafeConfigurationBranch> branches;
  final _Copy copy;
  @override
  Widget build(BuildContext context) => _Panel(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 980,
        child: Column(
          children: <Widget>[
            _BranchLine(header: true, copy: copy),
            for (final b in branches) _BranchLine(branch: b, copy: copy),
          ],
        ),
      ),
    ),
  );
}

class _BranchLine extends StatelessWidget {
  const _BranchLine({this.branch, required this.copy, this.header = false});
  final CafeConfigurationBranch? branch;
  final _Copy copy;
  final bool header;
  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {int flex = 1, Widget? child}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: child ?? Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
    if (header) {
      return Container(
        color: AppColors.menuTableHeader,
        child: Row(
          children: <Widget>[
            cell(copy.branchName, flex: 18),
            cell(copy.address, flex: 22),
            cell(copy.phone, flex: 16),
            cell(copy.timezone, flex: 18),
            cell(copy.status, flex: 12),
            cell(copy.team, flex: 10),
            cell(copy.actions, flex: 8),
          ],
        ),
      );
    }
    final b = branch!;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          cell(b.name, flex: 18),
          cell(b.address ?? '—', flex: 22),
          cell(b.phone ?? '—', flex: 16),
          cell(b.timezone, flex: 18),
          cell(
            '',
            flex: 12,
            child: CafeStatusBadge(
              active: b.isActive,
              activeLabel: copy.active,
              inactiveLabel: copy.inactive,
            ),
          ),
          cell(copy.notAvailable, flex: 10),
          cell(
            '',
            flex: 8,
            child: IconButton(
              tooltip: copy.edit,
              onPressed: () =>
                  context.go('/cafe-configuration/branches/${b.id}/edit'),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _Copy {
  const _Copy(this.context);
  final BuildContext context;
  String get overview =>
      context.maybeL10n?.cafeConfigurationOverview ?? 'Overview';
  String get profile =>
      context.maybeL10n?.cafeConfigurationProfile ?? 'Cafe Profile';
  String get branches =>
      context.maybeL10n?.cafeConfigurationBranches ?? 'Branches';
  String get team =>
      context.maybeL10n?.cafeConfigurationTeamAccess ?? 'Team & Access';
  String get tax => context.maybeL10n?.cafeConfigurationTax ?? 'Tax';
  String get overviewSubtitle =>
      context.maybeL10n?.cafeConfigurationOverviewSubtitle ??
      'A concise summary of your cafe’s operational configuration.';
  String get profileSubtitle =>
      context.maybeL10n?.cafeConfigurationProfileSubtitle ??
      'Manage the core business information used across Cafe System.';
  String get branchesSubtitle =>
      context.maybeL10n?.cafeConfigurationBranchesSubtitle ??
      'Create and manage the physical locations where your cafe operates.';
  String get createBranchSubtitle =>
      context.maybeL10n?.cafeConfigurationCreateBranchSubtitle ??
      'Add a new location where your cafe operates.';
  String get editBranchSubtitle =>
      context.maybeL10n?.cafeConfigurationEditBranchSubtitle ??
      'Update the details for this cafe location.';
  String get configured =>
      context.maybeL10n?.cafeConfigurationConfigured ?? 'Configured';
  String get active => context.maybeL10n?.commonActive ?? 'Active';
  String get inactive => context.maybeL10n?.commonInactive ?? 'Inactive';
  String get total => context.maybeL10n?.cafeConfigurationTotal ?? 'total';
  String get notAvailable =>
      context.maybeL10n?.cafeConfigurationNotAvailable ?? 'Not available';
  String get taxSummary =>
      context.maybeL10n?.cafeConfigurationTaxSummary ??
      'Cafe-wide exclusive tax';
  String get loading => context.maybeL10n?.commonLoading ?? 'Loading…';
  String get retry => context.maybeL10n?.commonRetry ?? 'Retry';
  String get couldNotLoad =>
      context.maybeL10n?.cafeConfigurationCouldNotLoad ??
      'Could not load configuration. Check your connection and try again.';
  String get businessInformation =>
      context.maybeL10n?.cafeConfigurationBusinessInformation ??
      'Business information';
  String get cafeName =>
      context.maybeL10n?.cafeConfigurationCafeName ?? 'Cafe Name';
  String get email => context.maybeL10n?.cafeConfigurationEmail ?? 'Email';
  String get phone => context.maybeL10n?.cafeConfigurationPhone ?? 'Phone';
  String get timezone =>
      context.maybeL10n?.cafeConfigurationTimezone ?? 'Timezone';
  String get readOnly =>
      context.maybeL10n?.cafeConfigurationReadOnly ?? 'Read-only';
  String get currency =>
      context.maybeL10n?.cafeConfigurationCurrency ?? 'Currency';
  String get status => context.maybeL10n?.cafeConfigurationStatus ?? 'Status';
  String get reset => context.maybeL10n?.cafeConfigurationReset ?? 'Reset';
  String get cancel => context.maybeL10n?.commonCancel ?? 'Cancel';
  String get saveChanges =>
      context.maybeL10n?.cafeConfigurationSaveChanges ?? 'Save Changes';
  String get profileSaved =>
      context.maybeL10n?.cafeConfigurationProfileSaved ?? 'Cafe profile saved.';
  String get saveFailed =>
      context.maybeL10n?.cafeConfigurationSaveFailed ??
      'Could not save your changes. Your edits were kept.';
  String get addBranch =>
      context.maybeL10n?.cafeConfigurationAddBranch ?? 'Add Branch';
  String get createBranch =>
      context.maybeL10n?.cafeConfigurationCreateBranch ?? 'Create Branch';
  String get editBranch =>
      context.maybeL10n?.cafeConfigurationEditBranch ?? 'Edit Branch';
  String get branchName =>
      context.maybeL10n?.cafeConfigurationBranchName ?? 'Branch Name';
  String get address =>
      context.maybeL10n?.cafeConfigurationAddress ?? 'Address';
  String get actions =>
      context.maybeL10n?.cafeConfigurationActions ?? 'Actions';
  String get noBranches =>
      context.maybeL10n?.cafeConfigurationNoBranches ?? 'No branches yet';
  String get noBranchesHelp =>
      context.maybeL10n?.cafeConfigurationNoBranchesHelp ??
      'Create your first cafe location to get started.';
  String get branchCreated =>
      context.maybeL10n?.cafeConfigurationBranchCreated ?? 'Branch created.';
  String get branchSaved =>
      context.maybeL10n?.cafeConfigurationBranchSaved ?? 'Branch saved.';
  String get edit => context.maybeL10n?.commonEdit ?? 'Edit';
}
