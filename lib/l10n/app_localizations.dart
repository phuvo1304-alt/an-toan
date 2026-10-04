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
