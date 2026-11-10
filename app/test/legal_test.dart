import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:readle/config.dart';
import 'package:readle/l10n/app_localizations.dart';
import 'package:readle/ui/progress_screen.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'flows.dart';

void main() {
  test('one slug drives both legal URLs', () {
    expect(legalPage('privacy', slug: 'leselicht').toString(), 'https://pratiyush.github.io/german-apps-legal/leselicht/privacy.html');
    expect(legalPage('impressum', slug: 'leselicht').toString(), 'https://pratiyush.github.io/german-apps-legal/leselicht/impressum.html');
    expect(legalPage('privacy', slug: ''), isNull);
  });

  testWidgets('Settings shows Privacy policy and Impressum once the slug is set, and hides them before', (tester) async {
    Future<void> pump(String slug) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ListView(children: legalTiles(context, slug: slug)),
          ),
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

  test('the support mail has a readable subject: spaces, not plus signs', () {
    expect(supportMail('0.1.0 (1)').toString(), 'mailto:pratiyush1@gmail.com?subject=Readle%200.1.0%20(1)');
  });

  testWidgets('Settings → About: the version, and Contact support opens a mail to the owner', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    PackageInfo.setMockInitialValues(
      appName: 'Readle',
      packageName: 'com.pratiyush.readle',
      version: '0.1.0',
      buildNumber: '7',
      buildSignature: '',
    );
    final launcher = RecordingLauncher();
    final before = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = before);
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('tab-progress')));
    await tester.pumpAndSettle();
    final version = find.byKey(const Key('version'));
    await reveal(tester, version, const Key('progress-list'));
    expect(find.descendant(of: version, matching: find.text('0.1.0 (7)')), findsOneWidget);
    await reveal(tester, find.byKey(const Key('support')), const Key('progress-list'));
    await tester.tap(find.byKey(const Key('support')));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['mailto:pratiyush1@gmail.com?subject=Readle%200.1.0%20(7)']);
  });
}
