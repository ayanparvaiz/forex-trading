import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/avatars.dart';
import 'package:forex_trading/widgets/avatar_image.dart';

void main() {
  test('every id from 1 to 24 is used exactly once', () {
    // Ids are identities stored on profiles. A gap would strand the people
    // who picked it on the fallback owl; a duplicate would give two people
    // who chose differently the same face.
    final ids = Avatars.all.map((a) => a.id).toList()..sort();
    expect(ids, List.generate(24, (i) => i + 1));
  });

  test('every avatar has its artwork on disk', () {
    for (final avatar in Avatars.all) {
      expect(File(avatar.asset).existsSync(), isTrue, reason: avatar.slug);
    }
  });

  test('subjects that survived the redesign kept their numbers', () {
    // Changing art is fine; changing what a stored number means is not.
    // Someone who chose the tiger, id 2, still has a tiger.
    expect(Avatars.byId(1).slug, 'owl');
    expect(Avatars.byId(2).slug, 'tiger');
    expect(Avatars.byId(9).slug, 'shark');
    expect(Avatars.byId(10).slug, 'dragon');
  });

  test('old emoji-era slugs still resolve to their original number', () {
    expect(Avatars.from('koala').id, 7);
    expect(Avatars.from('rocket').id, 20);
    expect(Avatars.from('dragon').id, 10);
    expect(Avatars.from(99).slug, 'owl');
  });

  test('both shelves of the picker have something on them', () {
    expect(Avatars.ofKind(AvatarKind.animal), hasLength(16));
    expect(Avatars.ofKind(AvatarKind.character), hasLength(8));
  });

  testWidgets('every file parses and draws in flutter_svg', (tester) async {
    // Chrome rendering them is not proof: flutter_svg supports a subset of
    // SVG, and anything outside it would fail here rather than on a phone.
    for (final avatar in Avatars.all) {
      final loader = SvgAssetLoader(avatar.asset);
      final info = await tester.runAsync(() => vg.loadPicture(loader, null));
      expect(info, isNotNull, reason: avatar.slug);
      expect(info!.size, const Size(128, 128), reason: avatar.slug);
      info.picture.dispose();
    }
  });

  // Renders the whole set through flutter_svg to a PNG, only when asked:
  //   AVATAR_PREVIEW=/tmp/avatars.png flutter test test/avatars_test.dart
  final preview = Platform.environment['AVATAR_PREVIEW'];
  testWidgets('preview', skip: preview == null, (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Decode every file before the frame that screenshots them.
    await tester.runAsync(() async {
      for (final a in Avatars.all) {
        final info = await vg.loadPicture(SvgAssetLoader(a.asset), null);
        info.picture.dispose();
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
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final a in Avatars.all) AvatarImage(a.id, size: 96),
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
