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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (context.read<AuthSessionCubit>().state.status ==
        AuthSessionStatus.submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<AuthSessionCubit>().login(
      identifier: _identifier.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AuthSessionState state = context.watch<AuthSessionCubit>().state;
    final bool loading = state.status == AuthSessionStatus.submitting;
    final AuthFailure? failure = state.failure;
    final bool showFailureBanner =
        failure != null && failure.fieldErrors.isEmpty;
    final String? message = failure != null
        ? authFailureMessage(l10n, failure)
        : state.message == null
        ? null
        : _messageFor(l10n, state.message!);
    return BlocListener<AuthSessionCubit, AuthSessionState>(
      listenWhen: (AuthSessionState previous, AuthSessionState current) =>
          previous.failure != current.failure &&
          current.failure?.kind == AuthFailureKind.invalidCredentials,
      listener: (BuildContext context, AuthSessionState state) {
        _password.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _passwordFocus.requestFocus();
        });
      },
      child: AuthCard(
        title: l10n.authLoginTitle,
        subtitle: l10n.authLoginSubtitle,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (message != null &&
                  (showFailureBanner || state.message != null)) ...<Widget>[
                AuthErrorBanner(message: message),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextFormField(
                key: const Key('auth-identifier-field'),
                controller: _identifier,
                enabled: !loading,
                textInputAction: TextInputAction.next,
                onChanged: (_) => context
                    .read<AuthSessionCubit>()
                    .clearFailureFor(AuthField.identifier),
                decoration: InputDecoration(
                  labelText: l10n.authEmailOrUsername,
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText: _fieldError(
                    l10n,
                    failure?.fieldErrors[AuthField.identifier],
                  ),
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
                focusNode: _passwordFocus,
                enabled: !loading,
                obscureText: _obscurePassword,
                onChanged: (_) => context
                    .read<AuthSessionCubit>()
                    .clearFailureFor(AuthField.password),
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.authPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: _fieldError(
                    l10n,
                    failure?.fieldErrors[AuthField.password],
                  ),
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
                key: const Key('auth-login-submit-button'),
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
      ),
    );
  }
}

String? _fieldError(AppLocalizations l10n, AuthFailureKind? failure) =>
    failure == null ? null : authFieldFailureMessage(l10n, failure);

String _messageFor(AppLocalizations l10n, AuthMessage message) =>
    switch (message) {
      AuthMessage.sessionExpired => l10n.authSessionExpired,
      AuthMessage.offlineSessionExpired => l10n.authOfflineSessionExpired,
    };
