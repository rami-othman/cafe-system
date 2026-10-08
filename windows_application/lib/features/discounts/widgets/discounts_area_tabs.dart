import 'package:flutter/material.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_spacing.dart';

enum DiscountsArea { policies, settings }

/// Discounts → Policies / Settings. Settings is offered only when the caller
/// knows the user may manage the Cafe Discount Policy; the backend still
/// authorizes every read and write.
class DiscountsAreaTabs extends StatelessWidget {
  const DiscountsAreaTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.showSettings = true,
  });
  final DiscountsArea selected;
  final ValueChanged<DiscountsArea> onSelected;
  final bool showSettings;
  @override
  Widget build(BuildContext context) {
    if (!showSettings) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: SegmentedButton<DiscountsArea>(
        key: const Key('discounts-area-tabs'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: DiscountsArea.policies,
            icon: const Icon(Icons.local_offer_outlined),
            label: Text(
              l.ds3NavPolicies,
              key: const Key('discounts-tab-policies'),
            ),
          ),
          ButtonSegment(
            value: DiscountsArea.settings,
            icon: const Icon(Icons.tune),
            label: Text(
              l.ds3NavSettings,
              key: const Key('discounts-tab-settings'),
            ),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (value) {
          if (value.first != selected) onSelected(value.first);
        },
      ),
    );
  }
}
