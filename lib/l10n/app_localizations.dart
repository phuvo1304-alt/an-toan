import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appName.
  ///
  /// In vi, this message translates to:
  /// **'An Toàn'**
  String get appName;

  /// No description provided for @homeTitle.
  ///
  /// In vi, this message translates to:
  /// **'An Toàn'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra trước khi tin. Học cách nhận ra lừa đảo.'**
  String get homeSubtitle;

  /// No description provided for @cardCheckMessage.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra tin nhắn'**
  String get cardCheckMessage;

  /// No description provided for @cardCheckMessageDesc.
  ///
  /// In vi, this message translates to:
  /// **'Dán tin nhắn hoặc chọn ảnh chụp màn hình'**
  String get cardCheckMessageDesc;

  /// No description provided for @cardCheckPhone.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra số điện thoại'**
  String get cardCheckPhone;

  /// No description provided for @cardCheckPhoneDesc.
  ///
  /// In vi, this message translates to:
  /// **'Xem cộng đồng có báo cáo số này không'**
  String get cardCheckPhoneDesc;

  /// No description provided for @cardTraining.
  ///
  /// In vi, this message translates to:
  /// **'Luyện tập'**
  String get cardTraining;

  /// No description provided for @cardTrainingDesc.
  ///
  /// In vi, this message translates to:
  /// **'Tình huống mô phỏng để nhận ra bẫy'**
  String get cardTrainingDesc;

  /// No description provided for @cardQuiz.
  ///
  /// In vi, this message translates to:
  /// **'Đố vui'**
  String get cardQuiz;

  /// No description provided for @cardQuizDesc.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi: đây có phải lừa đảo không?'**
  String get cardQuizDesc;

  /// No description provided for @comingSoon.
  ///
  /// In vi, this message translates to:
  /// **'Sắp ra mắt'**
  String get comingSoon;

  /// No description provided for @settings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get language;

  /// No description provided for @languageVi.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get languageVi;

  /// No description provided for @languageEn.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @disclaimerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ý quan trọng'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerBody.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả do AI tạo ra chỉ mang tính tham khảo, không phải tư vấn pháp lý hay chuyên môn, và có thể sai. An Toàn không bao giờ khẳng định một tin nhắn là an toàn tuyệt đối. Nếu còn nghi ngờ, hãy hỏi người lớn đáng tin cậy hoặc liên hệ cơ quan chức năng.'**
  String get disclaimerBody;

  /// No description provided for @privacyNote.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung bạn gửi đi để kiểm tra sẽ được chuyển đến dịch vụ AI để phân tích. Đừng gửi mật khẩu, mã OTP hay thông tin ngân hàng.'**
  String get privacyNote;

  /// No description provided for @checkerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra tin nhắn'**
  String get checkerTitle;

  /// No description provided for @tabText.
  ///
  /// In vi, this message translates to:
  /// **'Văn bản'**
  String get tabText;

  /// No description provided for @tabScreenshot.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh'**
  String get tabScreenshot;

  /// No description provided for @pasteHint.
  ///
  /// In vi, this message translates to:
  /// **'Dán tin nhắn, SMS, email hoặc nội dung chat cần kiểm tra vào đây...'**
  String get pasteHint;

  /// No description provided for @pickImage.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh chụp màn hình'**
  String get pickImage;

  /// No description provided for @changeImage.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh khác'**
  String get changeImage;

  /// No description provided for @noImageSelected.
  ///
  /// In vi, this message translates to:
  /// **'Chưa chọn ảnh'**
  String get noImageSelected;

  /// No description provided for @checkButton.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra'**
  String get checkButton;

  /// No description provided for @checking.
  ///
  /// In vi, this message translates to:
  /// **'Đang phân tích...'**
  String get checking;

  /// No description provided for @resultTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả'**
  String get resultTitle;

  /// No description provided for @riskSafe.
  ///
  /// In vi, this message translates to:
  /// **'Có vẻ an toàn'**
  String get riskSafe;

  /// No description provided for @riskSuspicious.
  ///
  /// In vi, this message translates to:
  /// **'Đáng nghi'**
  String get riskSuspicious;

  /// No description provided for @riskLikelyScam.
  ///
  /// In vi, this message translates to:
  /// **'Có khả năng là lừa đảo'**
  String get riskLikelyScam;

  /// No description provided for @scoreLabel.
  ///
  /// In vi, this message translates to:
  /// **'Điểm rủi ro'**
  String get scoreLabel;

  /// No description provided for @redFlags.
  ///
  /// In vi, this message translates to:
  /// **'Dấu hiệu cảnh báo'**
  String get redFlags;

  /// No description provided for @noRedFlags.
  ///
  /// In vi, this message translates to:
  /// **'Không thấy dấu hiệu rõ ràng.'**
  String get noRedFlags;

  /// No description provided for @whatToDo.
  ///
  /// In vi, this message translates to:
  /// **'Bạn nên làm gì'**
  String get whatToDo;

  /// No description provided for @notVerified.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thể xác minh'**
  String get notVerified;

  /// No description provided for @checkAnother.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra tin khác'**
  String get checkAnother;

  /// No description provided for @errorEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập nội dung hoặc chọn một ảnh trước.'**
  String get errorEmpty;

  /// No description provided for @errorTooLong.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung quá dài. Hãy rút gọn lại (tối đa 4000 ký tự).'**
  String get errorTooLong;

  /// No description provided for @errorImageTooLarge.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh quá lớn. Hãy chọn ảnh nhỏ hơn.'**
  String get errorImageTooLarge;

  /// No description provided for @errorRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã kiểm tra quá nhiều lần. Vui lòng thử lại sau.'**
  String get errorRateLimited;

  /// No description provided for @errorNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Không có kết nối mạng. Hãy kiểm tra internet rồi thử lại.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra. Vui lòng thử lại sau.'**
  String get errorGeneric;

  /// No description provided for @errorNotConfigured.
  ///
  /// In vi, this message translates to:
  /// **'Ứng dụng chưa được cấu hình máy chủ (thiếu SUPABASE_URL).'**
  String get errorNotConfigured;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get retry;

  /// No description provided for @officialHelpTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cần giúp đỡ?'**
  String get officialHelpTitle;

  /// No description provided for @officialHelpBody.
  ///
  /// In vi, this message translates to:
  /// **'Nếu bạn đã bị lừa, hãy báo ngay cho gia đình, ngân hàng của bạn và cơ quan công an địa phương. Hãy kiểm tra số liên hệ chính thức mới nhất trên cổng thông tin của cơ quan chức năng.'**
  String get officialHelpBody;

  /// No description provided for @quizTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đố vui'**
  String get quizTitle;

  /// No description provided for @quizIntro.
  ///
  /// In vi, this message translates to:
  /// **'Đọc từng tin nhắn và đoán xem đó có phải lừa đảo không. Sau mỗi câu, bạn sẽ thấy lời giải thích.'**
  String get quizIntro;

  /// No description provided for @quizStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get quizStart;

  /// No description provided for @quizQuestionProgress.
  ///
  /// In vi, this message translates to:
  /// **'Câu {current}/{total}'**
  String quizQuestionProgress(int current, int total);

  /// No description provided for @quizPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn này có phải lừa đảo không?'**
  String get quizPrompt;

  /// No description provided for @quizAnswerScam.
  ///
  /// In vi, this message translates to:
  /// **'Lừa đảo'**
  String get quizAnswerScam;

  /// No description provided for @quizAnswerNotScam.
  ///
  /// In vi, this message translates to:
  /// **'Không phải lừa đảo'**
  String get quizAnswerNotScam;

  /// No description provided for @quizCorrect.
  ///
  /// In vi, this message translates to:
  /// **'Chính xác!'**
  String get quizCorrect;

  /// No description provided for @quizWrong.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đúng'**
  String get quizWrong;

  /// No description provided for @quizItWasScam.
  ///
  /// In vi, this message translates to:
  /// **'Đây là tin nhắn lừa đảo.'**
  String get quizItWasScam;

  /// No description provided for @quizItWasNotScam.
  ///
  /// In vi, this message translates to:
  /// **'Đây là tin nhắn bình thường.'**
  String get quizItWasNotScam;

  /// No description provided for @quizNext.
  ///
  /// In vi, this message translates to:
  /// **'Câu tiếp theo'**
  String get quizNext;

  /// No description provided for @quizSeeResults.
  ///
  /// In vi, this message translates to:
  /// **'Xem kết quả'**
  String get quizSeeResults;

  /// No description provided for @quizScore.
  ///
  /// In vi, this message translates to:
  /// **'Điểm: {correct}/{total}'**
  String quizScore(int correct, int total);

  /// No description provided for @quizStreak.
  ///
  /// In vi, this message translates to:
  /// **'Chuỗi đúng: {count}'**
  String quizStreak(int count);

  /// No description provided for @quizSummaryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành!'**
  String get quizSummaryTitle;

  /// No description provided for @quizRoundBestStreak.
  ///
  /// In vi, this message translates to:
  /// **'Chuỗi đúng dài nhất lượt này: {count}'**
  String quizRoundBestStreak(int count);

  /// No description provided for @quizBest.
  ///
  /// In vi, this message translates to:
  /// **'Kỷ lục: {correct}/{total}'**
  String quizBest(int correct, int total);

  /// No description provided for @quizBestStreak.
  ///
  /// In vi, this message translates to:
  /// **'Chuỗi đúng kỷ lục: {count}'**
  String quizBestStreak(int count);

  /// No description provided for @quizNoBestYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có kỷ lục. Hãy chơi lượt đầu tiên!'**
  String get quizNoBestYet;

  /// No description provided for @quizNewRecord.
  ///
  /// In vi, this message translates to:
  /// **'Kỷ lục mới!'**
  String get quizNewRecord;

  /// No description provided for @quizPlayAgain.
  ///
  /// In vi, this message translates to:
  /// **'Chơi lại'**
  String get quizPlayAgain;

  /// No description provided for @quizBackHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get quizBackHome;

  /// No description provided for @phoneTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra số điện thoại'**
  String get phoneTitle;

  /// No description provided for @phoneCommunityNote.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin ở đây do người dùng báo cáo, không phải kết quả xác minh. Một số chưa có báo cáo không có nghĩa là an toàn.'**
  String get phoneCommunityNote;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get phoneNumberLabel;

  /// No description provided for @phoneNumberHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: 0901 234 567'**
  String get phoneNumberHint;

  /// No description provided for @phoneCheck.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra'**
  String get phoneCheck;

  /// No description provided for @phoneInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Số không hợp lệ. Hãy nhập số di động Việt Nam, ví dụ 0901 234 567 hoặc +84 901 234 567.'**
  String get phoneInvalid;

  /// No description provided for @phoneNoReports.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có báo cáo nào'**
  String get phoneNoReports;

  /// No description provided for @phoneNoReportsNote.
  ///
  /// In vi, this message translates to:
  /// **'Chưa ai báo cáo số này. Điều đó không đảm bảo số này an toàn, hãy luôn cẩn thận.'**
  String get phoneNoReportsNote;

  /// No description provided for @phoneReportedBy.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, other{Được {count} người dùng báo cáo}}'**
  String phoneReportedBy(int count);

  /// No description provided for @phoneCategoryCount.
  ///
  /// In vi, this message translates to:
  /// **'{category}: {count}'**
  String phoneCategoryCount(String category, int count);

  /// No description provided for @phoneLastReported.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo gần nhất: {date}'**
  String phoneLastReported(String date);

  /// No description provided for @phoneReportsNote.
  ///
  /// In vi, this message translates to:
  /// **'Đây là báo cáo của người dùng, có thể sai. Báo cáo không chứng minh ai là chủ của số này.'**
  String get phoneReportsNote;

  /// No description provided for @phoneReportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo số này'**
  String get phoneReportTitle;

  /// No description provided for @phoneReportIntro.
  ///
  /// In vi, this message translates to:
  /// **'Nếu số trên đã gọi hoặc nhắn tin lừa đảo bạn, hãy báo cáo để cảnh báo người khác. Không ghi tên, địa chỉ hay thông tin cá nhân.'**
  String get phoneReportIntro;

  /// No description provided for @phoneCategoryLabel.
  ///
  /// In vi, this message translates to:
  /// **'Loại lừa đảo'**
  String get phoneCategoryLabel;

  /// No description provided for @phoneCategoryRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy chọn loại lừa đảo.'**
  String get phoneCategoryRequired;

  /// No description provided for @phoneDescriptionLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả ngắn (không bắt buộc)'**
  String get phoneDescriptionLabel;

  /// No description provided for @phoneDescriptionTooLong.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả quá dài (tối đa 300 ký tự).'**
  String get phoneDescriptionTooLong;

  /// No description provided for @phoneSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi báo cáo'**
  String get phoneSubmit;

  /// No description provided for @phoneReportSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi báo cáo. Cảm ơn bạn đã giúp cảnh báo mọi người!'**
  String get phoneReportSuccess;

  /// No description provided for @phoneReportRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã gửi quá nhiều báo cáo hôm nay. Vui lòng thử lại vào ngày mai.'**
  String get phoneReportRateLimited;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In vi, this message translates to:
  /// **'Dán tin nhắn hoặc chọn ảnh chụp màn hình, An Toàn sẽ cho bạn biết nó có giống lừa đảo không, vì sao, và nên làm gì tiếp theo.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingLanguageTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ'**
  String get onboardingLanguageTitle;

  /// No description provided for @onboardingLanguageBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thể đổi lại bất cứ lúc nào trong phần Cài đặt.'**
  String get onboardingLanguageBody;

  /// No description provided for @onboardingPrivacyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quyền riêng tư của bạn'**
  String get onboardingPrivacyTitle;

  /// No description provided for @onboardingPrivacyBody.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung bạn gửi để kiểm tra sẽ được chuyển đến một dịch vụ AI để phân tích. Kết quả do AI tạo ra và có thể sai. Ứng dụng không cần đăng nhập và không thu thập thông tin cá nhân. Đừng gửi mật khẩu, mã OTP hay thông tin ngân hàng.'**
  String get onboardingPrivacyBody;

  /// No description provided for @onboardingSkip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu sử dụng'**
  String get onboardingGetStarted;

  /// No description provided for @privacyPolicy.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách quyền riêng tư'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicyOpenError.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được trang. Bạn có thể tự mở: {url}'**
  String privacyPolicyOpenError(String url);

  /// No description provided for @trainingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Luyện tập'**
  String get trainingTitle;

  /// No description provided for @trainingIntro.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi tình huống là một tin nhắn mô phỏng. Hãy tìm những phần đáng ngờ, rồi xem bạn đã phát hiện được bao nhiêu.'**
  String get trainingIntro;

  /// No description provided for @trainingInstructions.
  ///
  /// In vi, this message translates to:
  /// **'Chạm vào những phần bạn thấy đáng ngờ (chạm lần nữa để bỏ chọn), rồi bấm Nộp bài.'**
  String get trainingInstructions;

  /// No description provided for @trainingResultIntro.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả: phần màu xanh là bạn phát hiện đúng, màu đỏ là bạn bỏ sót, màu cam là phần bình thường mà bạn đánh dấu nhầm.'**
  String get trainingResultIntro;

  /// No description provided for @trainingSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Nộp bài'**
  String get trainingSubmit;

  /// No description provided for @trainingCaughtLabel.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã phát hiện'**
  String get trainingCaughtLabel;

  /// No description provided for @trainingMissedLabel.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã bỏ sót'**
  String get trainingMissedLabel;

  /// No description provided for @trainingFalsePositiveLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phần này bình thường'**
  String get trainingFalsePositiveLabel;

  /// No description provided for @trainingSummaryCaught.
  ///
  /// In vi, this message translates to:
  /// **'Bạn phát hiện {caught}/{total} dấu hiệu đáng ngờ'**
  String trainingSummaryCaught(int caught, int total);

  /// No description provided for @trainingSummaryFalsePositives.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =0{Không đánh dấu nhầm phần nào} other{Đánh dấu nhầm {count} phần bình thường}}'**
  String trainingSummaryFalsePositives(int count);

  /// No description provided for @trainingTryAgain.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get trainingTryAgain;

  /// No description provided for @trainingBackToList.
  ///
  /// In vi, this message translates to:
  /// **'Về danh sách tình huống'**
  String get trainingBackToList;

  /// No description provided for @scamTypeFakeJob.
  ///
  /// In vi, this message translates to:
  /// **'Việc làm giả'**
  String get scamTypeFakeJob;

  /// No description provided for @scamTypeFakeScholarship.
  ///
  /// In vi, this message translates to:
  /// **'Học bổng giả'**
  String get scamTypeFakeScholarship;

  /// No description provided for @scamTypePhishing.
  ///
  /// In vi, this message translates to:
  /// **'Giả mạo đường link'**
  String get scamTypePhishing;

  /// No description provided for @scamTypeImpersonation.
  ///
  /// In vi, this message translates to:
  /// **'Giả danh'**
  String get scamTypeImpersonation;

  /// No description provided for @scamTypeInvestment.
  ///
  /// In vi, this message translates to:
  /// **'Đầu tư'**
  String get scamTypeInvestment;

  /// No description provided for @scamTypeRomance.
  ///
  /// In vi, this message translates to:
  /// **'Lừa đảo tình cảm'**
  String get scamTypeRomance;

  /// No description provided for @scamTypeLoan.
  ///
  /// In vi, this message translates to:
  /// **'Vay tiền'**
  String get scamTypeLoan;

  /// No description provided for @scamTypeOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get scamTypeOther;

  /// No description provided for @tabAudio.
  ///
  /// In vi, this message translates to:
  /// **'Giọng nói'**
  String get tabAudio;

  /// No description provided for @recordStart.
  ///
  /// In vi, this message translates to:
  /// **'Bấm micro và nói (hoặc mở tin nhắn thoại gần điện thoại)'**
  String get recordStart;

  /// No description provided for @recordStop.
  ///
  /// In vi, this message translates to:
  /// **'Dừng'**
  String get recordStop;

  /// No description provided for @listening.
  ///
  /// In vi, this message translates to:
  /// **'Đang nghe...'**
  String get listening;

  /// No description provided for @audioPreparing.
  ///
  /// In vi, this message translates to:
  /// **'Đang chuẩn bị micro...'**
  String get audioPreparing;

  /// No description provided for @audioSecondsLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {seconds} giây'**
  String audioSecondsLeft(int seconds);

  /// No description provided for @transcriptHint.
  ///
  /// In vi, this message translates to:
  /// **'Lời nói sẽ hiện ở đây thành chữ. Bạn có thể sửa lại trước khi bấm Kiểm tra.'**
  String get transcriptHint;

  /// No description provided for @noSpeechDetected.
  ///
  /// In vi, this message translates to:
  /// **'Không nghe được lời nói nào. Hãy thử lại ở nơi yên tĩnh, nói rõ hơn, hoặc gõ nội dung vào ô.'**
  String get noSpeechDetected;

  /// No description provided for @audioTranscriptEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có nội dung. Hãy bấm micro và nói, hoặc gõ nội dung vào ô trước khi kiểm tra.'**
  String get audioTranscriptEmpty;

  /// No description provided for @audioPermissionDenied.
  ///
  /// In vi, this message translates to:
  /// **'An Toàn chưa được phép dùng micro nên không thể nghe. Để bật: mở Cài đặt của điện thoại, chọn Ứng dụng, An Toàn, Quyền, rồi cho phép Micro. Hoặc dùng thẻ Văn bản để gõ nội dung.'**
  String get audioPermissionDenied;

  /// No description provided for @audioLocaleUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Điện thoại này chưa hỗ trợ nhận dạng giọng nói tiếng Việt. Vui lòng dùng thẻ Văn bản để gõ nội dung.'**
  String get audioLocaleUnavailable;

  /// No description provided for @audioNotSupported.
  ///
  /// In vi, this message translates to:
  /// **'Điện thoại này không hỗ trợ nhận dạng giọng nói. Vui lòng dùng thẻ Văn bản để gõ hoặc dán nội dung.'**
  String get audioNotSupported;

  /// No description provided for @audioNotSupportedShort.
  ///
  /// In vi, this message translates to:
  /// **'Không dùng được giọng nói trên máy này'**
  String get audioNotSupportedShort;

  /// No description provided for @audioFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không nhận dạng được giọng nói lúc này. Hãy thử lại, hoặc dùng thẻ Văn bản.'**
  String get audioFailed;

  /// No description provided for @phoneAlreadyReported.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã báo cáo số này trong 24 giờ qua. Cảm ơn bạn, mỗi người chỉ cần báo cáo một lần.'**
  String get phoneAlreadyReported;

  /// No description provided for @phoneDisputeAction.
  ///
  /// In vi, this message translates to:
  /// **'Thấy sai? Báo lỗi'**
  String get phoneDisputeAction;

  /// No description provided for @phoneDisputeConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo này có vẻ sai?'**
  String get phoneDisputeConfirmTitle;

  /// No description provided for @phoneDisputeConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Nếu bạn nghĩ các báo cáo về số này không đúng (ví dụ đây là số của bạn hoặc người quen), hãy báo lỗi. Khi đủ người báo lỗi, báo cáo sẽ không còn được tính và sẽ được xem xét lại. Mỗi số bạn chỉ báo lỗi được một lần.'**
  String get phoneDisputeConfirmBody;

  /// No description provided for @phoneDisputeCancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get phoneDisputeCancel;

  /// No description provided for @phoneDisputeConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Báo lỗi'**
  String get phoneDisputeConfirm;

  /// No description provided for @phoneDisputeSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghi nhận. Cảm ơn bạn đã giúp giữ thông tin chính xác.'**
  String get phoneDisputeSuccess;

  /// No description provided for @phoneAlreadyDisputed.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã báo lỗi cho số này rồi.'**
  String get phoneAlreadyDisputed;

  /// No description provided for @phoneNothingToDispute.
  ///
  /// In vi, this message translates to:
  /// **'Số này hiện không còn báo cáo nào để báo lỗi.'**
  String get phoneNothingToDispute;

  /// No description provided for @phoneDisputeRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã báo lỗi quá nhiều lần hôm nay. Vui lòng thử lại vào ngày mai.'**
  String get phoneDisputeRateLimited;

  /// No description provided for @trainingDifficultyEasy.
  ///
  /// In vi, this message translates to:
  /// **'Dễ'**
  String get trainingDifficultyEasy;

  /// No description provided for @trainingDifficultyMedium.
  ///
  /// In vi, this message translates to:
  /// **'Vừa'**
  String get trainingDifficultyMedium;

  /// No description provided for @trainingDifficultyHard.
  ///
  /// In vi, this message translates to:
  /// **'Khó'**
  String get trainingDifficultyHard;

  /// No description provided for @trainingSummaryNoFlags.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn này an toàn: không có dấu hiệu đáng ngờ nào để tìm'**
  String get trainingSummaryNoFlags;

  /// No description provided for @trainingResultIntroSafe.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả: tin nhắn này không có dấu hiệu đáng ngờ nào. Phần màu cam (nếu có) là phần bình thường mà bạn đánh dấu nhầm.'**
  String get trainingResultIntroSafe;

  /// No description provided for @addImages.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh ({count}/{max})'**
  String addImages(int count, int max);

  /// No description provided for @removeImage.
  ///
  /// In vi, this message translates to:
  /// **'Xóa ảnh {number}'**
  String removeImage(int number);

  /// No description provided for @imagesLimitReached.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 3 ảnh cho mỗi lần kiểm tra'**
  String get imagesLimitReached;

  /// No description provided for @imagesOrderHint.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh được gửi theo thứ tự 1, 2, 3 như một cuộc trò chuyện.'**
  String get imagesOrderHint;

  /// No description provided for @imageUnsupported.
  ///
  /// In vi, this message translates to:
  /// **'Không đọc được ảnh này. Hãy chọn ảnh chụp màn hình dạng JPG hoặc PNG.'**
  String get imageUnsupported;

  /// No description provided for @errorTooManyImages.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi lần chỉ kiểm tra được tối đa 3 ảnh. Hãy bỏ bớt ảnh rồi thử lại.'**
  String get errorTooManyImages;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
