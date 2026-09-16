import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../models/auth_failure.dart';

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('auth-error-banner'),
    container: true,
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF2C6AE)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline, color: AppColors.secondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                textAlign: Directionality.of(context) == TextDirection.rtl
                    ? TextAlign.right
                    : TextAlign.left,
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String authFailureMessage(
  AppLocalizations l10n,
  AuthFailure failure,
) => switch (failure.kind) {
  AuthFailureKind.invalidCredentials => l10n.authInvalidCredentials,
  AuthFailureKind.tooManyAttempts => l10n.authTooManyAttempts,
  AuthFailureKind.networkUnavailable => l10n.authNetworkUnavailable,
  AuthFailureKind.connectionTimeout => l10n.authConnectionTimeout,
  AuthFailureKind.serverUnavailable => l10n.authServerUnavailable,
  AuthFailureKind.validation => l10n.authValidationFailed,
  AuthFailureKind.invalidResponse => l10n.authInvalidResponse,
  AuthFailureKind.secureStorageFailure => l10n.authSecureStorageFailure,
  AuthFailureKind.verifiedSessionSaveFailed =>
    l10n.authVerifiedSessionSaveFailed,
  AuthFailureKind.secureStorageReadFailure => l10n.authSecureStorageReadFailure,
  AuthFailureKind.corruptSavedSession => l10n.authCorruptSavedSession,
  AuthFailureKind.unableToVerifySession => l10n.authUnableToVerifySession,
  AuthFailureKind.offlineVerificationRequired =>
    l10n.authConnectionRequiredToVerifySession,
  AuthFailureKind.passwordChangedSessionSaveFailed =>
    l10n.authPasswordChangedSessionSaveFailed,
  AuthFailureKind.unexpected => l10n.authUnexpectedError,
  AuthFailureKind.incorrectCurrentPassword => l10n.authIncorrectCurrentPassword,
  AuthFailureKind.weakNewPassword => l10n.authWeakNewPassword,
  AuthFailureKind.passwordConfirmationMismatch =>
    l10n.authPasswordConfirmationMismatch,
};

String authFieldFailureMessage(
  AppLocalizations l10n,
  AuthFailureKind failure,
) => switch (failure) {
  AuthFailureKind.validation => l10n.authFieldValidationFailed,
  AuthFailureKind.incorrectCurrentPassword => l10n.authIncorrectCurrentPassword,
  AuthFailureKind.weakNewPassword => l10n.authWeakNewPassword,
  AuthFailureKind.passwordConfirmationMismatch =>
    l10n.authPasswordConfirmationMismatch,
  _ => authFailureMessage(l10n, AuthFailure(failure)),
};
