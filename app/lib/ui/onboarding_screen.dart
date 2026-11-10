import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_scope.dart';
import 'theme.dart';

/// First launch: one question, which stories suit you. "Not sure? Start at A1" picks every level
/// in sequence (A1 → B2), the owner's default, so an unsure learner starts easy and moves up.
/// The answer is the Story level setting and can be changed any time in Settings.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context).state;
    final palette = Palette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final options = [
      ('A1', l.onboardingA1Name, l.onboardingA1Blurb),
      ('A2', l.onboardingA2Name, l.onboardingA2Blurb),
      ('B1', l.onboardingB1Name, l.onboardingB1Blurb),
      ('B2', l.onboardingB2Name, l.onboardingB2Blurb),
    ];
    return Scaffold(
      key: const Key('onboarding'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            const Text(
              // l10n: German on purpose (the first German word the learner reads)
              'Willkommen!',
              style: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(l.onboardingIntro, style: TextStyle(color: palette.muted, fontSize: 16, height: 1.4)),
            const SizedBox(height: 20),
            for (final (level, name, blurb) in options)
              Card(
                key: Key('onboard-$level'),
                margin: const EdgeInsets.only(bottom: 10),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => state.finishOnboarding(level),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        LevelBadge(level),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              Text(blurb, style: TextStyle(color: palette.muted)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: palette.muted),
                      ],
                    ),
                  ),
                ),
              ),
            Text(
              l.onboardingChangeLater,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
          ],
        ),
      ),
      // Pinned, so the way out for an unsure learner is on screen on every phone (in the list it
      // fell below the fold on a 375×812 screen).
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: OutlinedButton(
          key: const Key('onboard-not-sure'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            side: BorderSide(color: scheme.primary, width: 1.5),
          ),
          onPressed: () => state.finishOnboarding('all'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.onboardingNotSure,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(l.onboardingNotSureDetail, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
