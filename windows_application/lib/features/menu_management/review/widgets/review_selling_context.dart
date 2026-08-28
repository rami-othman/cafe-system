import 'package:flutter/material.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../assignments/controllers/menu_assignments_cubit.dart'
    show salesChannels;
import '../controllers/menu_review_cubit.dart';

class ReviewSellingContext extends StatelessWidget {
  const ReviewSellingContext({
    super.key,
    required this.state,
    required this.cubit,
  });

  final MenuReviewState state;
  final MenuReviewCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: AppRadius.card,
      ),
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.reviewSellingContext,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final fields = <Widget>[
                  _ContextField(
                    label: l10n.reviewBranch,
                    child: _ContextDropdown<int>(
                      value: state.selectedBranch?.id,
                      items: state.branches
                          .map(
                            (branch) => DropdownMenuItem<int>(
                              value: branch.id,
                              child: Text(branch.name),
                            ),
                          )
                          .toList(),
                      onChanged: state.isBusy
                          ? null
                          : (int? value) {
                              if (value != null) cubit.selectBranch(value);
                            },
                    ),
                  ),
                  _ContextField(
                    label: l10n.reviewSalesChannel,
                    child: _ContextDropdown<String>(
                      value: state.channel,
                      items: salesChannels
                          .map(
                            (channel) => DropdownMenuItem<String>(
                              value: channel,
                              child: Text(_channelLabel(context, channel)),
                            ),
                          )
                          .toList(),
                      onChanged: state.isBusy
                          ? null
                          : (String? value) {
                              if (value != null) cubit.selectChannel(value);
                            },
                    ),
                  ),
                  _ContextField(
                    label: l10n.reviewScope,
                    child: _ContextValue(
                      value: l10n.reviewScopeAssignedMenus,
                      emphasized: true,
                    ),
                  ),
                  _ContextField(
                    label: l10n.reviewTimezone,
                    child: _ContextValue(
                      value: state.selectedBranch?.timezone ?? '–',
                    ),
                  ),
                ];

                if (constraints.maxWidth >= 760) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 3, child: fields[0]),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 3, child: fields[1]),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 4, child: fields[2]),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 2, child: fields[3]),
                    ],
                  );
                }

                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: fields
                      .map(
                        (Widget field) => SizedBox(
                          width: (constraints.maxWidth - AppSpacing.md) / 2,
                          child: field,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextField extends StatelessWidget {
  const _ContextField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      SizedBox(height: 44, child: child),
    ],
  );
}

class _ContextDropdown<T> extends StatefulWidget {
  const _ContextDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  State<_ContextDropdown<T>> createState() => _ContextDropdownState<T>();
}

class _ContextDropdownState<T> extends State<_ContextDropdown<T>> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onChanged != null;
    final bool focused = _focusNode.hasFocus;
    final Color borderColor = !enabled
        ? AppColors.divider
        : focused
        ? AppColors.secondary
        : AppColors.border;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: borderColor,
          width: focused && enabled ? 1.4 : 1,
        ),
        borderRadius: AppRadius.control,
      ),
      child: Center(
        child: DropdownButtonFormField<T>(
          initialValue: widget.value,
          focusNode: _focusNode,
          isDense: true,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          items: widget.items,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

class _ContextValue extends StatelessWidget {
  const _ContextValue({required this.value, this.emphasized = false});

  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    alignment: AlignmentDirectional.centerStart,
    padding: AppSpacing.horizontalMd,
    decoration: BoxDecoration(
      color: emphasized ? const Color(0xFFF7E8D3) : AppColors.surfaceAlt,
      borderRadius: AppRadius.control,
    ),
    child: Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: emphasized ? AppColors.secondary : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

String _channelLabel(BuildContext context, String value) => switch (value) {
  'pos' => context.l10n.salesChannelPos,
  'online_ordering' => context.l10n.salesChannelOnline,
  _ =>
    value
        .split('_')
        .map(
          (String word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' '),
};
