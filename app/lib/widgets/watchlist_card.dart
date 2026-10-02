import 'package:flutter/material.dart';

import '../data/account_scope.dart';
import '../data/mock_market.dart';
import '../data/session_controller.dart';
import '../data/trade_focus.dart';
import '../data/watchlist.dart';
import '../models/candle.dart';
import '../models/instrument.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// The starred pairs: each one's price now, how far it moved in a day, and
/// the day as a line. Tapped, it opens on the trade tab.
class WatchlistCard extends StatefulWidget {
  const WatchlistCard({super.key, this.list});

  /// The pairs to show; the app's [watchlist] unless a test says otherwise.
  final Watchlist? list;

  @override
  State<WatchlistCard> createState() => _WatchlistCardState();
}

class _WatchlistCardState extends State<WatchlistCard> {
  late final Watchlist _list = widget.list ?? watchlist;

  @override
  void initState() {
    super.initState();
    _list.addListener(_refresh);
    _list.load();
  }

  @override
  void dispose() {
    _list.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final market = AccountScope.of(context).market;
    final pairs = _list.pairs;
    return SectionCard(
      title: s.watchlistTitle,
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.sm),
      child: pairs.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Text(
                s.watchlistEmpty,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            )
          : Column(
              children: [
                for (final pair in pairs) _WatchRow(pair: pair, market: market),
              ],
            ),
    );
  }
}

class _WatchRow extends StatelessWidget {
  const _WatchRow({required this.pair, required this.market});

  final Instrument pair;
  final MockMarket market;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final now = market.price(pair);
    final day = dayOfHours(market.candles(pair, timeframe: Timeframe.h1));
    final from = day.isEmpty ? now : day.first;
    final pips = (now - from) / pair.pipSize;
    final color = pips >= 0 ? AppColors.profit : AppColors.loss;
    return InkWell(
      onTap: () => tradeFocus.open(pair),
      borderRadius: Radii.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pair.symbol,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    pair.formatPrice(now),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontFeatures: tabularFigures,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Sparkline(values: [...day, now], height: 30, color: color),
            ),
            Gap.w12,
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${pips >= 0 ? '+' : '−'}${pips.abs().toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      fontFeatures: tabularFigures,
                      color: color,
                    ),
                  ),
                  Text(
                    '${s.pips} · ${s.last24h}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The closes of the last day's hourly candles, oldest first.
List<double> dayOfHours(List<Candle> hourly) => [
  for (final c in hourly.skip(hourly.length > 24 ? hourly.length - 24 : 0))
    c.close,
];
