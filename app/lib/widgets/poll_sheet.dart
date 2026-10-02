import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';

/// Asks for a poll: a question and two to four answers. The poll, or null
/// when closed without asking.
Future<Poll?> showPollSheet(BuildContext context) => showModalBottomSheet<Poll>(
  context: context,
  // Tall enough for four answers and the keyboard; it scrolls past that.
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => const PollSheet(),
);

class PollSheet extends StatefulWidget {
  const PollSheet({super.key});

  @override
  State<PollSheet> createState() => _PollSheetState();
}

class _PollSheetState extends State<PollSheet> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    _question.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  /// The answers written so far; a blank one is left out.
  List<String> get _answers => [
    for (final o in _options)
      if (o.text.trim().isNotEmpty) o.text.trim(),
  ];

  /// Something to ask, and two answers to pick from. The box counts letters
  /// as they look; the rules count them as they are stored — a Bangla
  /// letter with its marks is more than one — so the stored length is held
  /// too.
  bool get _ready {
    final q = _question.text.trim();
    return q.isNotEmpty &&
        q.length <= Poll.questionMax &&
        _answers.length >= Poll.minOptions &&
        _answers.every((a) => a.length <= Poll.optionMax);
  }

  void _add() => setState(() => _options.add(TextEditingController()));

  void _remove(int i) => setState(() => _options.removeAt(i).dispose());

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
              Row(
                children: [
                  const Icon(Icons.poll_rounded, color: AppColors.brand),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      s.newPoll,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              Gap.h12,
              TextField(
                controller: _question,
                autofocus: true,
                maxLength: Poll.questionMax,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: s.pollQuestion,
                  hintText: s.pollQuestionHint,
                ),
                onChanged: (_) => setState(() {}),
              ),
              for (final (i, o) in _options.indexed)
                TextField(
                  key: ObjectKey(o),
                  controller: o,
                  maxLength: Poll.optionMax,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: s.pollOption(i + 1),
                    // Two at least: only the ones past that can go.
                    suffixIcon: i >= Poll.minOptions
                        ? IconButton(
                            tooltip: s.removePollOption,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => _remove(i),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (_options.length < Poll.maxOptions)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(s.addPollOption),
                  ),
                ),
              Gap.h8,
              FilledButton(
                onPressed: _ready
                    ? () => Navigator.of(context).pop(
                        Poll(
                          question: _question.text.trim(),
                          options: _answers,
                        ),
                      )
                    : null,
                child: Text(s.askPoll),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
