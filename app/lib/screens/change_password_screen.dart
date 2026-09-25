import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';

/// Changes your password: the current one, then the new one twice.
///
/// The current password is checked first, by the server, because there is no
/// password reset here — a change made by whoever happened to pick up an
/// unlocked phone would lock its owner out for good.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _showCurrent = false;
  bool _showNext = false;
  bool _busy = false;

  /// The server's verdict on the current password, shown under that field
  /// until it is edited again.
  String? _currentError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _nextError(Strings s) {
    final next = _next.text;
    if (next.isEmpty) return null;
    if (next.length < AuthRepository.minPasswordLength) {
      return s.passwordTooShort;
    }
    if (next == _current.text) return s.sameAsCurrent;
    return null;
  }

  String? _confirmError(Strings s) {
    if (_confirm.text.isEmpty) return null;
    return _confirm.text == _next.text ? null : s.passwordsDontMatch;
  }

  bool get _ready =>
      !_busy &&
      _current.text.isNotEmpty &&
      _next.text.length >= AuthRepository.minPasswordLength &&
      _next.text != _current.text &&
      _confirm.text == _next.text;

  Future<void> _submit() async {
    final s = context.s;
    final session = context.session;
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _currentError = null;
    });

    final result = await session.changePassword(
      current: _current.text,
      next: _next.text,
    );
    if (!mounted) return;

    switch (result) {
      case AuthSuccess():
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text(s.passwordChanged)));
      case AuthFailure(error: AuthError.wrongCredentials):
        setState(() {
          _busy = false;
          _currentError = s.wrongCurrentPassword;
        });
      case AuthFailure(error: AuthError.tooManyAttempts):
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(content: Text(s.tooManyAttempts)));
      case AuthFailure():
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    Widget field({
      required TextEditingController controller,
      required String label,
      required bool visible,
      VoidCallback? onToggle,
      String? error,
      TextInputAction action = TextInputAction.next,
    }) {
      return TextField(
        controller: controller,
        obscureText: !visible,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: action,
        onChanged: (_) => setState(() {
          if (controller == _current) _currentError = null;
        }),
        onSubmitted: action == TextInputAction.done && _ready
            ? (_) => _submit()
            : null,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          prefixIcon: const Icon(Icons.lock_outline, size: 19),
          suffixIcon: onToggle == null
              ? null
              : IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    visible ? Icons.visibility_off : Icons.visibility,
                    size: 19,
                  ),
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.changePassword)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  field(
                    controller: _current,
                    label: s.currentPassword,
                    visible: _showCurrent,
                    onToggle: () =>
                        setState(() => _showCurrent = !_showCurrent),
                    error: _currentError,
                  ),
                  Gap.h24,
                  field(
                    controller: _next,
                    label: s.newPassword,
                    visible: _showNext,
                    onToggle: () => setState(() => _showNext = !_showNext),
                    error: _nextError(s),
                  ),
                  Gap.h12,
                  // Shares the new field's visibility: someone who has chosen
                  // to see what they are typing wants to see both.
                  field(
                    controller: _confirm,
                    label: s.confirmNewPassword,
                    visible: _showNext,
                    error: _confirmError(s),
                    action: TextInputAction.done,
                  ),
                  Gap.h16,
                  Container(
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: AppColors.warningDim,
                      borderRadius: Radii.tile,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 17,
                          color: AppColors.warning,
                        ),
                        Gap.w8,
                        Expanded(
                          child: Text(
                            s.rememberPassword,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.md,
              ),
              child: FilledButton(
                onPressed: _ready ? _submit : null,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(s.changePassword),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
