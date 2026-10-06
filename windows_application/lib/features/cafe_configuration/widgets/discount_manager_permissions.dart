import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../controllers/discount_permissions_cubit.dart';

class DiscountManagerPermissions extends StatelessWidget {
  const DiscountManagerPermissions({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DiscountPermissionsCubit, DiscountPermissionsState>(
        builder: (c, state) {
          final l = c.l10n, cubit = c.read<DiscountPermissionsCubit>();
          final labels = {
            'discounts.view': l.dsView,
            'discounts.manage': l.dsManagePolicies,
            'discounts.apply_configured': l.dsApplyConfigured,
            'discounts.settings.manage': l.dsTitle,
            'discounts.automatic.suppress': l.d2Suppress,
          };
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.dsManagerPermissions,
                    style: Theme.of(c).textTheme.titleMedium,
                  ),
                  Text(l.dsPermissionHelp),
                  if (state.busy) const LinearProgressIndicator(),
                  if (state.saved != null) ...[
                    for (final entry in labels.entries)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        value: state.draft.contains(entry.key),
                        onChanged: state.busy
                            ? null
                            : (v) => cubit.toggle(entry.key, v == true),
                      ),
                    FilledButton(
                      onPressed:
                          state.busy ||
                              state.saved!.length == state.draft.length &&
                                  state.saved!.containsAll(state.draft)
                          ? null
                          : cubit.save,
                      child: Text(l.dsSave),
                    ),
                  ],
                  if (state.failed) Text(l.dsSaveFailed),
                  if (state.saved == null && !state.busy)
                    TextButton(
                      onPressed: cubit.load,
                      child: Text(l.commonRetry),
                    ),
                ],
              ),
            ),
          );
        },
      );
}
