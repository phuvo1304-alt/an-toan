// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'An Toàn';

  @override
  String get homeTitle => 'An Toàn';

  @override
  String get homeSubtitle => 'Check before you trust. Learn to spot scams.';

  @override
  String get cardCheckMessage => 'Check a message';

  @override
  String get cardCheckMessageDesc => 'Paste a message or pick a screenshot';

  @override
  String get cardCheckPhone => 'Check a phone number';

  @override
  String get cardCheckPhoneDesc => 'See if the community reported this number';

  @override
  String get cardTraining => 'Train';

  @override
  String get cardTrainingDesc => 'Practice scenarios to spot the traps';

  @override
  String get cardQuiz => 'Quiz';

  @override
  String get cardQuizDesc => 'Questions: is this a scam?';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageVi => 'Tiếng Việt';

  @override
  String get languageEn => 'English';

  @override
  String get disclaimerTitle => 'Important';

  @override
  String get disclaimerBody =>
      'Results are AI-generated guidance only, not legal or professional advice, and they can be wrong. An Toàn never says a message is 100% safe. If you are unsure, ask a trusted adult or contact the authorities.';

  @override
  String get privacyNote =>
      'Content you submit for checking is sent to an AI service for analysis. Do not send passwords, OTP codes or banking details.';

  @override
  String get checkerTitle => 'Check a message';

  @override
  String get tabText => 'Text';

  @override
  String get tabScreenshot => 'Screenshot';

  @override
  String get pasteHint =>
      'Paste the message, SMS, email or chat you want to check here...';

  @override
  String get pickImage => 'Pick a screenshot';

  @override
  String get changeImage => 'Pick another image';

  @override
  String get noImageSelected => 'No image selected';

  @override
  String get checkButton => 'Check';

  @override
  String get checking => 'Analyzing...';

  @override
  String get resultTitle => 'Result';

  @override
  String get riskSafe => 'Looks safe';

  @override
  String get riskSuspicious => 'Suspicious';

  @override
  String get riskLikelyScam => 'Likely a scam';

  @override
  String get scoreLabel => 'Risk score';

  @override
  String get redFlags => 'Warning signs';

  @override
  String get noRedFlags => 'No clear warning signs found.';

  @override
  String get whatToDo => 'What to do';

  @override
  String get notVerified => 'Could not verify';

  @override
  String get checkAnother => 'Check another';

  @override
  String get errorEmpty => 'Enter some text or pick an image first.';

  @override
  String get errorTooLong =>
      'The text is too long. Please shorten it (max 4000 characters).';

  @override
  String get errorImageTooLarge =>
      'The image is too large. Please pick a smaller one.';

  @override
  String get errorRateLimited =>
      'You have checked too many times. Please try again later.';

  @override
  String get errorNetwork =>
      'No internet connection. Check your connection and try again.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again later.';

  @override
  String get errorNotConfigured =>
      'The app has no server configured (SUPABASE_URL is missing).';

  @override
  String get retry => 'Retry';

  @override
  String get officialHelpTitle => 'Need help?';

  @override
  String get officialHelpBody =>
      'If you have been scammed, tell your family, your bank and your local police right away. Check the latest official contact numbers on the authorities\' official websites.';

  @override
  String get quizTitle => 'Quiz';

  @override
  String get quizIntro =>
      'Read each message and decide whether it is a scam. After each answer you will see an explanation.';

  @override
  String get quizStart => 'Start';

  @override
  String quizQuestionProgress(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get quizPrompt => 'Is this message a scam?';

  @override
  String get quizAnswerScam => 'Scam';

  @override
  String get quizAnswerNotScam => 'Not a scam';

  @override
  String get quizCorrect => 'Correct!';

  @override
  String get quizWrong => 'Not quite';

  @override
  String get quizItWasScam => 'This message is a scam.';

  @override
  String get quizItWasNotScam => 'This is a normal message.';

  @override
  String get quizNext => 'Next';

  @override
  String get quizSeeResults => 'See results';

  @override
  String quizScore(int correct, int total) {
    return 'Score: $correct/$total';
  }

  @override
  String quizStreak(int count) {
    return 'Streak: $count';
  }

  @override
  String get quizSummaryTitle => 'Finished!';

  @override
  String quizRoundBestStreak(int count) {
    return 'Longest streak this round: $count';
  }

  @override
  String quizBest(int correct, int total) {
    return 'Best: $correct/$total';
  }

  @override
  String quizBestStreak(int count) {
    return 'Best streak: $count';
  }

  @override
  String get quizNoBestYet => 'No best score yet. Play your first round!';

  @override
  String get quizNewRecord => 'New record!';

  @override
  String get quizPlayAgain => 'Play again';

  @override
  String get quizBackHome => 'Back to home';
}
