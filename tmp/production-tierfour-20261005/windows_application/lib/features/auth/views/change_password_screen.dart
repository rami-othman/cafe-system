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

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (context.read<AuthSessionCubit>().state.status ==
        AuthSessionStatus.submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<AuthSessionCubit>().changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AuthSessionState state = context.watch<AuthSessionCubit>().state;
    final bool loading = state.status == AuthSessionStatus.submitting;
    final bool employee = state.session?.user.email == null;
    final int minimum = employee ? 8 : 10;
    final AuthFailure? failure = state.failure;
    final bool showFailureBanner =
        failure != null && failure.fieldErrors.isEmpty;
    return AuthCard(
      title: l10n.authChangePassword,
      subtitle: l10n.authLoginSubtitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.authChangePasswordExplanation,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              employee
                  ? l10n.authEmployeePasswordRule
                  : l10n.authManagerPasswordRule,
              style: AppTextStyles.labelMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (showFailureBanner) ...<Widget>[
              AuthErrorBanner(message: authFailureMessage(l10n, failure)),
              const SizedBox(height: AppSpacing.lg),
            ],
            _PasswordField(
              key: const Key('auth-current-password-field'),
              controller: _current,
              label: l10n.authCurrentPassword,
              enabled: !loading,
              errorText: _fieldError(
                l10n,
                failure?.fieldErrors[AuthField.currentPassword],
              ),
              onChanged: (_) => context
                  .read<AuthSessionCubit>()
                  .clearFailureFor(AuthField.currentPassword),
              validator: (String? value) => value == null || value.isEmpty
                  ? l10n.authPasswordRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            _PasswordField(
              key: const Key('auth-new-password-field'),
              controller: _next,
              label: l10n.authNewPassword,
              enabled: !loading,
              errorText: _fieldError(
                l10n,
                failure?.fieldErrors[AuthField.newPassword],
              ),
              onChanged: (_) => context
                  .read<AuthSessionCubit>()
                  .clearFailureFor(AuthField.newPassword),
              validator: (String? value) {
                if (value == null || value.length < minimum) {
                  return l10n.authMinimumPassword(minimum);
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _PasswordField(
              key: const Key('auth-confirm-password-field'),
              controller: _confirm,
              label: l10n.authConfirmNewPassword,
              enabled: !loading,
              errorText: _fieldError(
                l10n,
                failure?.fieldErrors[AuthField.confirmation],
              ),
              onChanged: (_) => context
                  .read<AuthSessionCubit>()
                  .clearFailureFor(AuthField.confirmation),
              onSubmitted: (_) => _submit(),
              validator: (String? value) =>
                  value != _next.text ? l10n.authPasswordsDoNotMatch : null,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              key: const Key('auth-change-password-submit-button'),
              label: loading ? l10n.authSavingPassword : l10n.authSavePassword,
              isExpanded: true,
              onPressed: loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.enabled,
    required this.validator,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? Function(String?) validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _obscure,
    validator: widget.validator,
    onChanged: widget.onChanged,
    onFieldSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.errorText,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    ),
  );
}

String? _fieldError(AppLocalizations l10n, AuthFailureKind? failure) =>
    failure == null ? null : authFieldFailureMessage(l10n, failure);
