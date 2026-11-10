// Frame timing in profile mode (production gate §5: gfxinfo can't see Flutter's own frames).
// Run on a device, never in the fast gate:
//
//   flutter drive --profile -d <device> --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart
//
// Writes build/perf/<scenario>.json (FrameTimingSummarizer: average / 90th / 99th percentile /
// worst build and raster times, missed frame budgets). Ads off, so it measures Readle's own UI.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/flows.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('frame timing: library, reader, word sheet', (tester) async {
    await pumpApp(tester);
    final library = find.descendant(of: find.byKey(const PageStorageKey('library')), matching: find.byType(Scrollable)).first;

    await binding.watchPerformance(() async {
      for (var i = 0; i < 4; i++) {
        await tester.fling(library, const Offset(0, -700), 2500);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 4; i++) {
        await tester.fling(library, const Offset(0, 700), 2500);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'library_scroll');

    // The longest story (B2, 173 words): open, scroll through, back to the top.
    await search(tester, 'Die Wohnung ohne');
    await waitFor(tester, find.byKey(const Key('story-die-wohnung-ohne-kueche')));
    await binding.watchPerformance(() async {
      await tester.tap(find.byKey(const Key('story-die-wohnung-ohne-kueche')));
      await tester.pumpAndSettle();
      final reader = find.descendant(of: find.byKey(const Key('reader-list')), matching: find.byType(Scrollable)).first;
      for (var i = 0; i < 3; i++) {
        await tester.fling(reader, const Offset(0, -500), 2000);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 3; i++) {
        await tester.fling(reader, const Offset(0, 500), 2000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'reader_open_scroll');

    await binding.watchPerformance(() async {
      for (final word in ['Wohnung', 'Küche', 'Wohnung']) {
        await tapWord(tester, word);
        await tester.tapAt(const Offset(20, 60)); // the sheet's barrier: close it
        await tester.pumpAndSettle();
      }
    }, reportKey: 'word_sheet');
  });
}
