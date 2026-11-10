import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Bottom navigation: the library tab.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get tabStories;

  /// Bottom navigation: the saved-words tab.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get tabWords;

  /// Bottom navigation: the progress and settings tab.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get tabProgress;

  /// Library: the big heading under the German greeting.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get libraryTitle;

  /// Library: shown instead of the list when the story library fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load stories.'**
  String get libraryLoadError;

  /// Library: the level filter chip that shows every level (the others are A1, A2, B1, B2).
  ///
  /// In en, this message translates to:
  /// **'All levels'**
  String get libraryAllLevels;

  /// Library: filter chip that hides stories already read.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get libraryUnread;

  /// Library: hint text in the empty search field.
  ///
  /// In en, this message translates to:
  /// **'Search stories…'**
  String get librarySearchHint;

  /// Library: shown when the level, collection, unread and search filters leave no story.
  ///
  /// In en, this message translates to:
  /// **'No stories match these filters.'**
  String get libraryNoMatches;

  /// Library: collection filter chip that shows every collection.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get collectionAll;

  /// Library: collection name, on its filter chip and in each story's meta line.
  ///
  /// In en, this message translates to:
  /// **'Fiction'**
  String get collectionFiction;

  /// Library: collection name, on its filter chip and in each story's meta line.
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get collectionCulture;

  /// Library: collection name, on its filter chip and in each story's meta line.
  ///
  /// In en, this message translates to:
  /// **'Facts'**
  String get collectionFacts;

  /// Library: eyebrow (small caps) on the card for the story opened last.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE READING'**
  String get libraryContinueReading;

  /// Library: eyebrow on the daily story card once a story was read today.
  ///
  /// In en, this message translates to:
  /// **'KEEP GOING — NEXT UP'**
  String get libraryKeepGoing;

  /// Library: eyebrow on the daily story card before any story was read today.
  ///
  /// In en, this message translates to:
  /// **'STORY OF THE DAY'**
  String get libraryStoryOfTheDay;

  /// Library: reading time and collection under a story title, on the daily card and in the list.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min · {collection}'**
  String storyCardMeta(int minutes, String collection);

  /// Library: tag on a story row the learner has finished.
  ///
  /// In en, this message translates to:
  /// **'✓ Read'**
  String get storyRead;

  /// Library banner: the content server needs a newer app version.
  ///
  /// In en, this message translates to:
  /// **'Update the app to get new stories.'**
  String get updateBannerAppTooOld;

  /// Library banner: new stories are ready to download.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{📚 1 new story to read} other{📚 {count} new stories to read}}'**
  String updateBannerNewStories(int count);

  /// Library banner (Android): button that opens the Play Store listing.
  ///
  /// In en, this message translates to:
  /// **'Update app'**
  String get updateBannerUpdateApp;

  /// Library banner: button that downloads the new stories.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateBannerDownload;

  /// Library: snack bar when downloading new stories fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the new stories. Try again later.'**
  String get updateBannerDownloadFailed;

  /// Reader: back button tooltip, the button under the story, and the button on the load-error page.
  ///
  /// In en, this message translates to:
  /// **'Back to stories'**
  String get backToStories;

  /// Reader: shown when a story fails to load.
  ///
  /// In en, this message translates to:
  /// **'This story couldn\'t be loaded.'**
  String get readerLoadError;

  /// Reader app bar: tooltip of the play button that reads the story aloud.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get readerListen;

  /// Reader app bar: tooltip of the same button while the story is being read aloud.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get readerStop;

  /// Reader app bar: toggle that shows the English translation under every sentence (the language code of the translations).
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get readerTranslations;

  /// Reader app bar: button that cycles the story text size.
  ///
  /// In en, this message translates to:
  /// **'Aa'**
  String get readerTextSize;

  /// Reader: reading time and word count above the story title.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min read · {words, plural, other{{words} words}}'**
  String readerStoryMeta(int minutes, int words);

  /// Reader: hint under the title once the learner has tapped a word. ⇄ is the translate icon after each sentence.
  ///
  /// In en, this message translates to:
  /// **'Tap any word for its meaning. Tap ⇄ for a sentence translation.'**
  String get readerTip;

  /// Reader: highlighted first-run hint under the title, until the first word tap. ⇄ is the translate icon.
  ///
  /// In en, this message translates to:
  /// **'Tap any word to hear it and see what it means. Tap ⇄ to translate a sentence.'**
  String get readerFirstTip;

  /// Reader: button under a story already read.
  ///
  /// In en, this message translates to:
  /// **'Take the quiz again'**
  String get readerQuizAgain;

  /// Reader: button under an unread story; marks it read and opens the quiz.
  ///
  /// In en, this message translates to:
  /// **'Finish & take the quiz'**
  String get readerFinish;

  /// Reader: screen-reader label of the ⇄ icon after a sentence.
  ///
  /// In en, this message translates to:
  /// **'Translate sentence {number}'**
  String readerTranslateSentence(int number);

  /// Reader: tooltip of the speaker button beside a sentence; reads from there to the end.
  ///
  /// In en, this message translates to:
  /// **'Listen from here'**
  String get readerListenFromHere;

  /// Word sheet: tooltip of the speaker button beside the headword.
  ///
  /// In en, this message translates to:
  /// **'Pronounce'**
  String get wordSheetPronounce;

  /// Word sheet: tooltip of the close button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get wordSheetClose;

  /// Word sheet and practice card: a noun's plural form. "die" is the German plural article and stays German.
  ///
  /// In en, this message translates to:
  /// **'plural: die {plural}'**
  String pluralDie(String plural);

  /// Word sheet: note when the tapped word has no dictionary entry.
  ///
  /// In en, this message translates to:
  /// **'No dictionary entry for this word (often a name). The sentence translation below should help.'**
  String get wordSheetNoEntry;

  /// Word sheet: note for a compound word shown with its last part's meaning. Both words are German and shown bold.
  ///
  /// In en, this message translates to:
  /// **'{word} is a compound — this is the meaning of its last part, {headword}.'**
  String wordSheetCompound(String word, String headword);

  /// Word sheet: note for an inflected word shown with its dictionary form. Both words are German and shown bold.
  ///
  /// In en, this message translates to:
  /// **'{word} is a form of {headword}.'**
  String wordSheetFormOf(String word, String headword);

  /// Word sheet: eyebrow over the sentence the word came from and its translation.
  ///
  /// In en, this message translates to:
  /// **'IN THIS STORY'**
  String get wordSheetInThisStory;

  /// Word sheet: button once the word is saved; tapping removes it.
  ///
  /// In en, this message translates to:
  /// **'✓ Saved to your words'**
  String get wordSheetSaved;

  /// Word sheet: button that saves the word for review.
  ///
  /// In en, this message translates to:
  /// **'＋ Save to my words'**
  String get wordSheetSave;

  /// Words tab: eyebrow above the heading.
  ///
  /// In en, this message translates to:
  /// **'YOUR VOCABULARY'**
  String get wordsEyebrow;

  /// Words tab: the big heading.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get wordsTitle;

  /// Words tab: summary card headline when words are due for review.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word to review} other{{count} words to review}}'**
  String wordsDue(int count);

  /// Words tab: summary headline when words are saved but none is due.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get wordsAllCaughtUp;

  /// Words tab: summary headline before any word is saved.
  ///
  /// In en, this message translates to:
  /// **'No words yet'**
  String get wordsNone;

  /// Words tab: summary card line under the headline once words are saved.
  ///
  /// In en, this message translates to:
  /// **'{total} saved · spaced repetition brings each word back just before you\'d forget it.'**
  String wordsSavedSummary(int total);

  /// Words tab: summary card line before any word is saved.
  ///
  /// In en, this message translates to:
  /// **'Tap words while reading and save them here.'**
  String get wordsEmptyHint;

  /// Words tab: button that starts a review session of the due words.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get wordsPractice;

  /// Words tab: filter chip, every saved word.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get wordFilterAll;

  /// Words tab: filter chip, words due for review today.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get wordFilterDue;

  /// Words tab: filter chip, words not yet mastered.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get wordFilterLearning;

  /// Words tab: filter chip, mastered words.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get wordFilterMastered;

  /// Words tab: tooltip of the speaker button on a word row.
  ///
  /// In en, this message translates to:
  /// **'Pronounce {word}'**
  String wordsPronounce(String word);

  /// Words tab: tooltip of the strength bars on a word row (spaced-repetition box).
  ///
  /// In en, this message translates to:
  /// **'Strength {box} of 6'**
  String wordsStrength(int box);

  /// Words tab: tooltip of the delete button on a word row.
  ///
  /// In en, this message translates to:
  /// **'Remove {word}'**
  String wordsRemove(String word);

  /// Practice: done page when no word was due.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review'**
  String get practiceNothingToReview;

  /// Practice: done page headline after the last card.
  ///
  /// In en, this message translates to:
  /// **'Session complete'**
  String get practiceSessionComplete;

  /// Practice: done page line under the headline.
  ///
  /// In en, this message translates to:
  /// **'{right} of {total} remembered.'**
  String practiceScore(int right, int total);

  /// Practice: done page button back to the Words tab.
  ///
  /// In en, this message translates to:
  /// **'Back to words'**
  String get practiceBackToWords;

  /// Practice: tooltip of the close button in the app bar.
  ///
  /// In en, this message translates to:
  /// **'End practice'**
  String get practiceEnd;

  /// Practice: flashcard front, under the German word.
  ///
  /// In en, this message translates to:
  /// **'Do you remember it? Tap to reveal.'**
  String get practiceRevealHint;

  /// Practice: flashcard back when the word has no dictionary entry.
  ///
  /// In en, this message translates to:
  /// **'(no dictionary entry)'**
  String get practiceNoEntry;

  /// Practice: button under the card that says the word.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get practiceListen;

  /// Practice: button that flips the card.
  ///
  /// In en, this message translates to:
  /// **'Show answer'**
  String get practiceShowAnswer;

  /// Practice: answer button after the flip; the word comes back sooner.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t know'**
  String get practiceDidntKnow;

  /// Practice: answer button after the flip; the word moves up a box.
  ///
  /// In en, this message translates to:
  /// **'Knew it'**
  String get practiceKnewIt;

  /// Quiz: shown when the quiz fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the quiz.'**
  String get quizLoadError;

  /// Quiz: tooltip of the close button in the app bar.
  ///
  /// In en, this message translates to:
  /// **'Close quiz'**
  String get quizClose;

  /// Quiz: eyebrow above a German word to translate.
  ///
  /// In en, this message translates to:
  /// **'WHAT DOES THIS WORD MEAN?'**
  String get quizWordQuestion;

  /// Quiz: eyebrow above a German sentence to translate.
  ///
  /// In en, this message translates to:
  /// **'WHAT DOES THIS SENTENCE MEAN?'**
  String get quizSentenceQuestion;

  /// Quiz: feedback after a wrong answer (a right answer shows the German "Richtig!").
  ///
  /// In en, this message translates to:
  /// **'Not quite.'**
  String get quizNotQuite;

  /// Quiz: button after answering the last question.
  ///
  /// In en, this message translates to:
  /// **'See results'**
  String get quizSeeResults;

  /// Quiz: button after answering a question, to the next one.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get quizContinue;

  /// Quiz results: line under the German praise headline; the title is the German story title.
  ///
  /// In en, this message translates to:
  /// **'You finished “{title}”.'**
  String quizFinished(String title);

  /// Quiz results: button that shares an image card of the finished story.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareResult;

  /// Share card (image): small line above the German story title.
  ///
  /// In en, this message translates to:
  /// **'I read a German story'**
  String get shareCardEyebrow;

  /// Share card (image): streak chip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{🔥 1 day streak} other{🔥 {count} day streak}}'**
  String shareCardStreak(int count);

  /// Share card (image): quiz score chip.
  ///
  /// In en, this message translates to:
  /// **'{pct}% on the quiz'**
  String shareCardScore(int pct);

  /// Share card (image): bottom line with the app name.
  ///
  /// In en, this message translates to:
  /// **'{app} · German stories you can tap'**
  String shareCardFooter(String app);

  /// Text sent with the share card; the title is the German story title, kept in German quotation marks.
  ///
  /// In en, this message translates to:
  /// **'I just read „{title}“ ({level}) in German with {app}.'**
  String shareText(String title, String level, String app);

  /// Quiz results: label under the percentage.
  ///
  /// In en, this message translates to:
  /// **'quiz score'**
  String get quizScore;

  /// Quiz results: button back to the library.
  ///
  /// In en, this message translates to:
  /// **'Next story'**
  String get quizNextStory;

  /// Quiz results: button shown below 80 %, restarts the quiz.
  ///
  /// In en, this message translates to:
  /// **'Try the quiz again'**
  String get quizTryAgain;

  /// Progress tab and quiz results: label under the streak number (🔥 N).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{day streak}}'**
  String statDayStreak(int count);

  /// Progress tab: label under the number of stories finished.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{stories read}}'**
  String statStoriesRead(int count);

  /// Progress tab: label under the number of saved words.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{words saved}}'**
  String statWordsSaved(int count);

  /// Progress tab: label under the number of mastered words.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{words mastered}}'**
  String statWordsMastered(int count);

  /// Onboarding: line under the German welcome ("Willkommen!").
  ///
  /// In en, this message translates to:
  /// **'Read short German stories and tap any word you don’t know. Which stories suit you?'**
  String get onboardingIntro;

  /// Onboarding: name on the A1 level card.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get onboardingA1Name;

  /// Onboarding: line on the A1 level card.
  ///
  /// In en, this message translates to:
  /// **'I know a few words and phrases'**
  String get onboardingA1Blurb;

  /// Onboarding: name on the A2 level card.
  ///
  /// In en, this message translates to:
  /// **'Elementary'**
  String get onboardingA2Name;

  /// Onboarding: line on the A2 level card.
  ///
  /// In en, this message translates to:
  /// **'I understand simple everyday sentences'**
  String get onboardingA2Blurb;

  /// Onboarding: name on the B1 level card.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get onboardingB1Name;

  /// Onboarding: line on the B1 level card.
  ///
  /// In en, this message translates to:
  /// **'I can follow clear texts on familiar topics'**
  String get onboardingB1Blurb;

  /// Onboarding: name on the B2 level card.
  ///
  /// In en, this message translates to:
  /// **'Upper intermediate'**
  String get onboardingB2Name;

  /// Onboarding: line on the B2 level card.
  ///
  /// In en, this message translates to:
  /// **'I read most everyday German'**
  String get onboardingB2Blurb;

  /// Onboarding: note under the level cards.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in Settings.'**
  String get onboardingChangeLater;

  /// Onboarding: pinned bottom button, picks every level in order.
  ///
  /// In en, this message translates to:
  /// **'Not sure? Start at A1'**
  String get onboardingNotSure;

  /// Onboarding: second line of the pinned bottom button.
  ///
  /// In en, this message translates to:
  /// **'Every level in order, moving up as you read'**
  String get onboardingNotSureDetail;

  /// Progress tab: eyebrow above the heading.
  ///
  /// In en, this message translates to:
  /// **'YOUR PROGRESS'**
  String get progressEyebrow;

  /// Progress tab: the big heading.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressTitle;

  /// Progress tab: daily goal card headline once today's goal is met.
  ///
  /// In en, this message translates to:
  /// **'Daily goal reached! 🎉'**
  String get progressGoalReached;

  /// Progress tab: daily goal card headline before the goal is met.
  ///
  /// In en, this message translates to:
  /// **'Today\'s goal'**
  String get progressTodaysGoal;

  /// Progress tab: daily goal card line under the headline.
  ///
  /// In en, this message translates to:
  /// **'{goal, plural, =1{Read 1 story a day.} other{Read {goal} stories a day.}}'**
  String progressGoalText(int goal);

  /// Progress tab: heading of the per-level progress bars.
  ///
  /// In en, this message translates to:
  /// **'Stories by level'**
  String get progressByLevel;

  /// Progress tab: small credit line at the very bottom.
  ///
  /// In en, this message translates to:
  /// **'Stories and dictionary from the Lernle project. German text is machine-assisted and awaiting native review.'**
  String get progressCredits;

  /// Progress tab: heading of the settings panel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings: label of the level dropdown.
  ///
  /// In en, this message translates to:
  /// **'Story level'**
  String get settingsStoryLevel;

  /// Settings: level dropdown option, every level in order.
  ///
  /// In en, this message translates to:
  /// **'All levels, A1 → B2'**
  String get settingsLevelAll;

  /// Settings: level dropdown option.
  ///
  /// In en, this message translates to:
  /// **'A1 · beginner'**
  String get settingsLevelA1;

  /// Settings: level dropdown option.
  ///
  /// In en, this message translates to:
  /// **'A2 · elementary'**
  String get settingsLevelA2;

  /// Settings: level dropdown option.
  ///
  /// In en, this message translates to:
  /// **'B1 · intermediate'**
  String get settingsLevelB1;

  /// Settings: level dropdown option.
  ///
  /// In en, this message translates to:
  /// **'B2 · upper intermediate'**
  String get settingsLevelB2;

  /// Settings: label of the daily goal dropdown.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get settingsDailyGoal;

  /// Settings: daily goal dropdown option (1, 2, 3 or 5 stories a day).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 story} other{{count} stories}}'**
  String settingsDailyGoalOption(int count);

  /// Settings: label of the theme dropdown.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Settings: theme dropdown option, follow the phone.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Settings: theme dropdown option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Settings: theme dropdown option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Settings: label of the speech speed dropdown.
  ///
  /// In en, this message translates to:
  /// **'Speech speed'**
  String get settingsSpeechSpeed;

  /// Settings: speech speed dropdown option.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get speechSlow;

  /// Settings: speech speed dropdown option.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get speechNormal;

  /// Settings: speech speed dropdown option.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get speechFast;

  /// Settings: switch, a tapped word is spoken.
  ///
  /// In en, this message translates to:
  /// **'Say words when tapped'**
  String get settingsSayWords;

  /// Settings: switch for the daily reading reminder.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get settingsReminder;

  /// Settings: subtitle of the daily reminder switch.
  ///
  /// In en, this message translates to:
  /// **'One a day, skipped once you have read'**
  String get settingsReminderDetail;

  /// Settings: snack bar when the learner turns the reminder on but refuses notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Readle. Allow them in system settings to get the reminder.'**
  String get settingsNotificationsDenied;

  /// Settings: row shown when the reminder is on but notifications were blocked later.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Readle'**
  String get settingsNotificationsBlocked;

  /// Settings: subtitle of that row; tapping opens the system notification page.
  ///
  /// In en, this message translates to:
  /// **'The reminder can\'t show. Tap to allow notifications.'**
  String get settingsNotificationsBlockedDetail;

  /// Settings: row that opens the time picker for the reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get settingsReminderTime;

  /// Settings: row that reopens the ad consent form (shown where consent rules require it).
  ///
  /// In en, this message translates to:
  /// **'Privacy & ad choices'**
  String get settingsPrivacyChoices;

  /// Settings: switch for downloading new stories automatically.
  ///
  /// In en, this message translates to:
  /// **'Download new stories on Wi-Fi'**
  String get settingsAutoUpdate;

  /// Settings: subtitle of the Wi-Fi download switch.
  ///
  /// In en, this message translates to:
  /// **'Never on mobile data. Off: you tap Download.'**
  String get settingsAutoUpdateDetail;

  /// Settings: row that opens the hosted privacy policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// Settings: row that opens the open-source licence page.
  ///
  /// In en, this message translates to:
  /// **'Licences'**
  String get settingsLicences;

  /// Settings: row that writes a mail to support (the address is the subtitle).
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get settingsSupport;

  /// Settings: row showing the app version and build.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// Settings: red button at the end of the panel.
  ///
  /// In en, this message translates to:
  /// **'Reset all progress'**
  String get settingsReset;

  /// Settings: title of the reset confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Reset all progress?'**
  String get settingsResetQuestion;

  /// Settings: body of the reset confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'This deletes your streak, finished stories and saved words. It can\'t be undone.'**
  String get settingsResetDetail;

  /// Settings: reset dialog button that keeps everything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// Settings: reset dialog button that deletes all progress.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDelete;

  /// Settings: row that checks the content server for new stories now.
  ///
  /// In en, this message translates to:
  /// **'New stories'**
  String get contentCheckTitle;

  /// Settings: subtitle of the New stories row when new stories are waiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new story: download it from Stories} other{{count} new stories: download them from Stories}}'**
  String contentCheckAvailable(int count);

  /// Settings: subtitle of the New stories row when the content needs a newer app.
  ///
  /// In en, this message translates to:
  /// **'Update the app to get new stories'**
  String get contentCheckAppTooOld;

  /// Settings: subtitle of the New stories row when nothing is new.
  ///
  /// In en, this message translates to:
  /// **'Checked once a day when you open the app'**
  String get contentCheckNone;

  /// Settings: snack bar after tapping New stories when nothing is new.
  ///
  /// In en, this message translates to:
  /// **'You have every story. Check again tomorrow.'**
  String get contentCheckUpToDate;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
