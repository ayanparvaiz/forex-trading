import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/widgets/medal_pill.dart';

void main() {
  testWidgets('all three places lay out inside a leaderboard row', (
    tester,
  ) async {
    // A narrow phone, and the widest score there is — a pill that overflowed
    // here would push the row's text off screen for the top three.
    await tester.binding.setSurfaceSize(const Size(360, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (final place in [1, 2, 3])
                Row(
                  children: [
                    const Expanded(child: Text('A long display name here')),
                    MedalPill(place: place, label: '100'),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(MedalPill), findsNWidgets(3));
  });

  testWidgets('says what it shows to a screen reader', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MedalPill(place: 2, label: '93')),
    );

    expect(find.bySemanticsLabel('Place 2, discipline 93'), findsOneWidget);
  });

  // Writes a PNG of the three pills for eyeballing. Only when asked:
  //   MEDAL_PREVIEW=/tmp/medals.png flutter test test/medal_pill_test.dart
  final preview = Platform.environment['MEDAL_PREVIEW'];
  testWidgets('preview', skip: preview == null, (tester) async {
    // flutter test draws text with a placeholder font; load a real one so
    // the preview shows digits rather than boxes.
    await tester.runAsync(() async {
      // A static face: the test engine cannot read variable fonts like SF.
      final font = File('/System/Library/Fonts/Supplemental/Arial Bold.ttf');
      if (font.existsSync()) {
        await (FontLoader('Roboto')..addFont(
              Future.value(font.readAsBytesSync().buffer.asByteData()),
            ))
            .load();
      }
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: Material(
          color: Colors.transparent,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: const Color(0xFF111B21),
                padding: const EdgeInsets.all(24),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MedalPill(place: 1, label: '98'),
                    SizedBox(height: 22),
                    MedalPill(place: 2, label: '93'),
                    SizedBox(height: 22),
                    MedalPill(place: 3, label: '92'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(preview!).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
