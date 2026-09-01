import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../controllers/auth_session_cubit.dart';
import '../controllers/auth_session_state.dart';
import '../widgets/auth_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.message});
  final AuthMessage? message;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<AuthSessionCubit>().login(
      identifier: _identifier.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool loading = context.select<AuthSessionCubit, bool>(
      (AuthSessionCubit cubit) =>
          cubit.state.status == AuthSessionStatus.submitting,
    );
    return AuthCard(
      title: l10n.authLoginTitle,
      subtitle: l10n.authLoginSubtitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.message != null) ...<Widget>[
              _MessageBanner(message: _messageFor(l10n, widget.message!)),
              const SizedBox(height: AppSpacing.lg),
            ],
            TextFormField(
              key: const Key('auth-identifier-field'),
              controller: _identifier,
              enabled: !loading,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.authEmailOrUsername,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (String? value) =>
                  value == null || value.trim().isEmpty
                  ? l10n.authIdentifierRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              key: const Key('auth-password-field'),
              controller: _password,
              enabled: !loading,
              obscureText: _obscurePassword,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.authPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (String? value) => value == null || value.isEmpty
                  ? l10n.authPasswordRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: loading ? l10n.authLoggingIn : l10n.authLogIn,
              isExpanded: true,
              icon: loading ? null : Icons.login,
              onPressed: loading ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.authLoginHelp,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
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
        Expanded(child: Text(message, style: AppTextStyles.bodySmall)),
      ],
    ),
  );
}

String _messageFor(AppLocalizations l10n, AuthMessage message) =>
    switch (message) {
      AuthMessage.sessionExpired => l10n.authSessionExpired,
      AuthMessage.offlineSessionExpired => l10n.authOfflineSessionExpired,
      AuthMessage.loginFailed => l10n.authLoginFailed,
      AuthMessage.passwordChangeFailed => l10n.authPasswordChangeFailed,
    };
