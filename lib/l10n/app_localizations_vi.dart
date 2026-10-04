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
}
