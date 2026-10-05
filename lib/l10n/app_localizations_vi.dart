// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'An Toàn';

  @override
  String get homeTitle => 'An Toàn';

  @override
  String get homeSubtitle =>
      'Kiểm tra trước khi tin. Học cách nhận ra lừa đảo.';

  @override
  String get cardCheckMessage => 'Kiểm tra tin nhắn';

  @override
  String get cardCheckMessageDesc => 'Dán tin nhắn hoặc chọn ảnh chụp màn hình';

  @override
  String get cardCheckPhone => 'Kiểm tra số điện thoại';

  @override
  String get cardCheckPhoneDesc => 'Xem cộng đồng có báo cáo số này không';

  @override
  String get cardTraining => 'Luyện tập';

  @override
  String get cardTrainingDesc => 'Tình huống mô phỏng để nhận ra bẫy';

  @override
  String get cardQuiz => 'Đố vui';

  @override
  String get cardQuizDesc => 'Câu hỏi: đây có phải lừa đảo không?';

  @override
  String get comingSoon => 'Sắp ra mắt';

  @override
  String get settings => 'Cài đặt';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get languageVi => 'Tiếng Việt';

  @override
  String get languageEn => 'English';

  @override
  String get disclaimerTitle => 'Lưu ý quan trọng';

  @override
  String get disclaimerBody =>
      'Kết quả do AI tạo ra chỉ mang tính tham khảo, không phải tư vấn pháp lý hay chuyên môn, và có thể sai. An Toàn không bao giờ khẳng định một tin nhắn là an toàn tuyệt đối. Nếu còn nghi ngờ, hãy hỏi người lớn đáng tin cậy hoặc liên hệ cơ quan chức năng.';

  @override
  String get privacyNote =>
      'Nội dung bạn gửi đi để kiểm tra sẽ được chuyển đến dịch vụ AI để phân tích. Đừng gửi mật khẩu, mã OTP hay thông tin ngân hàng.';

  @override
  String get checkerTitle => 'Kiểm tra tin nhắn';

  @override
  String get tabText => 'Văn bản';

  @override
  String get tabScreenshot => 'Ảnh';

  @override
  String get pasteHint =>
      'Dán tin nhắn, SMS, email hoặc nội dung chat cần kiểm tra vào đây...';

  @override
  String get pickImage => 'Chọn ảnh chụp màn hình';

  @override
  String get changeImage => 'Chọn ảnh khác';

  @override
  String get noImageSelected => 'Chưa chọn ảnh';

  @override
  String get checkButton => 'Kiểm tra';

  @override
  String get checking => 'Đang phân tích...';

  @override
  String get resultTitle => 'Kết quả';

  @override
  String get riskSafe => 'Có vẻ an toàn';

  @override
  String get riskSuspicious => 'Đáng nghi';

  @override
  String get riskLikelyScam => 'Có khả năng là lừa đảo';

  @override
  String get scoreLabel => 'Điểm rủi ro';

  @override
  String get redFlags => 'Dấu hiệu cảnh báo';

  @override
  String get noRedFlags => 'Không thấy dấu hiệu rõ ràng.';

  @override
  String get whatToDo => 'Bạn nên làm gì';

  @override
  String get notVerified => 'Chưa thể xác minh';

  @override
  String get checkAnother => 'Kiểm tra tin khác';

  @override
  String get errorEmpty => 'Hãy nhập nội dung hoặc chọn một ảnh trước.';

  @override
  String get errorTooLong =>
      'Nội dung quá dài. Hãy rút gọn lại (tối đa 4000 ký tự).';

  @override
  String get errorImageTooLarge => 'Ảnh quá lớn. Hãy chọn ảnh nhỏ hơn.';

  @override
  String get errorRateLimited =>
      'Bạn đã kiểm tra quá nhiều lần. Vui lòng thử lại sau.';

  @override
  String get errorNetwork =>
      'Không có kết nối mạng. Hãy kiểm tra internet rồi thử lại.';

  @override
  String get errorGeneric => 'Có lỗi xảy ra. Vui lòng thử lại sau.';

  @override
  String get errorNotConfigured =>
      'Ứng dụng chưa được cấu hình máy chủ (thiếu SUPABASE_URL).';

  @override
  String get retry => 'Thử lại';

  @override
  String get officialHelpTitle => 'Cần giúp đỡ?';

  @override
  String get officialHelpBody =>
      'Nếu bạn đã bị lừa, hãy báo ngay cho gia đình, ngân hàng của bạn và cơ quan công an địa phương. Hãy kiểm tra số liên hệ chính thức mới nhất trên cổng thông tin của cơ quan chức năng.';

  @override
  String get quizTitle => 'Đố vui';

  @override
  String get quizIntro =>
      'Đọc từng tin nhắn và đoán xem đó có phải lừa đảo không. Sau mỗi câu, bạn sẽ thấy lời giải thích.';

  @override
  String get quizStart => 'Bắt đầu';

  @override
  String quizQuestionProgress(int current, int total) {
    return 'Câu $current/$total';
  }

  @override
  String get quizPrompt => 'Tin nhắn này có phải lừa đảo không?';

  @override
  String get quizAnswerScam => 'Lừa đảo';

  @override
  String get quizAnswerNotScam => 'Không phải lừa đảo';

  @override
  String get quizCorrect => 'Chính xác!';

  @override
  String get quizWrong => 'Chưa đúng';

  @override
  String get quizItWasScam => 'Đây là tin nhắn lừa đảo.';

  @override
  String get quizItWasNotScam => 'Đây là tin nhắn bình thường.';

  @override
  String get quizNext => 'Câu tiếp theo';

  @override
  String get quizSeeResults => 'Xem kết quả';

  @override
  String quizScore(int correct, int total) {
    return 'Điểm: $correct/$total';
  }

  @override
  String quizStreak(int count) {
    return 'Chuỗi đúng: $count';
  }

  @override
  String get quizSummaryTitle => 'Hoàn thành!';

  @override
  String quizRoundBestStreak(int count) {
    return 'Chuỗi đúng dài nhất lượt này: $count';
  }

  @override
  String quizBest(int correct, int total) {
    return 'Kỷ lục: $correct/$total';
  }

  @override
  String quizBestStreak(int count) {
    return 'Chuỗi đúng kỷ lục: $count';
  }

  @override
  String get quizNoBestYet => 'Chưa có kỷ lục. Hãy chơi lượt đầu tiên!';

  @override
  String get quizNewRecord => 'Kỷ lục mới!';

  @override
  String get quizPlayAgain => 'Chơi lại';

  @override
  String get quizBackHome => 'Về trang chủ';

  @override
  String get phoneTitle => 'Kiểm tra số điện thoại';

  @override
  String get phoneCommunityNote =>
      'Thông tin ở đây do người dùng báo cáo, không phải kết quả xác minh. Một số chưa có báo cáo không có nghĩa là an toàn.';

  @override
  String get phoneNumberLabel => 'Số điện thoại';

  @override
  String get phoneNumberHint => 'Ví dụ: 0901 234 567';

  @override
  String get phoneCheck => 'Kiểm tra';

  @override
  String get phoneInvalid =>
      'Số không hợp lệ. Hãy nhập số di động Việt Nam, ví dụ 0901 234 567 hoặc +84 901 234 567.';

  @override
  String get phoneNoReports => 'Chưa có báo cáo nào';

  @override
  String get phoneNoReportsNote =>
      'Chưa ai báo cáo số này. Điều đó không đảm bảo số này an toàn, hãy luôn cẩn thận.';

  @override
  String phoneReportedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Được $count người dùng báo cáo',
    );
    return '$_temp0';
  }

  @override
  String phoneCategoryCount(String category, int count) {
    return '$category: $count';
  }

  @override
  String phoneLastReported(String date) {
    return 'Báo cáo gần nhất: $date';
  }

  @override
  String get phoneReportsNote =>
      'Đây là báo cáo của người dùng, có thể sai. Báo cáo không chứng minh ai là chủ của số này.';

  @override
  String get phoneReportTitle => 'Báo cáo số này';

  @override
  String get phoneReportIntro =>
      'Nếu số trên đã gọi hoặc nhắn tin lừa đảo bạn, hãy báo cáo để cảnh báo người khác. Không ghi tên, địa chỉ hay thông tin cá nhân.';

  @override
  String get phoneCategoryLabel => 'Loại lừa đảo';

  @override
  String get phoneCategoryRequired => 'Hãy chọn loại lừa đảo.';

  @override
  String get phoneDescriptionLabel => 'Mô tả ngắn (không bắt buộc)';

  @override
  String get phoneDescriptionTooLong => 'Mô tả quá dài (tối đa 300 ký tự).';

  @override
  String get phoneSubmit => 'Gửi báo cáo';

  @override
  String get phoneReportSuccess =>
      'Đã gửi báo cáo. Cảm ơn bạn đã giúp cảnh báo mọi người!';

  @override
  String get phoneReportRateLimited =>
      'Bạn đã gửi quá nhiều báo cáo. Vui lòng thử lại sau một giờ.';

  @override
  String get phoneCatImpersonation => 'Giả danh công an, cơ quan nhà nước';

  @override
  String get phoneCatFakeBank => 'Giả danh ngân hàng, ví điện tử';

  @override
  String get phoneCatFakeJob => 'Việc làm giả, việc nhẹ lương cao';

  @override
  String get phoneCatInvestment => 'Đầu tư, tiền ảo';

  @override
  String get phoneCatLoan => 'Vay tiền';

  @override
  String get phoneCatShopping => 'Mua bán, giao hàng';

  @override
  String get phoneCatSpam => 'Quảng cáo, làm phiền';

  @override
  String get phoneCatOther => 'Khác';

  @override
  String get onboardingWelcomeBody =>
      'Dán tin nhắn hoặc chọn ảnh chụp màn hình, An Toàn sẽ cho bạn biết nó có giống lừa đảo không, vì sao, và nên làm gì tiếp theo.';

  @override
  String get onboardingLanguageTitle => 'Chọn ngôn ngữ';

  @override
  String get onboardingLanguageBody =>
      'Bạn có thể đổi lại bất cứ lúc nào trong phần Cài đặt.';

  @override
  String get onboardingPrivacyTitle => 'Quyền riêng tư của bạn';

  @override
  String get onboardingPrivacyBody =>
      'Nội dung bạn gửi để kiểm tra sẽ được chuyển đến một dịch vụ AI để phân tích. Kết quả do AI tạo ra và có thể sai. Ứng dụng không cần đăng nhập và không thu thập thông tin cá nhân. Đừng gửi mật khẩu, mã OTP hay thông tin ngân hàng.';

  @override
  String get onboardingSkip => 'Bỏ qua';

  @override
  String get onboardingNext => 'Tiếp';

  @override
  String get onboardingGetStarted => 'Bắt đầu sử dụng';

  @override
  String get privacyPolicy => 'Chính sách quyền riêng tư';

  @override
  String privacyPolicyOpenError(String url) {
    return 'Không mở được trang. Bạn có thể tự mở: $url';
  }

  @override
  String get trainingTitle => 'Luyện tập';

  @override
  String get trainingIntro =>
      'Mỗi tình huống là một tin nhắn mô phỏng. Hãy tìm những phần đáng ngờ, rồi xem bạn đã phát hiện được bao nhiêu.';

  @override
  String get trainingInstructions =>
      'Chạm vào những phần bạn thấy đáng ngờ (chạm lần nữa để bỏ chọn), rồi bấm Nộp bài.';

  @override
  String get trainingResultIntro =>
      'Kết quả: phần màu xanh là bạn phát hiện đúng, màu đỏ là bạn bỏ sót, màu cam là phần bình thường mà bạn đánh dấu nhầm.';

  @override
  String get trainingSubmit => 'Nộp bài';

  @override
  String get trainingCaughtLabel => 'Bạn đã phát hiện';

  @override
  String get trainingMissedLabel => 'Bạn đã bỏ sót';

  @override
  String get trainingFalsePositiveLabel => 'Phần này bình thường';

  @override
  String trainingSummaryCaught(int caught, int total) {
    return 'Bạn phát hiện $caught/$total dấu hiệu đáng ngờ';
  }

  @override
  String trainingSummaryFalsePositives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đánh dấu nhầm $count phần bình thường',
      zero: 'Không đánh dấu nhầm phần nào',
    );
    return '$_temp0';
  }

  @override
  String get trainingTryAgain => 'Thử lại';

  @override
  String get trainingBackToList => 'Về danh sách tình huống';

  @override
  String get scamTypeFakeJob => 'Việc làm giả';

  @override
  String get scamTypeFakeScholarship => 'Học bổng giả';

  @override
  String get scamTypePhishing => 'Giả mạo đường link';

  @override
  String get scamTypeImpersonation => 'Giả danh';

  @override
  String get scamTypeInvestment => 'Đầu tư';

  @override
  String get scamTypeRomance => 'Lừa đảo tình cảm';

  @override
  String get scamTypeLoan => 'Vay tiền';

  @override
  String get scamTypeOther => 'Khác';
}
