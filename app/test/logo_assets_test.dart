import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/widgets/app_logo.dart';

/// Generates the PNGs that the launcher-icon and native-splash tooling read.
///
/// Run with `flutter test test/logo_assets_test.dart` after changing the mark,
/// then re-run `dart run flutter_launcher_icons` and `flutter_native_splash`.
/// Keeping the generator in the test suite means a change to the painter that
/// breaks rendering fails CI rather than shipping a blank icon.
void main() {
  const mark = LogoMark.bubble;

  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());

  Future<File> write(String path, List<int> bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  // Every render goes through runAsync. Picture.toImage() needs the real
  // raster thread, and under the test binding's fake async its future simply
  // never completes — the test hangs rather than failing.
  testWidgets('generates the launcher icon and splash assets', (tester) async {
    await tester.runAsync(() async {
      // Full-bleed icon, tile included. iOS applies its own mask.
      final icon = await renderLogoPng(mark: mark, pixels: 1024);
      await write('assets/icon/app_icon.png', icon);

      // Android adaptive foreground: transparent, and inset because the
      // launcher can crop the outer third to whatever mask the phone uses.
      final foreground = await renderLogoPng(
        mark: mark,
        pixels: 1024,
        background: false,
        inset: 0.62,
      );
      await write('assets/icon/app_icon_foreground.png', foreground);

      // Splash mark: no tile, since the splash paints the background itself.
      final splash = await renderLogoPng(
        mark: mark,
        pixels: 768,
        background: false,
      );
      await write('assets/logo/splash.png', splash);

      expect(icon.length, greaterThan(1000));
      expect(foreground.length, greaterThan(1000));
      expect(splash.length, greaterThan(1000));
    });
  });

  testWidgets('every mark renders to a non-empty image', (tester) async {
    await tester.runAsync(() async {
      for (final m in LogoMark.values) {
        final bytes = await renderLogoPng(mark: m, pixels: 128);
        expect(bytes.length, greaterThan(500), reason: '$m rendered empty');
      }
    });
  });
}
