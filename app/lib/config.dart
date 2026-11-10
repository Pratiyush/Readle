// App-wide settings that change at release time.

/// The legal pages live at `https://pratiyush.github.io/german-apps-legal/<slug>/privacy.html` and
/// `…/impressum.html` (drafted by the hub). The slug follows the app's final name, so it stays empty
/// until the owner picks one; Settings hides both links while it is empty, so no release ships a
/// dead link. Set it here, or at build time with `--dart-define=LEGAL_SLUG=…`.
const legalSlug = String.fromEnvironment('LEGAL_SLUG', defaultValue: '');

const legalBase = 'https://pratiyush.github.io/german-apps-legal';

/// The page's URL, or null while no slug is set.
Uri? legalPage(String page, {String slug = legalSlug}) => slug.isEmpty ? null : Uri.parse('$legalBase/$slug/$page.html');

/// The app's name, in one place until the owner picks the original one ("Readle" is a working title).
const appName = 'Readle';

/// Readle's Play listing, for "Update app" when the content CDN needs a newer client. iOS shows the
/// message without a link until the App Store record exists (Apple enrolment: January 2027).
const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.pratiyush.readle';

/// Where "Contact support" writes to (the owner's privacy and support contact, per the hub).
const supportEmail = 'pratiyush1@gmail.com';

/// A mail to support with the app version in the subject. Built by hand: Uri.queryParameters would
/// turn the spaces into plus signs, which mail apps show as they are.
Uri supportMail(String version) => Uri.parse('mailto:$supportEmail?subject=${Uri.encodeComponent('Readle $version')}');
