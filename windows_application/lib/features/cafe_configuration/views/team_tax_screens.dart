import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../controllers/tax_cubit.dart';
import '../controllers/team_cubit.dart';
import '../models/cafe_configuration_models.dart';

class TeamAccessScreen extends StatelessWidget {
  const TeamAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final _TeamCopy c = _TeamCopy(context);
    return BlocConsumer<TeamCubit, TeamState>(
      listener: (BuildContext context, TeamState state) {
        if (state.status == TeamLoadStatus.failure &&
            state.errorMessage == 'mutation') {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(c.mutationFailed)));
        }
      },
      builder: (BuildContext context, TeamState state) {
        if (state.status == TeamLoadStatus.failure &&
            state.errorMessage == 'load') {
          return _LoadFailure(
            title: c.title,
            onRetry: () => context.read<TeamCubit>().load(),
          );
        }
        final bool loading =
            state.status == TeamLoadStatus.loading && state.roles.isEmpty;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PageHeader(
                title: c.title,
                subtitle: c.subtitle,
                action: FilledButton.icon(
                  onPressed: loading || state.status == TeamLoadStatus.mutating
                      ? null
                      : () => _showMemberEditor(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(c.addMember),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _TeamFilters(copy: c, state: state),
              const SizedBox(height: AppSpacing.lg),
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (state.members.isEmpty)
                _EmptyTeam(
                  copy: c,
                  filtered:
                      state.search.isNotEmpty ||
                      state.roleFilter != null ||
                      state.statusFilter != null ||
                      state.branchFilter != null,
                )
              else
                _TeamTable(copy: c, state: state),
              if (!loading && state.lastPage > 1) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _Pagination(copy: c, state: state),
              ],
            ],
          ),
        );
      },
    );
  }
}

class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key});
  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  final TextEditingController _rate = TextEditingController();
  bool _seeded = false;
  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _TeamCopy c = _TeamCopy(context);
    return BlocConsumer<TaxCubit, TaxState>(
      listener: (BuildContext context, TaxState state) {
        if (state.tax != null && !_seeded) {
          _seeded = true;
          _rate.text = state.draftPercentage;
        }
        if (state.status == TaxLoadStatus.success) {
          _rate.text = state.draftPercentage;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(c.taxSaved)));
        }
      },
      builder: (BuildContext context, TaxState state) {
        if (state.tax == null && state.status == TaxLoadStatus.failure) {
          return _LoadFailure(
            title: c.tax,
            onRetry: () => context.read<TaxCubit>().load(),
          );
        }
        if (state.tax == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final bool saving = state.status == TaxLoadStatus.saving;
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _PageHeader(title: c.tax, subtitle: c.taxSubtitle),
                  const SizedBox(height: AppSpacing.xl),
                  _Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          c.taxRate,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          c.taxHelp,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: AppTextField(
                                  controller: _rate,
                                  label: c.taxRate,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: context.read<TaxCubit>().update,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsetsDirectional.only(
                                  start: AppSpacing.md,
                                ),
                                child: Text(
                                  '%',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.status == TaxLoadStatus.failure) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            state.error == 'invalid' ||
                                    state.error == 'validation'
                                ? c.taxInvalid
                                : c.mutationFailed,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          c.taxExplanation,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                            onPressed: state.isDirty && !saving
                                ? () => _confirmTax(context, c, state)
                                : null,
                            child: saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(c.save),
                          ),
                        ),
                      ],
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

  Future<void> _confirmTax(
    BuildContext context,
    _TeamCopy c,
    TaxState state,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(c.confirmTax),
        content: Text(
          '${c.current}: ${state.tax!.percentage.toStringAsFixed(2)}%\n${c.newValue}: ${state.draftPercentage}%\n\n${c.newOrdersOnly}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(c.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(c.save),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TaxCubit>().save();
    }
  }
}

class _TeamFilters extends StatefulWidget {
  const _TeamFilters({required this.copy, required this.state});
  final _TeamCopy copy;
  final TeamState state;
  @override
  State<_TeamFilters> createState() => _TeamFiltersState();
}

class _TeamFiltersState extends State<_TeamFilters> {
  late final TextEditingController _search = TextEditingController(
    text: widget.state.search,
  );
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Surface(
    child: Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 260,
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.copy.search,
            ),
            onSubmitted: (String value) =>
                context.read<TeamCubit>().setFilters(search: value),
          ),
        ),
        _FilterDropdown<String>(
          value: widget.state.roleFilter,
          hint: widget.copy.role,
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'owner', child: Text('Owner')),
            DropdownMenuItem(value: 'manager', child: Text('Manager')),
            DropdownMenuItem(value: 'employee', child: Text('Employee')),
          ],
          onChanged: (String? value) => context.read<TeamCubit>().setFilters(
            role: value,
            clearRole: value == null,
          ),
        ),
        _FilterDropdown<String>(
          value: widget.state.statusFilter,
          hint: widget.copy.status,
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'active', child: Text(widget.copy.active)),
            DropdownMenuItem(
              value: 'deactivated',
              child: Text(widget.copy.deactivated),
            ),
            DropdownMenuItem(
              value: 'archived',
              child: Text(widget.copy.archived),
            ),
          ],
          onChanged: (String? value) => context.read<TeamCubit>().setFilters(
            status: value,
            clearStatus: value == null,
          ),
        ),
        _FilterDropdown<int>(
          value: widget.state.branchFilter,
          hint: widget.copy.branches,
          items: widget.state.branches
              .map(
                (CafeConfigurationBranch branch) => DropdownMenuItem<int>(
                  value: branch.id,
                  child: Text(branch.name),
                ),
              )
              .toList(),
          onChanged: (int? value) => context.read<TeamCubit>().setFilters(
            branchId: value,
            clearBranch: value == null,
          ),
        ),
      ],
    ),
  );
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 170,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      hint: Text(hint),
      isExpanded: true,
      items: <DropdownMenuItem<T>>[
        DropdownMenuItem<T>(value: null, child: Text(hint)),
        ...items,
      ],
      onChanged: onChanged,
    ),
  );
}

class _TeamTable extends StatelessWidget {
  const _TeamTable({required this.copy, required this.state});
  final _TeamCopy copy;
  final TeamState state;
  @override
  Widget build(BuildContext context) => _Surface(
    padding: EdgeInsets.zero,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1020,
        child: Column(
          children: <Widget>[
            _TeamRow(copy: copy, header: true),
            for (final TeamMember member in state.members)
              _TeamRow(copy: copy, member: member),
          ],
        ),
      ),
    ),
  );
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.copy, this.member, this.header = false});
  final _TeamCopy copy;
  final TeamMember? member;
  final bool header;
  @override
  Widget build(BuildContext context) {
    Widget cell(String value, {int flex = 1, Widget? child}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child ?? Text(value, overflow: TextOverflow.ellipsis),
      ),
    );
    if (header) {
      return Container(
        color: AppColors.menuTableHeader,
        child: Row(
          children: <Widget>[
            cell(copy.name, flex: 20),
            cell(copy.role, flex: 13),
            cell(copy.login, flex: 20),
            cell(copy.branches, flex: 22),
            cell(copy.status, flex: 12),
            cell(copy.actions, flex: 13),
          ],
        ),
      );
    }
    final TeamMember item = member!;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          cell(item.name, flex: 20),
          cell(
            '',
            flex: 13,
            child: _RoleBadge(member: item, copy: copy),
          ),
          cell(
            '',
            flex: 20,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(item.login, overflow: TextOverflow.ellipsis),
            ),
          ),
          cell(
            item.allBranches
                ? copy.allBranches
                : item.assignedBranches
                      .map((TeamBranchAssignment b) => b.name)
                      .join(', '),
            flex: 22,
          ),
          cell(
            '',
            flex: 12,
            child: _StatusBadge(member: item, copy: copy),
          ),
          cell(
            '',
            flex: 13,
            child: item.isOwner
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _ProtectedBadge(copy: copy),
                  )
                : _MemberMenu(member: item, copy: copy),
          ),
        ],
      ),
    );
  }
}

class _MemberMenu extends StatelessWidget {
  const _MemberMenu({required this.member, required this.copy});
  final TeamMember member;
  final _TeamCopy copy;
  @override
  Widget build(BuildContext context) => PopupMenuButton<_MemberAction>(
    tooltip: copy.actions,
    onSelected: (_MemberAction action) =>
        _memberAction(context, copy, member, action),
    itemBuilder: (BuildContext context) => <PopupMenuEntry<_MemberAction>>[
      PopupMenuItem(value: _MemberAction.edit, child: Text(copy.edit)),
      if (!member.isArchived)
        PopupMenuItem(
          value: _MemberAction.reset,
          child: Text(copy.resetPassword),
        ),
      if (member.isActive)
        PopupMenuItem(
          value: _MemberAction.deactivate,
          child: Text(copy.deactivate),
        ),
      if (member.isDeactivated)
        PopupMenuItem(
          value: _MemberAction.activate,
          child: Text(copy.activate),
        ),
      if (!member.isArchived)
        PopupMenuItem(value: _MemberAction.archive, child: Text(copy.archive)),
    ],
  );
}

enum _MemberAction { edit, reset, deactivate, activate, archive }

Future<void> _memberAction(
  BuildContext context,
  _TeamCopy copy,
  TeamMember member,
  _MemberAction action,
) async {
  switch (action) {
    case _MemberAction.edit:
      await _showMemberEditor(context, member: member);
    case _MemberAction.reset:
      await _showResetPassword(context, member, copy);
    case _MemberAction.deactivate:
      await _showLifecycleConfirmation(
        context,
        member,
        copy,
        _MemberAction.deactivate,
      );
    case _MemberAction.activate:
      await _showLifecycleConfirmation(
        context,
        member,
        copy,
        _MemberAction.activate,
      );
    case _MemberAction.archive:
      await _showLifecycleConfirmation(
        context,
        member,
        copy,
        _MemberAction.archive,
      );
  }
}

Future<void> _showMemberEditor(
  BuildContext context, {
  TeamMember? member,
}) async {
  final TeamCubit cubit = context.read<TeamCubit>();
  final _TeamCopy c = _TeamCopy(context);
  final TeamMemberDraft initial = member == null
      ? _defaultDraft(cubit.state.roles)
      : TeamMemberDraft.fromMember(member);
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => BlocProvider.value(
      value: cubit,
      child: _MemberEditorDialog(copy: c, member: member, initial: initial),
    ),
  );
}

TeamMemberDraft _defaultDraft(List<TenantRole> roles) {
  final TenantRole? employee = roles
      .where((TenantRole role) => role.code == 'employee' && role.assignable)
      .firstOrNull;
  return TeamMemberDraft(
    roleId: employee?.id ?? 0,
    roleCode: employee?.code ?? 'employee',
  );
}

class _MemberEditorDialog extends StatefulWidget {
  const _MemberEditorDialog({
    required this.copy,
    required this.member,
    required this.initial,
  });
  final _TeamCopy copy;
  final TeamMember? member;
  final TeamMemberDraft initial;
  @override
  State<_MemberEditorDialog> createState() => _MemberEditorDialogState();
}

class _MemberEditorDialogState extends State<_MemberEditorDialog> {
  late TeamMemberDraft _draft = widget.initial;
  late final TextEditingController _name = TextEditingController(
        text: _draft.name,
      ),
      _email = TextEditingController(text: _draft.email),
      _username = TextEditingController(text: _draft.username),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TeamState state = context.watch<TeamCubit>().state;
    final bool editing = widget.member != null;
    final bool roleChanged =
        editing && _draft.roleCode != widget.member!.role.code;
    final List<CafeConfigurationBranch> activeBranches = state.branches
        .where((CafeConfigurationBranch b) => b.isActive)
        .toList();
    final Set<int> activeIds = activeBranches
        .map((CafeConfigurationBranch b) => b.id)
        .toSet();
    return AlertDialog(
      title: Text(editing ? widget.copy.editMember : widget.copy.addMember),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DialogField(
                controller: _name,
                label: '${widget.copy.name} *',
                error: state.errors['name'],
                onChanged: (String v) => _draft = _draft.copyWith(name: v),
              ),
              _DialogField(
                controller: _email,
                label: '${widget.copy.email} *',
                error: state.errors['email'],
                ltr: true,
                onChanged: (String v) => _draft = _draft.copyWith(email: v),
              ),
              if (!_draft.isManager)
                _DialogField(
                  controller: _username,
                  label: '${widget.copy.username} *',
                  error: state.errors['username'],
                  ltr: true,
                  onChanged: (String v) =>
                      _draft = _draft.copyWith(username: v),
                ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<TenantRole>(
                initialValue: state.roles
                    .where((TenantRole r) => r.id == _draft.roleId)
                    .firstOrNull,
                decoration: InputDecoration(labelText: '${widget.copy.role} *'),
                items: state.roles
                    .where(
                      (TenantRole r) =>
                          r.assignable &&
                          (r.code == 'manager' || r.code == 'employee'),
                    )
                    .map(
                      (TenantRole role) => DropdownMenuItem<TenantRole>(
                        value: role,
                        child: Text(_roleLabel(role.code, widget.copy)),
                      ),
                    )
                    .toList(),
                onChanged: (TenantRole? role) {
                  if (role != null) {
                    setState(
                      () => _draft = _draft.copyWith(
                        roleId: role.id,
                        roleCode: role.code,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${widget.copy.branchAccess} *',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.copy.activeBranchesOnly,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final CafeConfigurationBranch branch in activeBranches)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _draft.branchIds.contains(branch.id),
                  title: Text(branch.name),
                  onChanged: (bool? selected) => setState(() {
                    final List<int> ids = List<int>.from(_draft.branchIds);
                    selected == true
                        ? ids.add(branch.id)
                        : ids.remove(branch.id);
                    _draft = _draft.copyWith(branchIds: ids);
                  }),
                ),
              for (final int historicalId in _draft.branchIds.where(
                (int id) => !activeIds.contains(id),
              ))
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  title: Text(
                    '${state.branches.where((CafeConfigurationBranch b) => b.id == historicalId).firstOrNull?.name ?? historicalId} (${widget.copy.inactive})',
                  ),
                  onChanged: null,
                ),
              if (state.errors['branchIds'] != null)
                _DialogError(state.errors['branchIds']!),
              if (!editing || roleChanged) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  roleChanged
                      ? widget.copy.roleChangePassword
                      : widget.copy.temporaryPasswordHelp(
                          _draft.passwordMinimum,
                        ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                _DialogField(
                  controller: _password,
                  label: '${widget.copy.temporaryPassword} *',
                  error: state.errors['temporaryPassword'],
                  obscure: true,
                  onChanged: (String v) =>
                      _draft = _draft.copyWith(temporaryPassword: v),
                ),
                _DialogField(
                  controller: _confirm,
                  label: '${widget.copy.confirmPassword} *',
                  error: state.errors['temporaryPassword_confirmation'],
                  obscure: true,
                  onChanged: (String v) => _draft = _draft.copyWith(
                    temporaryPasswordConfirmation: v,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: state.status == TeamLoadStatus.mutating
              ? null
              : () => Navigator.pop(context),
          child: Text(widget.copy.cancel),
        ),
        FilledButton(
          onPressed: state.status == TeamLoadStatus.mutating
              ? null
              : () async {
                  final TeamMember? saved = editing
                      ? await context.read<TeamCubit>().update(
                          widget.member!.id,
                          _draft,
                          includePassword: roleChanged,
                        )
                      : await context.read<TeamCubit>().create(_draft);
                  if (saved != null && context.mounted) {
                    Navigator.pop(context);
                    if (!editing) {
                      await _showCreatedConfirmation(
                        context,
                        saved,
                        _draft,
                        widget.copy,
                      );
                    }
                  }
                },
          child: state.status == TeamLoadStatus.mutating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(editing ? widget.copy.save : widget.copy.create),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.error,
    this.ltr = false,
    this.obscure = false,
  });
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final String? error;
  final bool ltr, obscure;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
    child: Directionality(
      textDirection: ltr ? TextDirection.ltr : Directionality.of(context),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, errorText: error),
      ),
    ),
  );
}

class _DialogError extends StatelessWidget {
  const _DialogError(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: AppColors.danger));
}

Future<void> _showCreatedConfirmation(
  BuildContext context,
  TeamMember member,
  TeamMemberDraft draft,
  _TeamCopy c,
) => showDialog<void>(
  context: context,
  builder: (BuildContext context) => AlertDialog(
    title: Text(c.memberCreated),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${c.name}: ${member.name}'),
        Text('${c.role}: ${_roleLabel(member.role.code, c)}'),
        Text('${c.login}: ${member.login}'),
        const SizedBox(height: AppSpacing.md),
        Text(c.passwordVisibleOnce),
        Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(draft.temporaryPassword),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () =>
            Clipboard.setData(ClipboardData(text: draft.temporaryPassword)),
        child: Text(c.copy),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(c.done),
      ),
    ],
  ),
);

Future<void> _showResetPassword(
  BuildContext context,
  TeamMember member,
  _TeamCopy c,
) async {
  final TextEditingController password = TextEditingController(),
      confirm = TextEditingController();
  String? error;
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: Text(c.resetPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(c.resetPasswordExplanation),
            const SizedBox(height: AppSpacing.md),
            _DialogField(
              controller: password,
              label: '${c.temporaryPassword} *',
              obscure: true,
              error: error,
              onChanged: (_) {},
            ),
            _DialogField(
              controller: confirm,
              label: '${c.confirmPassword} *',
              obscure: true,
              onChanged: (_) {},
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(c.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (password.text.length < member.passwordMinimum ||
                  password.text != confirm.text) {
                setState(
                  () => error = password.text.length < member.passwordMinimum
                      ? c.temporaryPasswordHelp(member.passwordMinimum)
                      : c.passwordMismatch,
                );
                return;
              }
              final TeamMember? result = await context
                  .read<TeamCubit>()
                  .resetPassword(
                    member.id,
                    password.text,
                    member.passwordMinimum,
                  );
              if (result != null && context.mounted) Navigator.pop(context);
            },
            child: Text(c.resetPassword),
          ),
        ],
      ),
    ),
  );
  password.dispose();
  confirm.dispose();
}

Future<void> _showLifecycleConfirmation(
  BuildContext context,
  TeamMember member,
  _TeamCopy c,
  _MemberAction action,
) async {
  final String text = switch (action) {
    _MemberAction.deactivate => c.deactivateExplanation,
    _MemberAction.activate => c.activateExplanation,
    _MemberAction.archive => c.archiveExplanation,
    _ => '',
  };
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(switch (action) {
        _MemberAction.deactivate => c.deactivate,
        _MemberAction.activate => c.activate,
        _MemberAction.archive => c.archive,
        _ => '',
      }),
      content: Text(text),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(c.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(c.confirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  switch (action) {
    case _MemberAction.deactivate:
      await context.read<TeamCubit>().deactivate(member.id);
    case _MemberAction.activate:
      await context.read<TeamCubit>().activate(member.id);
    case _MemberAction.archive:
      await context.read<TeamCubit>().archive(member.id);
    default:
      break;
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.member, required this.copy});
  final TeamMember member;
  final _TeamCopy copy;
  @override
  Widget build(BuildContext context) =>
      Text(_roleLabel(member.role.code, copy));
}

String _roleLabel(String code, _TeamCopy c) => switch (code) {
  'owner' => c.owner,
  'manager' => c.manager,
  _ => c.employee,
};

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.member, required this.copy});
  final TeamMember member;
  final _TeamCopy copy;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(
      member.isActive
          ? copy.active
          : member.isDeactivated
          ? copy.deactivated
          : copy.archived,
    ),
  );
}

class _ProtectedBadge extends StatelessWidget {
  const _ProtectedBadge({required this.copy});
  final _TeamCopy copy;
  @override
  Widget build(BuildContext context) => Chip(label: Text(copy.protected));
}

class _EmptyTeam extends StatelessWidget {
  const _EmptyTeam({required this.copy, required this.filtered});
  final _TeamCopy copy;
  final bool filtered;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.group_outlined,
            size: 42,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            filtered ? copy.noResults : copy.noMembers,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.copy, required this.state});
  final _TeamCopy copy;
  final TeamState state;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: <Widget>[
      Text('${state.currentPage} / ${state.lastPage}'),
      const SizedBox(width: AppSpacing.md),
      IconButton(
        onPressed: state.currentPage > 1
            ? () => context.read<TeamCubit>().load(page: state.currentPage - 1)
            : null,
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        onPressed: state.currentPage < state.lastPage
            ? () => context.read<TeamCubit>().load(page: state.currentPage + 1)
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) =>
        constraints.maxWidth < 700 || action == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle),
              if (action != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                action!,
              ],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle),
                  ],
                ),
              ),
              action!,
            ],
          ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.title, required this.onRetry});
  final String title;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final _TeamCopy c = _TeamCopy(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text(c.loadFailed),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: Text(c.retry)),
        ],
      ),
    );
  }
}

class _TeamCopy {
  const _TeamCopy(this.context);
  final BuildContext context;
  String get title =>
      context.maybeL10n?.cafeConfigurationTeamAccess ?? 'Team & Access';
  String get edit => context.maybeL10n?.commonEdit ?? 'Edit';
  String get subtitle =>
      context.maybeL10n?.teamAccessSubtitle ??
      'Manage Managers and Employees with access to your cafe.';
  String get addMember => context.maybeL10n?.teamAddMember ?? 'Add Team Member';
  String get search => context.maybeL10n?.teamSearch ?? 'Search team';
  String get role => context.maybeL10n?.teamRole ?? 'Role';
  String get status => context.maybeL10n?.cafeConfigurationStatus ?? 'Status';
  String get branches =>
      context.maybeL10n?.cafeConfigurationBranches ?? 'Branches';
  String get name => context.maybeL10n?.teamName ?? 'Name';
  String get login => context.maybeL10n?.teamLogin ?? 'Login';
  String get actions =>
      context.maybeL10n?.cafeConfigurationActions ?? 'Actions';
  String get active => context.maybeL10n?.commonActive ?? 'Active';
  String get inactive => context.maybeL10n?.commonInactive ?? 'Inactive';
  String get deactivated => context.maybeL10n?.teamDeactivated ?? 'Deactivated';
  String get archived => context.maybeL10n?.teamArchived ?? 'Archived';
  String get protected => context.maybeL10n?.teamProtected ?? 'Protected';
  String get allBranches =>
      context.maybeL10n?.teamAllBranches ?? 'All Branches';
  String get owner => context.maybeL10n?.teamOwner ?? 'Owner';
  String get manager => context.maybeL10n?.teamManager ?? 'Manager';
  String get employee => context.maybeL10n?.teamEmployee ?? 'Employee';
  String get noMembers =>
      context.maybeL10n?.teamNoMembers ?? 'No Managers or Employees yet.';
  String get noResults =>
      context.maybeL10n?.teamNoResults ??
      'No team members match these filters.';
  String get editMember =>
      context.maybeL10n?.teamEditMember ?? 'Edit Team Member';
  String get email => context.maybeL10n?.cafeConfigurationEmail ?? 'Email';
  String get username => context.maybeL10n?.teamUsername ?? 'Username';
  String get branchAccess =>
      context.maybeL10n?.teamBranchAccess ?? 'Branch Access';
  String get activeBranchesOnly =>
      context.maybeL10n?.teamActiveBranchesOnly ??
      'Only active branches can be assigned.';
  String get temporaryPassword =>
      context.maybeL10n?.teamTemporaryPassword ?? 'Temporary Password';
  String get confirmPassword =>
      context.maybeL10n?.teamConfirmPassword ?? 'Confirm Temporary Password';
  String temporaryPasswordHelp(int min) =>
      context.maybeL10n?.teamTemporaryPasswordMinimum(min) ??
      'Use at least $min characters.';
  String get roleChangePassword =>
      context.maybeL10n?.teamRoleChangePassword ??
      'Changing the role requires a new temporary password and login reset.';
  String get cancel => context.maybeL10n?.commonCancel ?? 'Cancel';
  String get save =>
      context.maybeL10n?.cafeConfigurationSaveChanges ?? 'Save Changes';
  String get create => context.maybeL10n?.teamCreate ?? 'Create';
  String get memberCreated =>
      context.maybeL10n?.teamMemberCreated ?? 'Team member created';
  String get passwordVisibleOnce =>
      context.maybeL10n?.teamPasswordVisibleOnce ??
      'This temporary password can only be viewed now.';
  String get copy => context.maybeL10n?.teamCopy ?? 'Copy';
  String get done => cancel;
  String get resetPassword =>
      context.maybeL10n?.teamResetPassword ?? 'Reset Password';
  String get resetPasswordExplanation =>
      context.maybeL10n?.teamResetPasswordExplanation ??
      'Active sessions will be revoked. The user must change their password after next login.';
  String get passwordMismatch =>
      context.maybeL10n?.teamPasswordMismatch ?? 'Passwords do not match.';
  String get deactivate => context.maybeL10n?.teamDeactivate ?? 'Deactivate';
  String get activate => context.maybeL10n?.teamActivate ?? 'Activate';
  String get archive => context.maybeL10n?.teamArchive ?? 'Archive';
  String get deactivateExplanation =>
      context.maybeL10n?.teamDeactivateExplanation ??
      'This user can no longer sign in. Historical activity remains.';
  String get activateExplanation =>
      context.maybeL10n?.teamActivateExplanation ??
      'This user can sign in again.';
  String get archiveExplanation =>
      context.maybeL10n?.teamArchiveExplanation ??
      'Historical records are preserved. Archived users cannot currently be restored.';
  String get confirm => context.maybeL10n?.teamConfirm ?? 'Confirm';
  String get mutationFailed =>
      context.maybeL10n?.teamMutationFailed ??
      'Could not complete the request. Your changes were kept.';
  String get loadFailed =>
      context.maybeL10n?.teamLoadFailed ??
      'Could not load this section. Check your connection and try again.';
  String get retry => context.maybeL10n?.commonRetry ?? 'Retry';
  String get tax => context.maybeL10n?.cafeConfigurationTax ?? 'Tax';
  String get taxSubtitle =>
      context.maybeL10n?.taxSubtitle ??
      'Set the single tax rate used across your cafe.';
  String get taxRate => context.maybeL10n?.taxRate ?? 'Tax rate';
  String get taxHelp =>
      context.maybeL10n?.taxHelp ?? 'Enter a percentage from 0 through 100.';
  String get taxExplanation =>
      context.maybeL10n?.taxExplanation ??
      'This cafe-wide tax is exclusive and applied after discounts. Changes apply to new orders; existing orders preserve their captured tax rate.';
  String get taxInvalid =>
      context.maybeL10n?.taxInvalid ??
      'Enter a valid percentage from 0 through 100.';
  String get taxSaved => context.maybeL10n?.taxSaved ?? 'Tax rate saved.';
  String get confirmTax => context.maybeL10n?.taxConfirm ?? 'Update tax rate?';
  String get current => context.maybeL10n?.taxCurrent ?? 'Current';
  String get newValue => context.maybeL10n?.taxNew ?? 'New';
  String get newOrdersOnly =>
      context.maybeL10n?.taxNewOrdersOnly ?? 'This applies to new orders.';
}
