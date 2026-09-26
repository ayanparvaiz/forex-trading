import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/community_avatars.dart';

void main() {
  test('every id from 1 to 28 is used exactly once', () {
    // Stored on communities: a gap or a duplicate would change what a
    // community shows without anyone changing it.
    final ids = CommunityAvatars.all.map((a) => a.id).toList()..sort();
    expect(ids, List.generate(28, (i) => i + 1));
    expect(CommunityAvatars.first, 1);
    expect(CommunityAvatars.last, 28);
  });

  test('seven on each topic', () {
    for (final topic in CommunityAvatarTopic.values) {
      expect(CommunityAvatars.ofTopic(topic), hasLength(7), reason: '$topic');
    }
  });

  test('an unknown number is no picture, not a wrong one', () {
    expect(CommunityAvatars.byId(null), isNull);
    expect(CommunityAvatars.byId(99), isNull);
    expect(CommunityAvatars.byId(21)!.slug, 'shapla');
  });

  test('every picture has its artwork on disk', () {
    for (final a in CommunityAvatars.all) {
      expect(File(a.asset).existsSync(), isTrue, reason: a.slug);
    }
  });

  testWidgets('every file parses and draws in flutter_svg', (tester) async {
    for (final a in CommunityAvatars.all) {
      final info = await tester.runAsync(
        () => vg.loadPicture(SvgAssetLoader(a.asset), null),
      );
      expect(info, isNotNull, reason: a.slug);
      expect(info!.size, const Size(128, 128), reason: a.slug);
      info.picture.dispose();
    }
  });

  // The whole set through flutter_svg to a PNG, only when asked:
  //   AVATAR_PREVIEW=/tmp/c.png flutter test test/community_avatars_test.dart
  final preview = Platform.environment['AVATAR_PREVIEW'];
  testWidgets('preview', skip: preview == null, (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      for (final a in CommunityAvatars.all) {
        (await vg.loadPicture(
          SvgAssetLoader(a.asset),
          null,
        )).picture.dispose();
      }
    });
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: const Color(0xFF0B141A),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final topic in CommunityAvatarTopic.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final a in CommunityAvatars.ofTopic(topic))
                            Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: SvgPicture.asset(
                                a.asset,
                                width: 104,
                                height: 104,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(preview!).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
