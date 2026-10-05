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

  @override
  String get phoneTitle => 'Check a phone number';

  @override
  String get phoneCommunityNote =>
      'This information is reported by users, not verified. A number with no reports is not necessarily safe.';

  @override
  String get phoneNumberLabel => 'Phone number';

  @override
  String get phoneNumberHint => 'e.g. 0901 234 567';

  @override
  String get phoneCheck => 'Check';

  @override
  String get phoneInvalid =>
      'Invalid number. Enter a Vietnamese mobile number, e.g. 0901 234 567 or +84 901 234 567.';

  @override
  String get phoneNoReports => 'No reports yet';

  @override
  String get phoneNoReportsNote =>
      'Nobody has reported this number. That does not guarantee it is safe, so stay careful.';

  @override
  String phoneReportedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reported by $count users',
      one: 'Reported by 1 user',
    );
    return '$_temp0';
  }

  @override
  String phoneCategoryCount(String category, int count) {
    return '$category: $count';
  }

  @override
  String phoneLastReported(String date) {
    return 'Last reported: $date';
  }

  @override
  String get phoneReportsNote =>
      'These are user reports and can be wrong. A report does not prove who owns this number.';

  @override
  String get phoneReportTitle => 'Report this number';

  @override
  String get phoneReportIntro =>
      'If this number called or texted you with a scam, report it to warn others. Do not include names, addresses or personal details.';

  @override
  String get phoneCategoryLabel => 'Type of scam';

  @override
  String get phoneCategoryRequired => 'Please choose a type of scam.';

  @override
  String get phoneDescriptionLabel => 'Short description (optional)';

  @override
  String get phoneDescriptionTooLong =>
      'The description is too long (max 300 characters).';

  @override
  String get phoneSubmit => 'Send report';

  @override
  String get phoneReportSuccess =>
      'Report sent. Thank you for helping warn others!';

  @override
  String get phoneReportRateLimited =>
      'You have sent too many reports. Please try again in an hour.';

  @override
  String get phoneCatImpersonation => 'Pretending to be police or officials';

  @override
  String get phoneCatFakeBank => 'Pretending to be a bank or e-wallet';

  @override
  String get phoneCatFakeJob => 'Fake job, easy money tasks';

  @override
  String get phoneCatInvestment => 'Investment, crypto';

  @override
  String get phoneCatLoan => 'Loans';

  @override
  String get phoneCatShopping => 'Shopping, delivery';

  @override
  String get phoneCatSpam => 'Ads, nuisance calls';

  @override
  String get phoneCatOther => 'Other';

  @override
  String get onboardingWelcomeBody =>
      'Paste a message or pick a screenshot, and An Toàn tells you whether it looks like a scam, why, and what to do next.';

  @override
  String get onboardingLanguageTitle => 'Choose your language';

  @override
  String get onboardingLanguageBody =>
      'You can change it any time in Settings.';

  @override
  String get onboardingPrivacyTitle => 'Your privacy';

  @override
  String get onboardingPrivacyBody =>
      'Content you submit for checking is sent to an AI service for analysis. Results are AI-generated and can be wrong. The app needs no login and collects no personal data. Do not send passwords, OTP codes or banking details.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String privacyPolicyOpenError(String url) {
    return 'Could not open the page. You can open it yourself: $url';
  }
}
