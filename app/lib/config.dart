// App-wide settings that change at release time.

/// The legal pages live at `https://pratiyush.github.io/german-apps-legal/<slug>/privacy.html` and
/// `…/impressum.html` (drafted by the hub). The slug follows the app's final name, so it stays empty
/// until the owner picks one; Settings hides both links while it is empty, so no release ships a
/// dead link. Set it here, or at build time with `--dart-define=LEGAL_SLUG=…`.
const legalSlug = String.fromEnvironment('LEGAL_SLUG', defaultValue: '');

const legalBase = 'https://pratiyush.github.io/german-apps-legal';

/// The page's URL, or null while no slug is set.
Uri? legalPage(String page, {String slug = legalSlug}) => slug.isEmpty ? null : Uri.parse('$legalBase/$slug/$page.html');
