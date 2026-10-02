import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/chat.dart';
import 'package:forex_trading/models/trade.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/shared_cards.dart';

void main() {
  Trade trade({double? exit, ExitReason? reason}) => Trade(
    id: 't1',
    symbol: 'EUR/USD',
    direction: TradeDirection.sell,
    lots: 0.1,
    entryPrice: 1.14,
    stopPrice: 1.142,
    targetPrice: 1.136,
    openedAt: DateTime(2026, 10, 1, 10),
    closedAt: exit == null ? null : DateTime(2026, 10, 1, 14),
    exitPrice: exit,
    exitReason: reason,
    balanceAtEntry: 10000,
    reason: 'lower high under the daily level',
  );

  test('a closed trade becomes a card; an open one does not', () {
    expect(SharedTrade.of(trade(), 'u-me'), isNull);
    final card = SharedTrade.of(
      trade(exit: 1.136, reason: ExitReason.takeProfit),
      'u-me',
    )!;
    expect(card.r, closeTo(2, 0.1), reason: 'the target, less the spread');
    expect(card.r, lessThan(2));
    expect(card.plannedRiskReward, closeTo(2, 1e-9));
    expect(card.exit, ExitReason.takeProfit);
    expect(card.isBuy, isFalse);

    final back = MessageAttachment.fromJson(card.toJson())! as SharedTrade;
    expect(back.toJson(), card.toJson());
  });

  test('a preview says it is a trade', () {
    expect(
      const Strings(AppLanguage.en).messagePreview('held it', 'trade'),
      '📈 Trade · held it',
    );
  });

  Future<void> pump(WidgetTester tester, SharedTrade card, Strings s) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: SharedTradeCard(trade: card, s: s),
            ),
          ),
        ),
      );

  testWidgets('the card: pair, side, result, prices, the plan', (tester) async {
    final card = SharedTrade.of(
      trade(exit: 1.142, reason: ExitReason.stopLoss),
      'u-me',
    )!;
    await pump(tester, card, const Strings(AppLanguage.en));
    expect(find.text('EUR/USD'), findsOneWidget);
    expect(find.text('Short'), findsOneWidget);
    expect(find.textContaining('−1.'), findsOneWidget);
    expect(find.text('Entry 1.14000 → 1.14200'), findsOneWidget);
    expect(find.text('Stopped out · Planned 1:2.0'), findsOneWidget);
  });

  testWidgets('fits a small phone, in Bangla', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final card = SharedTrade.of(
      trade(exit: 1.1385, reason: ExitReason.manual),
      'u-me',
    )!;
    await pump(tester, card, const Strings(AppLanguage.bn));
    expect(tester.takeException(), isNull);
  });
}
