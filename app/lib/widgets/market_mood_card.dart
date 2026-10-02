import 'dart:async';

import 'package:flutter/material.dart';

import '../data/market_mood_repository.dart';
import '../data/session_controller.dart';
import '../models/instrument.dart';
import '../models/market_mood.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Which way traders think [instrument] is going today — everyone, or the
/// community you are in — and your own say. Opinions, never advice.
class MarketMoodCard extends StatefulWidget {
  const MarketMoodCard({
    super.key,
    required this.instrument,
    this.source,
    this.now = DateTime.now,
  });

  final Instrument instrument;

  /// Where the mood is kept; Firestore unless a test says otherwise.
  final MarketMoodSource? source;

  final DateTime Function() now;

  @override
  State<MarketMoodCard> createState() => _MarketMoodCardState();
}

class _MarketMoodCardState extends State<MarketMoodCard> {
  late final MarketMoodSource? _source = widget.source ?? buildMarketMood();

  /// [moodEveryone], or my community's id. Mine, while I am in one, until I
  /// pick otherwise.
  String? _picked;

  /// What is being followed — scope, pair and day — and what it says.
  (String, String, String)? _following;
  StreamSubscription<MarketMood>? _sub;
  MarketMood _mood = MarketMood.none;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String get _scope {
    final mine = context.session.profile?.communityId;
    final picked = _picked;
    if (picked != null && (picked == moodEveryone || picked == mine)) {
      return picked;
    }
    return mine ?? moodEveryone;
  }

  /// Follows the mood for what is on screen now — a new pair, a new scope,
  /// or past midnight, a new day.
  void _follow(String scope, String pair, String day) {
    final key = (scope, pair, day);
    if (_following == key) return;
    _following = key;
    _sub?.cancel();
    _mood = MarketMood.none;
    _sub = _source
        ?.watch(scope, pair, day)
        .listen(
          (m) => setState(() => _mood = m),
          onError: (Object e) => debugPrint('mood failed: $e'),
        );
  }

  Future<void> _vote(MoodSide side) async {
    final source = _source;
    final me = context.session.uid;
    final key = _following;
    if (source == null || me == null || key == null) return;
    final before = _mood;
    // The same side again takes it back.
    final next = before.sideOf(me) == side ? null : side;
    setState(() => _mood = before.withVote(me, next));
    try {
      await source.vote(
        scope: key.$1,
        pair: key.$2,
        day: key.$3,
        me: me,
        side: next,
      );
    } catch (e) {
      debugPrint('mood vote failed: $e');
      if (!mounted) return;
      setState(() => _mood = before);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.s.couldNotSave)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_source == null) return const SizedBox.shrink();
    final s = context.s;
    final me = context.session.uid;
    final inCommunity = context.session.profile?.communityId != null;
    final scope = _scope;
    _follow(scope, moodPair(widget.instrument), moodDay(widget.now()));
    final mood = _mood;
    final mine = me == null ? null : mood.sideOf(me);
    final share = mood.upShare;

    return SectionCard(
      title: s.marketMood,
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inCommunity) ...[
            Wrap(
              spacing: Gap.sm,
              children: [
                for (final (id, label) in [
                  (moodEveryone, s.moodEveryone),
                  (context.session.profile!.communityId!, s.moodMyCommunity),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: scope == id,
                    onSelected: (_) => setState(() => _picked = id),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            Gap.h8,
          ],
          Text(
            s.moodQuestion(widget.instrument.symbol),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          Gap.h8,
          if (share == null)
            Text(
              s.moodNoVotes,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            )
          else ...[
            _Gauge(upShare: share),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.moodUpShare((share * 100).round()),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.profit,
                    ),
                  ),
                ),
                Text(
                  s.moodDownShare(100 - (share * 100).round()),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.loss,
                  ),
                ),
              ],
            ),
          ],
          Gap.h12,
          Row(
            children: [
              Expanded(
                child: _SideButton(
                  label: s.moodUp,
                  icon: Icons.trending_up_rounded,
                  color: AppColors.profit,
                  chosen: mine == MoodSide.up,
                  onTap: me == null ? null : () => _vote(MoodSide.up),
                ),
              ),
              Gap.w8,
              Expanded(
                child: _SideButton(
                  label: s.moodDown,
                  icon: Icons.trending_down_rounded,
                  color: AppColors.loss,
                  chosen: mine == MoodSide.down,
                  onTap: me == null ? null : () => _vote(MoodSide.down),
                ),
              ),
            ],
          ),
          Gap.h8,
          Text(
            [
              if (mood.votes > 0) s.moodVotes(mood.votes),
              s.moodNotAdvice,
            ].join(' · '),
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Up on the left in green, down on the right in red, each as wide as its
/// share.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.upShare});

  final double upShare;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Radii.pill,
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: AppColors.loss)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: upShare,
                child: const ColoredBox(color: AppColors.profit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(chosen ? Icons.check_rounded : icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: chosen ? Colors.white : color,
        backgroundColor: chosen ? color.withValues(alpha: 0.85) : null,
        side: BorderSide(color: color),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
