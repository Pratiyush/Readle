import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readle/config.dart';
import 'package:readle/ui/progress_screen.dart';

void main() {
  test('one slug drives both legal URLs', () {
    expect(legalPage('privacy', slug: 'leselicht').toString(), 'https://pratiyush.github.io/german-apps-legal/leselicht/privacy.html');
    expect(legalPage('impressum', slug: 'leselicht').toString(), 'https://pratiyush.github.io/german-apps-legal/leselicht/impressum.html');
    expect(legalPage('privacy', slug: ''), isNull);
  });

  testWidgets('Settings shows Privacy policy and Impressum once the slug is set, and hides them before', (tester) async {
    Future<void> pump(String slug) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: legalTiles(slug: slug)),
        ),
      ),
    );
    await pump('leselicht');
    expect(find.byKey(const Key('privacy-policy')), findsOneWidget);
    expect(find.byKey(const Key('impressum')), findsOneWidget);
    await pump('');
    expect(find.byType(ListTile), findsNothing);
  });

  test('no slug is baked in until the owner names the app', () => expect(legalSlug, isEmpty));
}
