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
  String get realCasesTitle => 'Real reported cases';

  @override
  String get realCasesDisclaimer =>
      'These are other real cases reported with similar tactics, not proof about your message.';

  @override
  String get readArticle => 'Read article';

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
      'You have sent too many reports today. Please try again tomorrow.';

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

  @override
  String get trainingTitle => 'Training';

  @override
  String get trainingIntro =>
      'Each scenario is a simulated message. Find the suspicious parts, then see how many you spotted.';

  @override
  String get trainingInstructions =>
      'Tap the parts you think are suspicious (tap again to unmark), then press Submit.';

  @override
  String get trainingResultIntro =>
      'Results: green means you spotted it, red means you missed it, amber is a normal part you marked by mistake.';

  @override
  String get trainingSubmit => 'Submit';

  @override
  String get trainingCaughtLabel => 'You spotted this';

  @override
  String get trainingMissedLabel => 'You missed this';

  @override
  String get trainingFalsePositiveLabel => 'This part is fine';

  @override
  String trainingSummaryCaught(int caught, int total) {
    return 'You spotted $caught/$total red flags';
  }

  @override
  String trainingSummaryFalsePositives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count normal parts marked by mistake',
      one: '1 normal part marked by mistake',
      zero: 'No normal parts marked by mistake',
    );
    return '$_temp0';
  }

  @override
  String get trainingTryAgain => 'Try again';

  @override
  String get trainingBackToList => 'Back to scenarios';

  @override
  String get scamTypeFakeJob => 'Fake job';

  @override
  String get scamTypeFakeScholarship => 'Fake scholarship';

  @override
  String get scamTypePhishing => 'Phishing link';

  @override
  String get scamTypeImpersonation => 'Impersonation';

  @override
  String get scamTypeInvestment => 'Investment';

  @override
  String get scamTypeRomance => 'Romance scam';

  @override
  String get scamTypeLoan => 'Loan';

  @override
  String get scamTypeOther => 'Other';

  @override
  String get tabAudio => 'Voice';

  @override
  String get recordStart =>
      'Tap the mic and speak (or play a voice message near the phone)';

  @override
  String get recordStop => 'Stop';

  @override
  String get listening => 'Listening...';

  @override
  String get audioPreparing => 'Getting the microphone ready...';

  @override
  String audioSecondsLeft(int seconds) {
    return '${seconds}s left';
  }

  @override
  String get transcriptHint =>
      'Your speech appears here as text. You can edit it before you press Check.';

  @override
  String get noSpeechDetected =>
      'No speech was heard. Try again somewhere quiet, speak more clearly, or type the content in the box.';

  @override
  String get audioTranscriptEmpty =>
      'There is nothing to check yet. Tap the mic and speak, or type the content in the box first.';

  @override
  String get audioPermissionDenied =>
      'An Toàn is not allowed to use the microphone, so it cannot listen. To allow it: open your phone\'s Settings, then Apps, An Toàn, Permissions, and allow Microphone. Or use the Text tab to type it.';

  @override
  String get audioLocaleUnavailable =>
      'English voice input isn\'t available on this device. Please use the Text tab to type it instead.';

  @override
  String get audioNotSupported =>
      'This device does not support speech recognition. Please use the Text tab to type or paste the content.';

  @override
  String get audioNotSupportedShort =>
      'Voice input is not available on this device';

  @override
  String get audioFailed =>
      'Speech recognition did not work just now. Try again, or use the Text tab.';

  @override
  String get phoneAlreadyReported =>
      'You already reported this number in the last 24 hours. Thank you, one report per person is enough.';

  @override
  String get phoneDisputeAction => 'Looks wrong? Flag it';

  @override
  String get phoneDisputeConfirmTitle => 'Do these reports look wrong?';

  @override
  String get phoneDisputeConfirmBody =>
      'If you think the reports about this number are wrong (for example it is your number or someone you know), flag it. When enough people flag a report, it stops being counted and is reviewed. You can flag each number only once.';

  @override
  String get phoneDisputeCancel => 'Cancel';

  @override
  String get phoneDisputeConfirm => 'Flag it';

  @override
  String get phoneDisputeSuccess =>
      'Thanks, noted. You are helping keep this information accurate.';

  @override
  String get phoneAlreadyDisputed => 'You have already flagged this number.';

  @override
  String get phoneNothingToDispute =>
      'There are no reports left on this number to flag.';

  @override
  String get phoneDisputeRateLimited =>
      'You have flagged too many times today. Please try again tomorrow.';

  @override
  String get trainingDifficultyEasy => 'Easy';

  @override
  String get trainingDifficultyMedium => 'Medium';

  @override
  String get trainingDifficultyHard => 'Hard';

  @override
  String get trainingSummaryNoFlags =>
      'This message was safe: there were no red flags to find';

  @override
  String get trainingResultIntroSafe =>
      'Results: this message had no red flags. Any amber part is a normal part you marked by mistake.';

  @override
  String addImages(int count, int max) {
    return 'Add screenshots ($count/$max)';
  }

  @override
  String removeImage(int number) {
    return 'Remove screenshot $number';
  }

  @override
  String get imagesLimitReached => 'Up to 3 screenshots per check';

  @override
  String get imagesOrderHint =>
      'Screenshots are sent in order 1, 2, 3, as one conversation.';

  @override
  String get imageUnsupported =>
      'This image could not be read. Please pick a JPG or PNG screenshot.';

  @override
  String get errorTooManyImages =>
      'You can check at most 3 screenshots at a time. Remove some and try again.';

  @override
  String get phoneCommentsTitle => 'Comments from users';

  @override
  String get phoneCommentsEmpty => 'No comments for this number yet.';

  @override
  String get phoneCommentsLoadMore => 'Show more comments';

  @override
  String get phoneCommentDisputeAction => 'Looks wrong? Flag it';

  @override
  String get phoneCommentDisputeSemantics => 'Flag this comment';

  @override
  String get phoneCommentDisputeConfirmTitle => 'Does this comment look wrong?';

  @override
  String get phoneCommentDisputeConfirmBody =>
      'If this comment is untrue, insults someone or contains personal details, flag it. When enough people flag it, the comment is hidden and reviewed. You can flag each comment only once.';

  @override
  String get phoneCommentDisputeSuccess =>
      'Thanks, this comment has been flagged.';

  @override
  String get phoneCommentAlreadyDisputed =>
      'You have already flagged this comment.';

  @override
  String get phoneCommentDisputeRateLimited =>
      'You\'ve flagged a lot today. Thank you for helping keep this accurate! You can try again tomorrow.';

  @override
  String get phoneCommentUnavailable => 'This comment is no longer shown.';

  @override
  String get phoneCommentToday => 'Today';

  @override
  String get phoneCommentYesterday => 'Yesterday';

  @override
  String phoneCommentDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String phoneCommentMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String phoneCommentYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }
}
