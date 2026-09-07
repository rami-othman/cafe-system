import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' show timeZoneDatabase;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class IanaTimezoneField extends StatefulWidget {
  const IanaTimezoneField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? errorText;
  @override
  State<IanaTimezoneField> createState() => _IanaTimezoneFieldState();
}

class _IanaTimezoneFieldState extends State<IanaTimezoneField> {
  late final TextEditingController _controller;
  late final List<String> _zones;
  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    _zones = timeZoneDatabase.locations.keys.toList()..sort();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(IanaTimezoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DropdownMenu<String>(
    controller: _controller,
    width: double.infinity,
    label: Text(widget.label),
    enableFilter: true,
    enableSearch: true,
    errorText: widget.errorText,
    leadingIcon: const Icon(Icons.public_outlined),
    dropdownMenuEntries: _zones
        .map(
          (String zone) => DropdownMenuEntry<String>(value: zone, label: zone),
        )
        .toList(growable: false),
    onSelected: (String? value) {
      if (value != null) widget.onChanged(value);
    },
  );
}

class CafeStatusBadge extends StatelessWidget {
  const CafeStatusBadge({
    super.key,
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
  });
  final bool active;
  final String activeLabel;
  final String inactiveLabel;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: active ? AppColors.discountGreenBadge : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      active ? activeLabel : inactiveLabel,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: active ? AppColors.discountGreenText : AppColors.textMuted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class FeatureError extends StatelessWidget {
  const FeatureError({
    super.key,
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });
  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_outlined,
            size: 38,
            color: AppColors.danger,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}
