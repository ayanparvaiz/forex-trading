import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/widgets/chat_bits.dart';

void main() {
  Future<int> swipe(
    WidgetTester tester,
    double dx, {
    bool enabled = true,
  }) async {
    var replies = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SwipeToReply(
              enabled: enabled,
              onReply: () => replies++,
              child: const SizedBox(
                width: 200,
                height: 40,
                child: ColoredBox(color: Colors.teal, child: Text('hello')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.text('hello'), Offset(dx, 0));
    await tester.pumpAndSettle();
    return replies;
  }

  testWidgets('a full swipe right replies, once', (tester) async {
    expect(await swipe(tester, 120), 1);
  });

  testWidgets('a short swipe springs back without replying', (tester) async {
    expect(await swipe(tester, 30), 0);
    // And the message is back where it started.
    expect(tester.getTopLeft(find.text('hello')).dx, closeTo(300, 0.5));
  });

  testWidgets('swiping left does nothing', (tester) async {
    expect(await swipe(tester, -120), 0);
  });

  testWidgets('not while replying is off', (tester) async {
    expect(await swipe(tester, 120, enabled: false), 0);
  });
}
