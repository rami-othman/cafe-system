import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../../shared/widgets/settings_ui.dart';
import '../../auth/controllers/auth_session_cubit.dart';
import '../../auth/controllers/auth_session_state.dart';
import '../controllers/discount_settings_cubit.dart';
import '../models/discount_settings.dart';
import '../widgets/discount_settings_summary.dart';

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
        final capValid = d.copyWith(policy: const DiscountCafePolicy()).isValid;

        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.header != null) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: widget.header,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            SettingsPageHeader(
              title: l.ds3Title,
              subtitle: l.ds3Subtitle,
              status: _status(state),
            ),
            if (state.errorCode != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SettingsNotice(
                tone: ManagementTone.danger,
                message: state.errorCode == 'load'
                    ? l.dsLoadFailed
                    : l.dsSaveFailed,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SettingsSectionCard(
              icon: Icons.tune,
              title: l.ds3General,
              description: l.ds4GeneralDesc,
              children: [
                SettingsSwitchTile(
                  tileKey: const Key('ds-allow-multiple'),
                  title: l.ds3AllowMultiple,
                  subtitle: l.ds3AllowMultipleHelp,
                  emphasized: true,
                  value: p.allowMultipleDiscounts,
                  onChanged: enabled
                      ? (v) => policy(p.copyWith(allowMultipleDiscounts: v))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsSectionCard(
              icon: Icons.auto_awesome_outlined,
              title: l.ds5Automatic,
              description: l.ds5AutomaticDesc,
              children: [
                SettingsSwitchTile(
                  tileKey: const Key('ds-automatic-enabled'),
                  title: l.ds5AutomaticEnabled,
                  subtitle: l.ds5AutomaticEnabledHelp,
                  emphasized: true,
                  value: d.automaticEnabled,
                  // An older backend cannot run promotions; never offer a
                  // change it would refuse to save.
                  onChanged: enabled && state.saved!.engineReady
                      ? (v) => c.update(d.copyWith(automaticEnabled: v))
                      : null,
                ),
                // Kept but inactive while promotions are off.
                SettingsSwitchTile(
                  tileKey: const Key('ds-allow-suppression'),
                  title: l.ds5AllowRemoval,
                  subtitle: l.ds5AllowRemovalHelp,
                  value: d.allowAutomaticSuppression,
                  onChanged: enabled && d.automaticEnabled
                      ? (v) =>
                            c.update(d.copyWith(allowAutomaticSuppression: v))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsSectionCard(
              icon: Icons.layers_outlined,
              title: l.ds3Combining,
              description: l.ds4CombiningDesc,
              notice: p.allowMultipleDiscounts
                  ? null
                  : SettingsNotice(message: l.ds4CombiningOffHint),
              children: [
                SettingsChoiceCards<String>(
                  label: l.ds3Stacking,
                  value: p.stackingMode,
                  onChanged: combining
                      ? (v) => policy(p.copyWith(stackingMode: v))
                      : null,
                  choices: [
                    SettingsChoice(
                      key: const Key('ds-stacking-different_items_only'),
                      value: 'different_items_only',
                      icon: Icons.call_split,
                      title: l.ds3StackingDifferent,
                      help: l.ds3StackingDifferentHelp,
                    ),
                    SettingsChoice(
                      key: const Key('ds-stacking-same_item_allowed'),
                      value: 'same_item_allowed',
                      icon: Icons.layers_outlined,
                      title: l.ds3StackingSame,
                      help: l.ds3StackingSameHelp,
                    ),
                  ],
                ),
                SettingsSwitchTile(
                  tileKey: const Key('ds-multiple-coupons'),
                  title: l.ds3AllowCoupons,
                  value: p.allowMultipleCoupons,
                  onChanged: combining
                      ? (v) => policy(p.copyWith(allowMultipleCoupons: v))
                      : null,
                ),
                SettingsSwitchTile(
                  tileKey: const Key('ds-coupon-configured'),
                  title: l.ds3AllowCouponConfigured,
                  value: p.allowCouponWithConfigured,
                  onChanged: combining
                      ? (v) => policy(p.copyWith(allowCouponWithConfigured: v))
                      : null,
                ),
                SettingsSwitchTile(
                  tileKey: const Key('ds-order-after-items'),
                  title: l.ds3AllowOrderAfterItems,
                  subtitle: l.ds3AllowOrderAfterItemsHelp,
                  value: p.allowOrderAfterItemDiscounts,
                  onChanged: combining
                      ? (v) =>
                            policy(p.copyWith(allowOrderAfterItemDiscounts: v))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsSectionCard(
              icon: Icons.shield_outlined,
              title: l.ds3Limits,
              description: l.ds4LimitsDesc,
              children: [
                SettingsNumberStepper(
                  fieldKey: const Key('ds-max-discounts'),
                  controller: _max,
                  label: l.ds3MaxCount,
                  helper: l.ds3MaxCountHelp,
                  errorText: p.isValid ? null : l.ds3MaxCountInvalid,
                  min: 1,
                  max: 10,
                  value: p.maximumDiscountsPerOrder,
                  decreaseLabel: l.ds4Decrease,
                  increaseLabel: l.ds4Increase,
                  onChanged: combining
                      ? (v) => policy(
                          p.copyWith(
                            maximumDiscountsPerOrder:
                                int.tryParse(v.trim()) ?? 0,
                          ),
                        )
                      : null,
                ),
                SettingsCompactField(
                  fieldKey: const Key('ds-cap'),
                  controller: _cap,
                  label: l.dsCap,
                  helper: l.dsCapHelp,
                  errorText: capValid ? null : l.dsValidation,
                  suffixText: '%',
                  decimal: true,
                  onChanged: enabled
                      ? (v) =>
                            c.update(d.copyWith(maximumTotalDiscountPercent: v))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsSectionCard(
              icon: Icons.balance_outlined,
              title: l.ds3Conflict,
              description: l.ds4ConflictDesc,
              children: [
                SettingsChoiceCards<String>(
                  value: p.conflictResolution,
                  onChanged: enabled
                      ? (v) => policy(p.copyWith(conflictResolution: v))
                      : null,
                  choices: [
                    SettingsChoice(
                      key: const Key('ds-conflict-best_saving'),
                      value: 'best_saving',
                      icon: Icons.savings_outlined,
                      title: l.ds3BestSaving,
                      help: l.ds4BestSavingHelp,
                    ),
                    SettingsChoice(
                      key: const Key('ds-conflict-priority'),
                      value: 'priority',
                      icon: Icons.low_priority,
                      title: l.ds3PriorityRule,
                      help: l.ds3PriorityRuleHelp,
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        final side = _SummaryPanel(state: state, cubit: c);

        const pagePadding = EdgeInsets.all(AppSpacing.xl);
        return PopScope(
          canPop: !state.dirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop && await _confirmLeave() && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Wide: the summary stays beside the settings as a live
                    // preview. Narrow: it follows the settings.
                    if (box.maxWidth >= 1100) {
                      return Align(
                        alignment: AlignmentDirectional.topStart,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1240),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: pagePadding,
                                  child: main,
                                ),
                              ),
                              SizedBox(
                                width: 360,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsetsDirectional.only(
                                    top: AppSpacing.xl,
                                    end: AppSpacing.xl,
                                    bottom: AppSpacing.xl,
                                  ),
                                  child: side,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      padding: pagePadding,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              main,
                              const SizedBox(height: AppSpacing.lg),
                              side,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SettingsActionBar(
                status: state.dirty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_note,
                            size: 20,
                            color: AppColors.discountOrangeText,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            l.ds4StatusUnsaved,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.discountOrangeText,
                            ),
                          ),
                        ],
                      )
                    : null,
                actions: [
                  TextButton.icon(
                    key: const Key('ds-reload'),
                    onPressed: enabled
                        ? () => c.load(
                            preserveDraft: state.dirty,
                            conflict: state.dirty,
                          )
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: Text(l.ds4Reload),
                  ),
                  OutlinedButton(
                    key: const Key('ds-reset'),
                    onPressed: enabled ? c.resetDraft : null,
                    child: Text(l.dsReset),
                  ),
                  FilledButton.icon(
                    key: const Key('ds-save'),
                    onPressed: state.canSave ? c.save : null,
                    icon: state.status == DiscountSettingsStatus.saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      state.status == DiscountSettingsStatus.saving
                          ? l.dsSaving
                          : l.dsSave,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _status(DiscountSettingsState state) {
    final l = context.l10n;
    if (state.dirty) {
      return ManagementBadge(
        label: l.ds4StatusUnsaved,
        tone: ManagementTone.warning,
      );
    }
    return state.saved!.version == 0
        ? ManagementBadge(
            label: l.ds4StatusDefaults,
            tone: ManagementTone.neutral,
          )
        : ManagementBadge(
            label: l.ds4StatusSaved,
            tone: ManagementTone.success,
          );
  }
}

/// Live summary of what the POS will enforce, plus the version-conflict
/// review when the server copy changed underneath the draft.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.state, required this.cubit});
  final DiscountSettingsState state;
  final DiscountSettingsCubit cubit;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.point_of_sale_outlined,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      state.dirty ? l.ds4PreviewDraft : l.ds3Effective,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l.ds4PreviewHelp,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const Divider(height: AppSpacing.xl),
              DiscountSettingsSummary(draft: state.draft),
            ],
          ),
        ),
        if (state.requiresReview) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsNotice(
                  tone: ManagementTone.warning,
                  message: l.dsConflict,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l.dsCurrentVersion(state.saved!.version),
                  style: AppTextStyles.labelLarge,
                ),
                DiscountSettingsSummary(draft: state.saved!.draft),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const Key('ds-review-conflict'),
                  onPressed: state.status == DiscountSettingsStatus.conflict
                      ? cubit.acknowledgeConflict
                      : null,
                  child: Text(l.dsReviewConflict),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
