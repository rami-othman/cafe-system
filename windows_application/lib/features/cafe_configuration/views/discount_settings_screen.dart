import '../widgets/discount_settings_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/controllers/auth_session_cubit.dart';
import '../../auth/controllers/auth_session_state.dart';
import '../controllers/discount_settings_cubit.dart';

class DiscountSettingsScreen extends StatefulWidget {
  const DiscountSettingsScreen({super.key});
  @override
  State<DiscountSettingsScreen> createState() => _DiscountSettingsScreenState();
}

class _DiscountSettingsScreenState extends State<DiscountSettingsScreen> {
  VoidCallback? _unregister;
  final _cap = TextEditingController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unregister?.call();
    _unregister = UnsavedNavigationScope.maybeOf(context)?.register(
      UnsavedNavigationGuard(
        isDirty: () => context.read<DiscountSettingsCubit>().state.dirty,
        confirmLeave: _confirmLeave,
      ),
    );
  }

  Future<bool> _confirmLeave() async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(context.l10n.dsDiscard),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(context.l10n.dsDiscardAction),
            ),
          ],
        ),
      ) ??
      false;
  @override
  void dispose() {
    _unregister?.call();
    _cap.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<AuthSessionCubit, AuthSessionState>(
    listenWhen: (p, n) =>
        p.session?.accessToken != n.session?.accessToken ||
        p.session?.tenant.id != n.session?.tenant.id ||
        p.session?.user.role != n.session?.user.role,
    listener: (c, s) => c.read<DiscountSettingsCubit>().revoke(),
    child: BlocBuilder<DiscountSettingsCubit, DiscountSettingsState>(
      builder: (context, state) {
        final l = context.l10n;
        final c = context.read<DiscountSettingsCubit>();
        if (state.status == DiscountSettingsStatus.forbidden) {
          return Center(child: Text(l.dsForbidden));
        }
        if (state.saved == null) {
          return Center(
            child: state.status == DiscountSettingsStatus.loading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.dsLoadFailed),
                      TextButton(onPressed: c.load, child: Text(l.commonRetry)),
                    ],
                  ),
          );
        }
        final d = state.draft;
        if (_cap.text != d.maximumTotalDiscountPercent) {
          _cap.text = d.maximumTotalDiscountPercent;
        }
        final enabled =
            state.status != DiscountSettingsStatus.saving &&
            state.status != DiscountSettingsStatus.loading;
        Widget choice(
          String key,
          String title,
          String value,
          List<(String, String)> options,
          void Function(String) change,
        ) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: DropdownButtonFormField<String>(
            key: ValueKey('$key-$value'),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: title),
            items: options
                .map(
                  (o) => DropdownMenuItem(
                    value: o.$1,
                    child: Text(o.$2, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: enabled
                ? (v) {
                    if (v != null) change(v);
                  }
                : null,
          ),
        );
        final rules = [
          ('exclusive', l.dsExclusive),
          ('follow_combination_rules', l.dsFollowRules),
        ];
        return PopScope(
          canPop: !state.dirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop && await _confirmLeave() && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: SingleChildScrollView(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.dsTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(l.dsSubtitle),
                      if (state.saved!.version == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Text(l.dsDefaults),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.dsAutomatic),
                        subtitle: Text(l.dsActivationUnavailable),
                        value: d.automaticEnabled,
                        onChanged: enabled && state.saved!.engineReady
                            ? (v) => c.update(d.copyWith(automaticEnabled: v))
                            : null,
                      ),
                      choice(
                        'ds-strategy',
                        l.dsStrategy,
                        d.selectionStrategy,
                        [
                          ('highest_saving', l.dsHighest),
                          ('lowest_saving', l.dsLowest),
                          ('priority', l.dsPriority),
                        ],
                        (v) => c.update(d.copyWith(selectionStrategy: v)),
                      ),
                      Text(l.dsSavingHelp),
                      const SizedBox(height: AppSpacing.lg),
                      choice(
                        'ds-combination',
                        l.dsCombination,
                        d.combinationMode,
                        [
                          ('single', l.dsSingle),
                          ('disjoint_items', l.dsDisjoint),
                        ],
                        (v) => c.update(
                          d.copyWith(
                            combinationMode: v,
                            orderDiscountBehavior: v == 'single'
                                ? 'exclusive'
                                : d.orderDiscountBehavior,
                          ),
                        ),
                      ),
                      Text(l.dsCombinationHelp),
                      const SizedBox(height: AppSpacing.lg),
                      choice(
                        'ds-order',
                        l.dsOrderBehavior,
                        d.orderDiscountBehavior,
                        [
                          ('exclusive', l.dsExclusive),
                          if (d.combinationMode == 'disjoint_items')
                            ('after_items', l.dsAfterItems),
                        ],
                        (v) => c.update(d.copyWith(orderDiscountBehavior: v)),
                      ),
                      Text(l.dsOrderHelp),
                      const SizedBox(height: AppSpacing.lg),
                      choice(
                        'ds-coupon',
                        l.dsCouponBehavior,
                        d.couponBehavior,
                        rules,
                        (v) => c.update(d.copyWith(couponBehavior: v)),
                      ),
                      choice(
                        'ds-manual',
                        l.dsManualBehavior,
                        d.manualBehavior,
                        rules,
                        (v) => c.update(d.copyWith(manualBehavior: v)),
                      ),
                      TextField(
                        key: const Key('ds-cap'),
                        controller: _cap,
                        enabled: enabled,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l.dsCap,
                          helperText: l.dsCapHelp,
                          helperMaxLines: 3,
                          errorText: d.isValid ? null : l.dsValidation,
                        ),
                        onChanged: (v) => c.update(
                          d.copyWith(maximumTotalDiscountPercent: v),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.dsAllowSuppression),
                        subtitle: Text(l.dsSuppressionHelp),
                        value: d.allowAutomaticSuppression,
                        onChanged: enabled
                            ? (v) => c.update(
                                d.copyWith(allowAutomaticSuppression: v),
                              )
                            : null,
                      ),
                      const Divider(),
                      Text(
                        l.dsSummary,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      DiscountSettingsSummary(draft: d),
                      Text(l.dsIntentHelp),
                      if (state.requiresReview) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(l.dsConflict),
                        Text(l.dsCurrentVersion(state.saved!.version)),
                        DiscountSettingsSummary(draft: state.saved!.draft),
                        TextButton(
                          key: const Key('ds-review-conflict'),
                          onPressed:
                              state.status == DiscountSettingsStatus.conflict
                              ? c.acknowledgeConflict
                              : null,
                          child: Text(l.dsReviewConflict),
                        ),
                      ],
                      if (state.errorCode != null)
                        Text(
                          state.errorCode == 'load'
                              ? l.dsLoadFailed
                              : l.dsSaveFailed,
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        children: [
                          FilledButton(
                            key: const Key('ds-save'),
                            onPressed: state.canSave ? c.save : null,
                            child: Text(
                              state.status == DiscountSettingsStatus.saving
                                  ? l.dsSaving
                                  : l.dsSave,
                            ),
                          ),
                          OutlinedButton(
                            key: const Key('ds-reset'),
                            onPressed: enabled ? c.resetDraft : null,
                            child: Text(l.dsReset),
                          ),
                          TextButton(
                            onPressed: enabled
                                ? () => c.load(
                                    preserveDraft: state.dirty,
                                    conflict: state.dirty,
                                  )
                                : null,
                            child: Text(l.commonRetry),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
