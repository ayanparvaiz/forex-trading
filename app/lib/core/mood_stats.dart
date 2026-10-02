import '../models/trade.dart';

/// How trades placed in one mood turned out.
class MoodStat {
  const MoodStat({
    required this.mood,
    required this.trades,
    required this.wins,
    required this.totalR,
  });

  final TradeMood mood;
  final int trades;
  final int wins;
  final double totalR;

  double get winRate => trades == 0 ? 0 : wins / trades;
  double get averageR => trades == 0 ? 0 : totalR / trades;
}

/// Each mood that closed trades were placed in, most trades first.
List<MoodStat> moodStats(Iterable<Trade> trades) {
  final by = <TradeMood, List<Trade>>{};
  for (final t in trades) {
    final mood = t.mood;
    if (mood == null || t.isOpen || t.rMultiple == null) continue;
    (by[mood] ??= []).add(t);
  }
  final stats = [
    for (final MapEntry(key: mood, value: list) in by.entries)
      MoodStat(
        mood: mood,
        trades: list.length,
        wins: list.where((t) => t.rMultiple! > 0).length,
        totalR: list.fold(0, (s, t) => s + t.rMultiple!),
      ),
  ];
  return stats..sort((a, b) {
    final n = b.trades.compareTo(a.trades);
    return n != 0 ? n : a.mood.index.compareTo(b.mood.index);
  });
}
