import 'dart:async';

import 'package:flutter/material.dart';

import '../data/account_scope.dart';
import '../data/lesson_progress.dart';
import '../data/session_controller.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Opens the lessons.
Future<void> openLearn(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const LearnScreen()));

/// Five short lessons on the habits the app scores, each with a quiz. Pass
/// them all for "scholar".
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, this.progress});

  /// Where passes are kept; [lessonProgress] unless a test says otherwise.
  final LessonProgress? progress;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late final LessonProgress _progress = widget.progress ?? lessonProgress;
  StreamSubscription<Set<String>>? _following;
  Set<String> _done = const {};
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final uid = context.session.uid;
    if (uid == null) return;
    _following = _progress
        .watch(uid)
        .listen(
          (d) => setState(() => _done = d),
          onError: (Object e) => debugPrint('lessons failed: $e'),
        );
  }

  @override
  void dispose() {
    _following?.cancel();
    super.dispose();
  }

  Future<void> _open(Lesson lesson) async {
    final passed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            LessonScreen(lesson: lesson, passed: _done.contains(lesson.id)),
      ),
    );
    if (passed != true || !mounted) return;
    final uid = context.session.uid;
    if (uid == null) return;
    final store = AccountScope.of(context);
    setState(() => _done = {..._done, lesson.id});
    try {
      await _progress.pass(uid, lesson.id);
      // The worker awards "scholar" once every lesson is passed.
      store.requestScoreUpdate();
    } catch (e) {
      debugPrint('lesson pass failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final total = Lesson.all.length;
    final done = Lesson.all.where((l) => _done.contains(l.id)).length;
    return Scaffold(
      appBar: AppBar(title: Text(s.learn)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.lessonsPassed(done, total),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Gap.h8,
                ClipRRect(
                  borderRadius: Radii.pill,
                  child: LinearProgressIndicator(
                    value: done / total,
                    minHeight: 8,
                    backgroundColor: AppColors.elevated,
                    color: AppColors.brand,
                  ),
                ),
                Gap.h8,
                Text(
                  s.scholarHint,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Gap.h12,
          for (final l in Lesson.all)
            Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: Gap.sm),
              shape: RoundedRectangleBorder(
                borderRadius: Radii.card,
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                onTap: () => _open(l),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: 4,
                ),
                leading: Text(l.emoji, style: const TextStyle(fontSize: 28)),
                title: Text(
                  l.title(s.isBangla),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _done.contains(l.id)
                      ? s.lessonPassed
                      : s.questionsCount(l.questions.length),
                  style: TextStyle(
                    color: _done.contains(l.id)
                        ? AppColors.profit
                        : AppColors.textMuted,
                  ),
                ),
                trailing: Icon(
                  _done.contains(l.id)
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: _done.contains(l.id)
                      ? AppColors.profit
                      : AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One lesson: read it, then answer its questions. Pops true when every
/// answer is right.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson, this.passed = false});

  final Lesson lesson;
  final bool passed;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  bool _quiz = false;

  /// The option picked for each question, as its index in the lesson.
  late final List<int?> _picked = List.filled(
    widget.lesson.questions.length,
    null,
  );
  bool _checked = false;

  bool get _allAnswered => _picked.every((p) => p != null);
  bool get _allRight => _picked.every((p) => p == 0);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final l = widget.lesson;
    final bn = s.isBangla;
    final lessonIndex = Lesson.all.indexOf(l);

    return Scaffold(
      appBar: AppBar(title: Text(l.title(bn))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        children: [
          Text(l.emoji, style: const TextStyle(fontSize: 44)),
          Gap.h12,
          for (final para in l.paragraphs(bn)) ...[
            Text(para, style: const TextStyle(fontSize: 15.5, height: 1.6)),
            Gap.h12,
          ],
          Gap.h8,
          if (!_quiz)
            FilledButton(
              onPressed: () => setState(() => _quiz = true),
              child: Text(s.takeQuiz),
            )
          else ...[
            for (final (qi, q) in l.questions.indexed) ...[
              Text(
                '${qi + 1}. ${q.prompt(bn)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap.h8,
              for (final oi in Question.order(lessonIndex * 3 + qi))
                _Option(
                  text: q.options(bn)[oi],
                  picked: _picked[qi] == oi,
                  // Once checked: the right one green, a wrong pick red.
                  state: !_checked
                      ? null
                      : oi == 0
                      ? true
                      : _picked[qi] == oi
                      ? false
                      : null,
                  onTap: _checked
                      ? null
                      : () => setState(() => _picked[qi] = oi),
                ),
              if (_checked) ...[
                Gap.h4,
                Text(
                  q.why(bn),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              Gap.h16,
            ],
            if (!_checked)
              FilledButton(
                onPressed: _allAnswered
                    ? () => setState(() => _checked = true)
                    : null,
                child: Text(s.checkAnswers),
              )
            else if (_allRight) ...[
              Pill(text: s.quizPassed, color: AppColors.profit),
              Gap.h12,
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(s.done),
              ),
            ] else ...[
              Text(
                s.quizTryAgain,
                style: const TextStyle(color: AppColors.warning),
              ),
              Gap.h12,
              OutlinedButton(
                onPressed: () => setState(() {
                  _checked = false;
                  for (var i = 0; i < _picked.length; i++) {
                    _picked[i] = null;
                  }
                }),
                child: Text(s.tryAgain),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.text,
    required this.picked,
    required this.state,
    required this.onTap,
  });

  final String text;
  final bool picked;

  /// After checking: true right, false wrong, null neither.
  final bool? state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      true => AppColors.profit,
      false => AppColors.loss,
      null => picked ? AppColors.brand : AppColors.border,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.tile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 12),
          decoration: BoxDecoration(
            color: picked ? color.withValues(alpha: 0.12) : AppColors.surface,
            borderRadius: Radii.tile,
            border: Border.all(color: color, width: picked ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(
                state == true
                    ? Icons.check_circle_rounded
                    : state == false
                    ? Icons.cancel_rounded
                    : picked
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 19,
                color: color,
              ),
              Gap.w12,
              Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }
}
