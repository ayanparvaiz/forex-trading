import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../models/trader.dart';
import '../models/app_config.dart';
import 'app_config_host.dart';
import '../theme/app_theme.dart';

/// What the New post button opens: a post, or a question. The choice, or
/// null when closed.
enum ComposeChoice { post, question }

Future<ComposeChoice?> chooseCompose(BuildContext context) {
  final s = context.s;
  return showModalBottomSheet<ComposeChoice>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.brand),
              title: Text(s.shareAPost),
              subtitle: Text(s.shareAPostHint),
              onTap: () => Navigator.of(sheet).pop(ComposeChoice.post),
            ),
            ListTile(
              leading: const Icon(
                Icons.help_outline_rounded,
                color: AppColors.warning,
              ),
              title: Text(s.askQuestion),
              subtitle: Text(s.askQuestionHint),
              onTap: () => Navigator.of(sheet).pop(ComposeChoice.question),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Asks for a question. Its words, or null when closed without asking.
Future<String?> showQuestionSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const QuestionSheet(),
    );

class QuestionSheet extends StatefulWidget {
  const QuestionSheet({super.key});

  @override
  State<QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<QuestionSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Ten letters at least, as every post; no more than the rules take.
  bool get _ready {
    final t = _text.text.trim();
    return t.length >= 10 && t.length <= FeedPost.questionMax;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.askQuestion,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Gap.h8,
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: FeedPost.questionMax,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: s.questionFieldHint),
                onChanged: (_) => setState(() {}),
              ),
              Gap.h8,
              FilledButton(
                onPressed: _ready
                    ? () {
                        final question = _text.text.trim();
                        if (sendAllowed(
                          context,
                          question,
                          feature: AppFeature.posting,
                        )) {
                          Navigator.of(context).pop(question);
                        }
                      }
                    : null,
                child: Text(s.askQuestion),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
