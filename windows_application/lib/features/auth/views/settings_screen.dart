import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../controllers/auth_session_cubit.dart';
import '../controllers/auth_session_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AuthSessionState state = context.watch<AuthSessionCubit>().state;
    final session = state.session;
    return DesktopPageLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.navigationSettings, style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.authSettingsSubtitle, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.panel,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.authAccount, style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.lg),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      session?.user.name ?? '',
                      style: AppTextStyles.bodyLarge,
                    ),
                    subtitle: Text(
                      session?.user.email ?? session?.user.username ?? '',
                      style: AppTextStyles.bodySmall,
                    ),
                    trailing: Text(
                      session?.user.role ?? '',
                      style: AppTextStyles.labelMedium,
                    ),
                  ),
                  if ((session?.tenant.name ?? '').isNotEmpty) ...<Widget>[
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.authSignedInTenant,
                      style: AppTextStyles.labelSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(session!.tenant.name, style: AppTextStyles.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: l10n.authLogout,
                    icon: Icons.logout,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? approved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.authLogout),
        content: Text(l10n.authLogoutConfirmation),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.authLogout),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted) {
      await context.read<AuthSessionCubit>().logout();
    }
  }
}
