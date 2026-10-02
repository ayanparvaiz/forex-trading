import 'dart:async';

import 'package:flutter/material.dart';

import '../core/market_sessions.dart';
import '../data/session_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Which of the four forex sessions are open now, and how long until each
/// opens or closes — so a trade can be timed to when the market is moving.
class SessionClock extends StatefulWidget {
  const SessionClock({super.key, this.now = DateTime.now});

  /// The time; a test gives its own.
  final DateTime Function() now;

  @override
  State<SessionClock> createState() => _SessionClockState();
}

class _SessionClockState extends State<SessionClock> {
  Timer? _ticking;

  @override
  void initState() {
    super.initState();
    // Waits are in minutes: once a minute is enough.
    _ticking = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticking?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final now = widget.now().toUtc();
    final note = marketWeekend(now)
        ? s.marketWeekend
        : busiestHours(now)
        ? s.busiestHours
        : null;
    return SectionCard(
      title: s.marketSessions,
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Two by two: each needs room for its wait.
          LayoutBuilder(
            builder: (context, box) {
              final width = (box.maxWidth - Gap.sm) / 2;
              return Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final session in MarketSession.values)
                    SizedBox(
                      width: width,
                      child: _SessionTile(session: session, now: now),
                    ),
                ],
              );
            },
          ),
          if (note != null) ...[
            Gap.h8,
            Text(
              note,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.now});

  final MarketSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final open = session.isOpenAt(now);
    final wait = s.shortWait(session.changeIn(now));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: open ? AppColors.profitDim : AppColors.elevated,
        borderRadius: Radii.field,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: open ? AppColors.profit : AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.sessionName(session.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            open ? s.closesIn(wait) : s.opensIn(wait),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: open ? AppColors.profit : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
