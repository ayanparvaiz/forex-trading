import 'dart:async';

import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../data/support_repository.dart';
import '../models/support_message.dart';
import '../theme/app_theme.dart';

/// Opens what you have written to the admins, and their answers.
Future<void> openSupport(BuildContext context, {SupportSource? source}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportScreen(source: source ?? buildSupport()),
      ),
    );

/// Writing to the admins: a box for a new message, and every one written
/// before with the admins' answer under it. A notification says when an
/// answer comes.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.source});

  final SupportSource? source;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const _max = 1000;
  final _text = TextEditingController();
  Stream<List<SupportMessage>>? _mine;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.session.uid;
    _mine ??= uid == null ? null : widget.source?.watchMine(uid);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final source = widget.source;
    final session = context.session;
    final uid = session.uid;
    final username = session.profile?.username;
    final text = _text.text.trim();
    if (source == null || uid == null || username == null || text.isEmpty) {
      return;
    }
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await source.send(uid: uid, username: username, text: text);
      _text.clear();
      messenger.showSnackBar(SnackBar(content: Text(s.supportSent)));
    } catch (e) {
      debugPrint('support message failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.writeToAdmins)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
          children: [
            Text(
              s.supportIntro,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            Gap.h16,
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 8,
              maxLength: _max,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: s.supportHint),
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed:
                    _sending ||
                        widget.source == null ||
                        _text.text.trim().isEmpty
                    ? null
                    : _send,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(s.send),
              ),
            ),
            Gap.h24,
            StreamBuilder<List<SupportMessage>>(
              stream: _mine,
              builder: (context, snapshot) {
                final mine = snapshot.data ?? const <SupportMessage>[];
                if (mine.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: Gap.md),
                    child: Text(
                      s.supportEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return Column(
                  children: [for (final m in mine) _MessageCard(message: m)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final m = message;
    final (label, color) = m.answered
        ? (s.supportAnswered, AppColors.brand)
        : m.status == 'closed'
        ? (s.supportClosed, AppColors.textMuted)
        : (s.supportWaiting, AppColors.warning);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: color),
              Gap.w8,
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              if (m.sentAt != null)
                Text(
                  s.timeAgo(m.sentAt!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          Gap.h8,
          Text(m.text, style: const TextStyle(fontSize: 14.5, height: 1.45)),
          if (m.answered) ...[
            Gap.h12,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: AppColors.brandDim.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                m.reply!,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
