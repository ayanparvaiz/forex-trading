import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/session_controller.dart';
import '../../theme/app_theme.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.s;
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await context.session.logIn(
      username: _username.text,
      password: _password.text,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result is AuthFailure ? s.wrongLogin : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final canSubmit = _username.text.trim().isNotEmpty &&
        _password.text.isNotEmpty &&
        !_busy;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xxl, Gap.xl, Gap.xl),
          children: [
            Gap.h32,
            const Text('📈', style: TextStyle(fontSize: 52)),
            Gap.h16,
            Text(
              s.loginTitle,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            Gap.h4,
            Text(
              s.loginSubtitle,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            Gap.h32,
            TextField(
              controller: _username,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: s.username,
                prefixIcon: const Icon(Icons.alternate_email, size: 19),
              ),
              onChanged: (_) => setState(() {}),
            ),
            Gap.h12,
            TextField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: s.password,
                prefixIcon: const Icon(Icons.lock_outline, size: 19),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    size: 19,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => canSubmit ? _submit() : null,
            ),
            if (_error != null) ...[
              Gap.h12,
              Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: AppColors.loss),
                  Gap.w8,
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.loss,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            Gap.h24,
            FilledButton(
              onPressed: canSubmit ? _submit : null,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(s.login),
            ),
            Gap.h24,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s.noAccount,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SignupScreen(),
                    ),
                  ),
                  child: Text(
                    s.createAccount,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
            Gap.h16,
            // Said up front rather than discovered at the worst moment.
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: Radii.tile,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.textMuted),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      s.noPasswordReset,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
