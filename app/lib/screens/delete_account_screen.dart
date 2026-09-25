import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/chat_inbox.dart';
import '../data/session_controller.dart';
import '../theme/app_theme.dart';

/// Deletes your account: what goes, then your password, then one last "are
/// you sure".
///
/// The password is asked for even though you are signed in. This cannot be
/// undone, and a phone left unlocked on a table should not be enough.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  String? _passwordError;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _ready => !_busy && _password.text.isNotEmpty;

  Future<bool> _confirm(String username) async {
    final s = context.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.elevated,
        title: Text(s.deleteConfirmTitle),
        content: Text(s.deleteConfirmBody(username)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.loss),
            child: Text(s.deleteAccount),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submit() async {
    final s = context.s;
    final session = context.session;
    final username = session.profile?.username ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final inbox = InboxScope.read(context);
    FocusScope.of(context).unfocus();

    if (!await _confirm(username) || !mounted) return;
    setState(() {
      _busy = true;
      _passwordError = null;
    });

    // Otherwise the next "active now" beat would write back the presence
    // the worker has just erased.
    inbox?.pausePresence();
    final error = await session.deleteAccount(password: _password.text);

    if (error == null) {
      // Nobody is signed in any more, so the root is the login screen. Back
      // to it, leaving no screen of the deleted account behind.
      nav.popUntil((route) => route.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(s.accountDeleted)));
      return;
    }

    inbox?.resumePresence();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error == AuthError.wrongCredentials) _passwordError = s.wrongPassword;
    });
    switch (error) {
      case AuthError.wrongCredentials:
        break;
      case AuthError.tooManyAttempts:
        messenger.showSnackBar(SnackBar(content: Text(s.tooManyAttempts)));
      default:
        messenger.showSnackBar(SnackBar(content: Text(s.couldNotDelete)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final username = context.session.profile?.username ?? '';

    Widget bullet(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          Gap.w12,
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14.5, height: 1.35),
            ),
          ),
        ],
      ),
    );

    // Nothing may leave mid-way: a half-finished delete is finished by
    // trying again from here, and there is nowhere else to try it from.
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(s.deleteAccount)),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Gap.md),
                      decoration: BoxDecoration(
                        color: AppColors.lossDim,
                        borderRadius: Radii.tile,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.loss,
                          ),
                          Gap.w12,
                          Expanded(
                            child: Text(
                              s.deleteAccountHeading,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.h24,
                    bullet(Icons.person_outline_rounded, s.deleteWhatProfile),
                    bullet(Icons.dynamic_feed_outlined, s.deleteWhatPosts),
                    bullet(Icons.forum_outlined, s.deleteWhatChats),
                    bullet(
                      Icons.notifications_none_rounded,
                      s.deleteWhatNotifications,
                    ),
                    bullet(
                      Icons.alternate_email_rounded,
                      s.deleteUsernameRetired(username),
                    ),
                    Gap.h8,
                    Text(
                      s.deleteReportsKept,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Gap.h24,
                    TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: !_showPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() => _passwordError = null),
                      onSubmitted: (_) => _ready ? _submit() : null,
                      decoration: InputDecoration(
                        labelText: s.deleteEnterPassword,
                        errorText: _passwordError,
                        prefixIcon: const Icon(Icons.lock_outline, size: 19),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 19,
                          ),
                        ),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.loss,
                    foregroundColor: Colors.white,
                  ),
                  child: _busy
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            ),
                            Gap.w12,
                            Text(s.deleting),
                          ],
                        )
                      : Text(s.deleteMyAccount),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
