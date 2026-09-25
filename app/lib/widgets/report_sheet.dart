import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/safety_repository.dart';
import '../data/session_controller.dart';
import '../theme/app_theme.dart';
import 'safety_actions.dart';

/// Reports a person, message, post or comment.
///
/// A reason from a short list, an optional note, and a plain statement that
/// the person is not told. Afterwards it offers to block them as well,
/// since whatever prompted a report is usually a reason not to hear from
/// them again — unless they are blocked already.
Future<void> showReportSheet(BuildContext context, ReportTarget target) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReportSheet(target: target),
  );
  if (sent != true || !context.mounted) return;

  final s = context.s;
  final alreadyBlocked =
      InboxScope.read(context)?.isBlocked(target.targetUid) ?? false;
  final block = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.elevated,
      icon: const Icon(Icons.check_circle, color: AppColors.profit, size: 36),
      title: Text(s.reportThanks),
      content: Text(alreadyBlocked ? s.reportPrivate : s.reportThanksBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(s.done),
        ),
        if (!alreadyBlocked)
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.loss),
            child: Text(s.block),
          ),
      ],
    ),
  );
  if (block == true && context.mounted) {
    await confirmBlock(
      context,
      otherUid: target.targetUid,
      otherUsername: target.targetUsername,
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.target});

  final ReportTarget target;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    final me = context.session.uid;
    final safety = InboxScope.read(context)?.safety;
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    if (reason == null || me == null || safety == null) return;

    setState(() => _sending = true);
    try {
      await safety.report(
        me: me,
        target: widget.target,
        reason: reason,
        note: _note.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('report failed: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final t = widget.target;
    final title = switch (t.kind) {
      ReportKind.user => s.reportUserTitle(t.targetUsername),
      ReportKind.message => s.reportMessageTitle,
      ReportKind.post => s.reportPostTitle,
      ReportKind.comment => s.reportCommentTitle,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.md,
                Gap.lg,
                Gap.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // What is being reported, quoted, so there is no doubt
                  // which message or post this is about.
                  if (t.quote != null) ...[
                    Container(
                      padding: const EdgeInsets.all(Gap.md),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: Radii.tile,
                        border: const Border(
                          left: BorderSide(color: AppColors.loss, width: 3),
                        ),
                      ),
                      child: Text(
                        t.quote!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Gap.h16,
                  ],
                  Text(
                    s.reportWhy,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Gap.h8,
                  RadioGroup<ReportReason>(
                    groupValue: _reason,
                    onChanged: (r) => setState(() => _reason = r),
                    child: Column(
                      children: [
                        for (final r in ReportReason.values)
                          RadioListTile<ReportReason>(
                            value: r,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeColor: AppColors.brand,
                            title: Text(
                              s.reportReason(r.name),
                              style: const TextStyle(fontSize: 14.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Gap.h8,
                  TextField(
                    controller: _note,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: s.reportNoteHint),
                  ),
                  Text(
                    s.reportPrivate,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
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
                onPressed: _reason != null && !_sending ? _send : null,
                style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
                child: _sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(s.sendReport),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
