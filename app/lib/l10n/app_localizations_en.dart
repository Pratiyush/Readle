// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabStories => 'Stories';

  @override
  String get tabWords => 'Words';

  @override
  String get tabProgress => 'Progress';

  @override
  String get libraryTitle => 'Stories';

  @override
  String get libraryLoadError => 'Couldn\'t load stories.';

  @override
  String get libraryAllLevels => 'All levels';

  @override
  String get libraryUnread => 'Unread';

  @override
  String get librarySearchHint => 'Search stories…';

  @override
  String get libraryNoMatches => 'No stories match these filters.';

  @override
  String get collectionAll => 'All';

  @override
  String get collectionFiction => 'Fiction';

  @override
  String get collectionCulture => 'Culture';

  @override
  String get collectionFacts => 'Facts';

  @override
  String get libraryContinueReading => 'CONTINUE READING';

  @override
  String get libraryKeepGoing => 'KEEP GOING — NEXT UP';

  @override
  String get libraryStoryOfTheDay => 'STORY OF THE DAY';

  @override
  String storyCardMeta(int minutes, String collection) {
    return '$minutes min · $collection';
  }

  @override
  String get storyRead => '✓ Read';

  @override
  String get updateBannerAppTooOld => 'Update the app to get new stories.';

  @override
  String updateBannerNewStories(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '📚 $count new stories to read', one: '📚 1 new story to read');
    return '$_temp0';
  }

  @override
  String get updateBannerUpdateApp => 'Update app';

  @override
  String get updateBannerDownload => 'Download';

  @override
  String get updateBannerDownloadFailed => 'Couldn\'t download the new stories. Try again later.';

  @override
  String get backToStories => 'Back to stories';

  @override
  String get readerLoadError => 'This story couldn\'t be loaded.';

  @override
  String get readerListen => 'Listen';

  @override
  String get readerStop => 'Stop';

  @override
  String get readerTranslations => 'EN';

  @override
  String get readerTextSize => 'Aa';

  @override
  String readerStoryMeta(int minutes, int words) {
    String _temp0 = intl.Intl.pluralLogic(words, locale: localeName, other: '$words words');
    return '$minutes min read · $_temp0';
  }

  @override
  String get readerTip => 'Tap any word for its meaning. Tap ⇄ for a sentence translation.';

  @override
  String get readerFirstTip => 'Tap any word to hear it and see what it means. Tap ⇄ to translate a sentence.';

  @override
  String get readerQuizAgain => 'Take the quiz again';

  @override
  String get readerFinish => 'Finish & take the quiz';

  @override
  String readerTranslateSentence(int number) {
    return 'Translate sentence $number';
  }

  @override
  String get readerListenFromHere => 'Listen from here';

  @override
  String get wordSheetPronounce => 'Pronounce';

  @override
  String get wordSheetClose => 'Close';

  @override
  String pluralDie(String plural) {
    return 'plural: die $plural';
  }

  @override
  String get wordSheetNoEntry => 'No dictionary entry for this word (often a name). The sentence translation below should help.';

  @override
  String wordSheetCompound(String word, String headword) {
    return '$word is a compound — this is the meaning of its last part, $headword.';
  }

  @override
  String wordSheetFormOf(String word, String headword) {
    return '$word is a form of $headword.';
  }

  @override
  String get wordSheetInThisStory => 'IN THIS STORY';

  @override
  String get wordSheetSaved => '✓ Saved to your words';

  @override
  String get wordSheetSave => '＋ Save to my words';

  @override
  String get wordsEyebrow => 'YOUR VOCABULARY';

  @override
  String get wordsTitle => 'Words';

  @override
  String wordsDue(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count words to review', one: '1 word to review');
    return '$_temp0';
  }

  @override
  String get wordsAllCaughtUp => 'All caught up!';

  @override
  String get wordsNone => 'No words yet';

  @override
  String wordsSavedSummary(int total) {
    return '$total saved · spaced repetition brings each word back just before you\'d forget it.';
  }

  @override
  String get wordsEmptyHint => 'Tap words while reading and save them here.';

  @override
  String get wordsPractice => 'Practice';

  @override
  String get wordFilterAll => 'All';

  @override
  String get wordFilterDue => 'Due';

  @override
  String get wordFilterLearning => 'Learning';

  @override
  String get wordFilterMastered => 'Mastered';

  @override
  String wordsPronounce(String word) {
    return 'Pronounce $word';
  }

  @override
  String wordsStrength(int box) {
    return 'Strength $box of 6';
  }

  @override
  String wordsRemove(String word) {
    return 'Remove $word';
  }

  @override
  String get practiceNothingToReview => 'Nothing to review';

  @override
  String get practiceSessionComplete => 'Session complete';

  @override
  String practiceScore(int right, int total) {
    return '$right of $total remembered.';
  }

  @override
  String get practiceBackToWords => 'Back to words';

  @override
  String get practiceEnd => 'End practice';

  @override
  String get practiceRevealHint => 'Do you remember it? Tap to reveal.';

  @override
  String get practiceNoEntry => '(no dictionary entry)';

  @override
  String get practiceListen => 'Listen';

  @override
  String get practiceShowAnswer => 'Show answer';

  @override
  String get practiceDidntKnow => 'Didn\'t know';

  @override
  String get practiceKnewIt => 'Knew it';

  @override
  String get quizLoadError => 'Couldn\'t load the quiz.';

  @override
  String get quizClose => 'Close quiz';

  @override
  String get quizWordQuestion => 'WHAT DOES THIS WORD MEAN?';

  @override
  String get quizSentenceQuestion => 'WHAT DOES THIS SENTENCE MEAN?';

  @override
  String get quizNotQuite => 'Not quite.';

  @override
  String get quizSeeResults => 'See results';

  @override
  String get quizContinue => 'Continue';

  @override
  String quizFinished(String title) {
    return 'You finished “$title”.';
  }

  @override
  String get quizScore => 'quiz score';

  @override
  String get quizNextStory => 'Next story';

  @override
  String get quizTryAgain => 'Try the quiz again';

  @override
  String statDayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'day streak');
    return '$_temp0';
  }

  @override
  String statStoriesRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'stories read');
    return '$_temp0';
  }

  @override
  String statWordsSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'words saved');
    return '$_temp0';
  }

  @override
  String statWordsMastered(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'words mastered');
    return '$_temp0';
  }

  @override
  String get onboardingIntro => 'Read short German stories and tap any word you don’t know. Which stories suit you?';

  @override
  String get onboardingA1Name => 'Beginner';

  @override
  String get onboardingA1Blurb => 'I know a few words and phrases';

  @override
  String get onboardingA2Name => 'Elementary';

  @override
  String get onboardingA2Blurb => 'I understand simple everyday sentences';

  @override
  String get onboardingB1Name => 'Intermediate';

  @override
  String get onboardingB1Blurb => 'I can follow clear texts on familiar topics';

  @override
  String get onboardingB2Name => 'Upper intermediate';

  @override
  String get onboardingB2Blurb => 'I read most everyday German';

  @override
  String get onboardingChangeLater => 'You can change this any time in Settings.';

  @override
  String get onboardingNotSure => 'Not sure? Start at A1';

  @override
  String get onboardingNotSureDetail => 'Every level in order, moving up as you read';

  @override
  String get progressEyebrow => 'YOUR PROGRESS';

  @override
  String get progressTitle => 'Progress';

  @override
  String get progressGoalReached => 'Daily goal reached! 🎉';

  @override
  String get progressTodaysGoal => 'Today\'s goal';

  @override
  String progressGoalText(int goal) {
    String _temp0 = intl.Intl.pluralLogic(goal, locale: localeName, other: 'Read $goal stories a day.', one: 'Read 1 story a day.');
    return '$_temp0';
  }

  @override
  String get progressByLevel => 'Stories by level';

  @override
  String get progressCredits =>
      'Stories and dictionary from the Lernle project. German text is machine-assisted and awaiting native review.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsStoryLevel => 'Story level';

  @override
  String get settingsLevelAll => 'All levels, A1 → B2';

  @override
  String get settingsLevelA1 => 'A1 · beginner';

  @override
  String get settingsLevelA2 => 'A2 · elementary';

  @override
  String get settingsLevelB1 => 'B1 · intermediate';

  @override
  String get settingsLevelB2 => 'B2 · upper intermediate';

  @override
  String get settingsDailyGoal => 'Daily goal';

  @override
  String settingsDailyGoalOption(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count stories', one: '1 story');
    return '$_temp0';
  }

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsSpeechSpeed => 'Speech speed';

  @override
  String get speechSlow => 'Slow';

  @override
  String get speechNormal => 'Normal';

  @override
  String get speechFast => 'Fast';

  @override
  String get settingsSayWords => 'Say words when tapped';

  @override
  String get settingsReminder => 'Daily reminder';

  @override
  String get settingsReminderDetail => 'One a day, skipped once you have read';

  @override
  String get settingsNotificationsDenied => 'Notifications are off for Readle. Allow them in system settings to get the reminder.';

  @override
  String get settingsNotificationsBlocked => 'Notifications are off for Readle';

  @override
  String get settingsNotificationsBlockedDetail => 'The reminder can\'t show. Tap to allow notifications.';

  @override
  String get settingsReminderTime => 'Reminder time';

  @override
  String get settingsPrivacyChoices => 'Privacy & ad choices';

  @override
  String get settingsAutoUpdate => 'Download new stories on Wi-Fi';

  @override
  String get settingsAutoUpdateDetail => 'Never on mobile data. Off: you tap Download.';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsLicences => 'Licences';

  @override
  String get settingsSupport => 'Contact support';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsReset => 'Reset all progress';

  @override
  String get settingsResetQuestion => 'Reset all progress?';

  @override
  String get settingsResetDetail => 'This deletes your streak, finished stories and saved words. It can\'t be undone.';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsDelete => 'Delete';

  @override
  String get contentCheckTitle => 'New stories';

  @override
  String contentCheckAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new stories: download them from Stories',
      one: '1 new story: download it from Stories',
    );
    return '$_temp0';
  }

  @override
  String get contentCheckAppTooOld => 'Update the app to get new stories';

  @override
  String get contentCheckNone => 'Checked once a day when you open the app';

  @override
  String get contentCheckUpToDate => 'You have every story. Check again tomorrow.';
}
