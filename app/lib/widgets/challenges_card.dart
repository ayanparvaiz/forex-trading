import 'dart:async';

import 'package:flutter/material.dart';

import '../data/challenges_repository.dart';
import '../data/session_controller.dart';
import '../models/challenge.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// This week's challenges, and last week's results: who challenged whom,
/// where each side stands, who is ahead or who won. Nothing at all when
/// there are none.
class ChallengesCard extends StatefulWidget {
  const ChallengesCard({super.key, this.repository, this.now = DateTime.now});

  final ChallengesRepository? repository;
  final DateTime Function() now;

  @override
  State<ChallengesCard> createState() => _ChallengesCardState();
}

class _ChallengesCardState extends State<ChallengesCard> {
  late final ChallengesRepository? _repo =
      widget.repository ?? buildChallenges();
  StreamSubscription<List<Challenge>>? _following;
  List<Challenge> _challenges = const [];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final uid = context.session.uid;
    if (uid == null) return;
    _following = _repo
        ?.watchMine(uid, widget.now())
        .listen(
          (c) => setState(() => _challenges = c),
          onError: (Object e) => debugPrint('challenges failed: $e'),
        );
  }

  @override
  void dispose() {
    _following?.cancel();
    super.dispose();
  }

  Future<void> _do(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('challenge action failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.s.couldNotSave)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    final me = context.session.uid;
    if (repo == null || me == null || _challenges.isEmpty) {
      return const SizedBox.shrink();
    }
    final s = context.s;
    final now = widget.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: SectionCard(
        title: s.challenges,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in _challenges)
              _ChallengeRow(
                key: ValueKey(c.id),
                challenge: c,
                me: me,
                over: weekOver(c.week, now),
                repo: repo,
                onAccept: () => _do(() => repo.accept(c.id)),
                onRemove: () => _do(() => repo.remove(c.id)),
              ),
            Text(
              s.challengeExplain,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeRow extends StatefulWidget {
  const _ChallengeRow({
    super.key,
    required this.challenge,
    required this.me,
    required this.over,
    required this.repo,
    required this.onAccept,
    required this.onRemove,
  });

  final Challenge challenge;
  final String me;
  final bool over;
  final ChallengesRepository repo;
  final VoidCallback onAccept;
  final VoidCallback onRemove;

  @override
  State<_ChallengeRow> createState() => _ChallengeRowState();
}

class _ChallengeRowState extends State<_ChallengeRow> {
  late final Stream<(String, WeekStanding)> _mine = widget.repo.watchSide(
    widget.me,
    widget.challenge.week,
  );
  late final Stream<(String, WeekStanding)> _theirs = widget.repo.watchSide(
    widget.challenge.otherOf(widget.me),
    widget.challenge.week,
  );

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = widget.challenge;
    return StreamBuilder<(String, WeekStanding)>(
      stream: _theirs,
      builder: (context, theirs) {
        final name = theirs.data?.$1 ?? '…';
        if (!c.accepted) {
          // Not yet on: an invitation, or one waiting.
          final mine = c.fromUid == widget.me;
          if (widget.over) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Text('⚔️', style: TextStyle(fontSize: 20)),
                    Gap.w12,
                    Expanded(
                      child: Text(
                        mine ? s.waitingFor(name) : s.challengedYou(name),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (mine)
                      IconButton(
                        onPressed: widget.onRemove,
                        tooltip: s.cancel,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                // Under the words, where a long name leaves them room.
                if (!mine)
                  Wrap(
                    spacing: Gap.sm,
                    children: [
                      TextButton(
                        onPressed: widget.onRemove,
                        child: Text(s.decline),
                      ),
                      FilledButton(
                        onPressed: widget.onAccept,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(0, 34),
                        ),
                        child: Text(s.accept),
                      ),
                    ],
                  ),
              ],
            ),
          );
        }
        return StreamBuilder<(String, WeekStanding)>(
          stream: _mine,
          builder: (context, mine) {
            final me = mine.data?.$2 ?? WeekStanding.none;
            final them = theirs.data?.$2 ?? WeekStanding.none;
            final result = resultFor(me, them);
            final color = switch (result) {
              ChallengeResult.ahead => AppColors.profit,
              ChallengeResult.behind => AppColors.loss,
              _ => AppColors.textSecondary,
            };
            String score(WeekStanding w) =>
                w.score == null ? s.tooFewTrades : w.score!.toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            if (widget.over) s.lastWeekLabel,
                            s.vsName(name),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Gap.w8,
                      Flexible(
                        child: Pill(
                          text: s.challengeStatus(result.name, widget.over),
                          color: color,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  Gap.h4,
                  Text(
                    '${s.youLabel} ${score(me)} · $name ${score(them)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontFeatures: tabularFigures,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
