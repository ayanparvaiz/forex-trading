import 'package:flutter/material.dart';

import '../../data/password_help.dart';
import '../../data/session_controller.dart';
import '../../theme/app_theme.dart';

/// Opens the request for a new password, with [username] already in it.
Future<void> showForgotPassword(
  BuildContext context,
  PasswordHelp help, {
  String username = '',
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => ForgotPasswordSheet(help: help, username: username),
);

/// Your username, how the admins can reach you, and why — sent to them;
/// then what happens next.
class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({
    super.key,
    required this.help,
    this.username = '',
  });

  final PasswordHelp help;
  final String username;

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  late final _username = TextEditingController(text: widget.username);
  final _contact = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  bool _failed = false;

  @override
  void dispose() {
    _username.dispose();
    _contact.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _ready =>
      RegExp(
        r'^[a-z0-9_]{3,20}$',
      ).hasMatch(_username.text.trim().toLowerCase().replaceFirst('@', '')) &&
      _contact.text.trim().length >= 3 &&
      !_sending;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _failed = false;
    });
    final ok = await widget.help.ask(
      username: _username.text.trim().toLowerCase().replaceFirst('@', ''),
      contact: _contact.text.trim(),
      note: _note.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = ok;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
          child: _sent
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 40,
                      color: AppColors.brand,
                    ),
                    Gap.h12,
                    Text(
                      s.helpRequestSent(_contact.text.trim()),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    Gap.h16,
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(s.gotIt),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.forgotPassword,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Gap.h8,
                    Text(
                      s.forgotExplain,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Gap.h16,
                    TextField(
                      controller: _username,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: s.username,
                        prefixIcon: const Icon(Icons.alternate_email, size: 19),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    Gap.h12,
                    TextField(
                      controller: _contact,
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: s.howToReachYou,
                        prefixIcon: const Icon(
                          Icons.contact_phone_outlined,
                          size: 19,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    TextField(
                      controller: _note,
                      maxLength: 300,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(labelText: s.anythingElse),
                    ),
                    if (_failed) ...[
                      Text(
                        s.helpRequestFailed,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.loss,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Gap.h8,
                    ],
                    FilledButton(
                      onPressed: _ready ? _send : null,
                      child: Text(s.sendToAdmins),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
