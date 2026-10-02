import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';

/// A poll in a room: the question, each answer with its share of the votes,
/// and mine marked. Tapping an answer votes for it; tapping mine again takes
/// the vote back.
class PollCard extends StatelessWidget {
  const PollCard({
    super.key,
    required this.poll,
    required this.counts,
    required this.mine,
    this.onVote,
  });

  final Poll poll;

  /// Votes for each answer, in their order.
  final List<int> counts;

  /// The answer I picked, if any.
  final int? mine;

  /// Null where I cannot vote — a locked room, or one I am not in.
  final ValueChanged<int?>? onVote;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final total = counts.fold<int>(0, (sum, c) => sum + c);
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.poll_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                s.poll,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Gap.h4,
          Text(
            poll.question,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          Gap.h8,
          for (final (i, option) in poll.options.indexed)
            _Answer(
              text: option,
              count: i < counts.length ? counts[i] : 0,
              share: total == 0 || i >= counts.length ? 0 : counts[i] / total,
              picked: mine == i,
              // The one I picked, again: taken back.
              onTap: onVote == null
                  ? null
                  : () => onVote!(mine == i ? null : i),
            ),
          const SizedBox(height: 2),
          Text(
            onVote == null || mine != null
                ? s.votesCount(total)
                : '${s.votesCount(total)} · ${s.pollTapToVote}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// One answer: a bar as long as its share of the votes, behind its words.
class _Answer extends StatelessWidget {
  const _Answer({
    required this.text,
    required this.count,
    required this.share,
    required this.picked,
    required this.onTap,
  });

  final String text;
  final int count;
  final double share;
  final bool picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.field,
          side: BorderSide(
            color: picked ? AppColors.brand : AppColors.border,
            width: picked ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: share,
                  child: ColoredBox(
                    color: picked
                        ? AppColors.brand.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      picked
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: picked ? AppColors.brand : AppColors.textMuted,
                    ),
                    Gap.w8,
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: picked
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Gap.w8,
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: tabularFigures,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
