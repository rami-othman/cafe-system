import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../controllers/auth_session_cubit.dart';
import '../controllers/auth_session_state.dart';
import '../models/auth_failure.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_error_banner.dart';

/// A small, Auth-only recovery surface. It intentionally reuses [AuthCard]
/// rather than modifying the Login or application-shell layout.
class AuthRecoveryScreen extends StatelessWidget {
  const AuthRecoveryScreen({super.key, required this.tenantBlocked});

  final bool tenantBlocked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AuthSessionState state = context.watch<AuthSessionCubit>().state;
    final bool loading = state.verificationInProgress;
    final bool offerLogout =
        tenantBlocked ||
        state.failure?.kind == AuthFailureKind.verifiedSessionSaveFailed;
    final String title = tenantBlocked
        ? l10n.authTenantNotOperationalTitle
        : l10n.authVerificationRequiredTitle;
    final String explanation = tenantBlocked
        ? l10n.authTenantNotOperationalExplanation
        : _verificationExplanation(l10n, state.failure);
    return AuthCard(
      title: title,
      subtitle: l10n.authLoginSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AuthErrorBanner(message: explanation),
          const SizedBox(height: AppSpacing.lg),
          if (tenantBlocked) ...<Widget>[
            Text(
              l10n.authContactAdministration,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppButton(
            key: const Key('auth-retry-verification-button'),
            label: loading
                ? l10n.authRetryingVerification
                : l10n.authRetryVerification,
            isExpanded: true,
            icon: loading ? null : Icons.refresh,
            onPressed: loading
                ? null
                : () => context.read<AuthSessionCubit>().retryVerification(),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: const Key('auth-return-to-login-button'),
            onPressed: () {
              final AuthSessionCubit cubit = context.read<AuthSessionCubit>();
              if (offerLogout) {
                cubit.logout();
              } else {
                cubit.returnToLogin();
              }
            },
            child: Text(
              offerLogout ? l10n.authLogout : l10n.authReturnToLogin,
            ),
          ),
        ],
      ),
    );
  }
}

String _verificationExplanation(AppLocalizations l10n, AuthFailure? failure) =>
    switch (failure?.kind) {
      AuthFailureKind.secureStorageReadFailure =>
        l10n.authSecureStorageReadFailure,
      AuthFailureKind.verifiedSessionSaveFailed =>
        l10n.authVerifiedSessionSaveFailed,
      AuthFailureKind.offlineVerificationRequired =>
        l10n.authConnectionRequiredToVerifySession,
      _ => l10n.authUnableToVerifySession,
    };
