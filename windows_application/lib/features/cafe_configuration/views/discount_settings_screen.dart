import '../widgets/discount_settings_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/controllers/auth_session_cubit.dart';
import '../../auth/controllers/auth_session_state.dart';
import '../controllers/discount_settings_cubit.dart';
import '../models/discount_settings.dart';

/// Cafe Discount Policy, in business language. Legacy engine fields stay in
/// the draft (and are saved back unchanged) but are not shown; Automatic
/// Promotions are not production-ready and have no controls here.
class DiscountSettingsScreen extends StatefulWidget {
  const DiscountSettingsScreen({super.key, this.header});

  /// Optional navigation shown above the policy (Discounts → Policies/Settings).
  final Widget? header;
  @override
  State<DiscountSettingsScreen> createState() => _DiscountSettingsScreenState();
}

class _DiscountSettingsScreenState extends State<DiscountSettingsScreen> {
  VoidCallback? _unregister;
  final _cap = TextEditingController();
  final _max = TextEditingController();
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
    _max.dispose();
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
        final p = d.policy;
        if (_cap.text != d.maximumTotalDiscountPercent) {
          _cap.text = d.maximumTotalDiscountPercent;
        }
        if ((int.tryParse(_max.text.trim()) ?? 0) !=
            p.maximumDiscountsPerOrder) {
          _max.text = p.maximumDiscountsPerOrder.toString();
        }
        final enabled =
            state.status != DiscountSettingsStatus.saving &&
            state.status != DiscountSettingsStatus.loading;
        // Combination controls stay visible but inactive while multiple
        // discounts are off; their saved values are never changed by that.
        final combining = enabled && p.allowMultipleDiscounts;
        void policy(DiscountCafePolicy next) =>
            c.update(d.copyWith(policy: next));
        Widget section(String title) => Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.xl,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        Widget toggle(
          String key,
          String title,
          bool value,
          bool active,
          void Function(bool) change, {
          String? help,
        }) => SwitchListTile(
          key: Key(key),
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: help == null ? null : Text(help),
          value: value,
          onChanged: active ? change : null,
        );
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
                      ?widget.header,
                      Text(
                        l.ds3Title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(l.ds3Subtitle),
                      if (state.saved!.version == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Text(l.dsDefaults),
                        ),
                      section(l.ds3General),
                      toggle(
                        'ds-allow-multiple',
                        l.ds3AllowMultiple,
                        p.allowMultipleDiscounts,
                        enabled,
                        (v) => policy(p.copyWith(allowMultipleDiscounts: v)),
                        help: l.ds3AllowMultipleHelp,
                      ),
                      section(l.ds3Combining),
                      Text(l.ds3Stacking, style: AppTextStyles.labelLarge),
                      RadioGroup<String>(
                        groupValue: p.stackingMode,
                        onChanged: (v) {
                          if (combining && v != null) {
                            policy(p.copyWith(stackingMode: v));
                          }
                        },
                        child: Column(
                          children: [
                            for (final option in [
                              (
                                'different_items_only',
                                l.ds3StackingDifferent,
                                l.ds3StackingDifferentHelp,
                              ),
                              (
                                'same_item_allowed',
                                l.ds3StackingSame,
                                l.ds3StackingSameHelp,
                              ),
                            ])
                              RadioListTile<String>(
                                key: Key('ds-stacking-${option.$1}'),
                                contentPadding: EdgeInsets.zero,
                                value: option.$1,
                                enabled: combining,
                                title: Text(option.$2),
                                subtitle: Text(option.$3),
                              ),
                          ],
                        ),
                      ),
                      toggle(
                        'ds-multiple-coupons',
                        l.ds3AllowCoupons,
                        p.allowMultipleCoupons,
                        combining,
                        (v) => policy(p.copyWith(allowMultipleCoupons: v)),
                      ),
                      toggle(
                        'ds-coupon-configured',
                        l.ds3AllowCouponConfigured,
                        p.allowCouponWithConfigured,
                        combining,
                        (v) => policy(p.copyWith(allowCouponWithConfigured: v)),
                      ),
                      toggle(
                        'ds-order-after-items',
                        l.ds3AllowOrderAfterItems,
                        p.allowOrderAfterItemDiscounts,
                        combining,
                        (v) =>
                            policy(p.copyWith(allowOrderAfterItemDiscounts: v)),
                        help: l.ds3AllowOrderAfterItemsHelp,
                      ),
                      section(l.ds3Limits),
                      TextField(
                        key: const Key('ds-max-discounts'),
                        controller: _max,
                        enabled: combining,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l.ds3MaxCount,
                          helperText: l.ds3MaxCountHelp,
                          helperMaxLines: 2,
                          errorText: p.isValid ? null : l.ds3MaxCountInvalid,
                        ),
                        onChanged: (v) => policy(
                          p.copyWith(
                            maximumDiscountsPerOrder:
                                int.tryParse(v.trim()) ?? 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
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
                          errorText:
                              d
                                  .copyWith(policy: const DiscountCafePolicy())
                                  .isValid
                              ? null
                              : l.dsValidation,
                        ),
                        onChanged: (v) => c.update(
                          d.copyWith(maximumTotalDiscountPercent: v),
                        ),
                      ),
                      section(l.ds3Conflict),
                      RadioGroup<String>(
                        groupValue: p.conflictResolution,
                        onChanged: (v) {
                          if (enabled && v != null) {
                            policy(p.copyWith(conflictResolution: v));
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              key: const Key('ds-conflict-best_saving'),
                              contentPadding: EdgeInsets.zero,
                              value: 'best_saving',
                              enabled: enabled,
                              title: Text(l.ds3BestSaving),
                            ),
                            RadioListTile<String>(
                              key: const Key('ds-conflict-priority'),
                              contentPadding: EdgeInsets.zero,
                              value: 'priority',
                              enabled: enabled,
                              title: Text(l.ds3PriorityRule),
                              subtitle: Text(l.ds3PriorityRuleHelp),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: AppSpacing.xxl),
                      Text(
                        l.ds3Effective,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      DiscountSettingsSummary(draft: d),
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
