/// One piece of a training message. Segments are shown one after another as
/// tappable pieces, so each text already includes the space or punctuation
/// that joins it to the next one.
///
/// EVERY segment has an explanation: for a suspicious one, why it is a red
/// flag; for a normal one, why it is fine (shown when the user flagged it by
/// mistake).
class ScenarioSegment {
  final String id;
  final String textVi;
  final String textEn;
  final bool isSuspicious;
  final String explanationVi;
  final String explanationEn;

  const ScenarioSegment({
    required this.id,
    required this.textVi,
    required this.textEn,
    required this.isSuspicious,
    required this.explanationVi,
    required this.explanationEn,
  });

  String text(String languageCode) => languageCode == 'en' ? textEn : textVi;

  String explanation(String languageCode) =>
      languageCode == 'en' ? explanationEn : explanationVi;
}

/// A whole training message, split into segments.
class TrainingScenario {
  final String id;
  final String titleVi;
  final String titleEn;

  /// Same values as SCAM_TYPES in supabase/functions/analyze-scam/index.ts.
  final String scamType;
  final List<ScenarioSegment> segments;

  const TrainingScenario({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    required this.scamType,
    required this.segments,
  });

  String title(String languageCode) => languageCode == 'en' ? titleEn : titleVi;

  Iterable<ScenarioSegment> get suspiciousSegments =>
      segments.where((s) => s.isSuspicious);
}

/// The bundled scenarios. Written from scratch (not reused from the quiz), based
/// on the patterns in research/scam_patterns_vn.md.
///
/// Safety notes, same as quiz_data.dart:
/// - Links are "defanged" ([.] instead of .) so they can never be opened.
/// - Phone numbers are partly hidden (xxx) so none belongs to a real person.
const trainingScenarios = <TrainingScenario>[
  // Inspired by research/scam_patterns_vn.md, "fake_job": CTV recruitment,
  // a small first payout to build trust, then deposits to "buy orders" with a
  // promised refund + commission, and moving the chat to Telegram.
  TrainingScenario(
    id: 'ctv_order_boosting',
    titleVi: 'Lời mời làm cộng tác viên chốt đơn',
    titleEn: 'An invitation to boost shop orders',
    scamType: 'fake_job',
    segments: [
      ScenarioSegment(
        id: 'job_intro',
        textVi: 'Chào bạn, mình là Ngọc, bên tuyển dụng của một shop thời trang online. ',
        textEn: 'Hi, I\'m Ngoc from the hiring team of an online fashion shop. ',
        isSuspicious: false,
        explanationVi:
            'Một lời chào và giới thiệu bình thường. Tự nó chưa nói lên điều gì, hãy xem người này yêu cầu gì ở các câu sau.',
        explanationEn:
            'A normal greeting and introduction. On its own it tells you nothing, so look at what the person asks for next.',
      ),
      ScenarioSegment(
        id: 'job_ctv',
        textVi: 'Bên mình đang tuyển thêm cộng tác viên làm việc qua điện thoại. ',
        textEn: 'We are hiring more collaborators who work from their phones. ',
        isSuspicious: false,
        explanationVi:
            'Tuyển cộng tác viên làm online không phải là dấu hiệu lừa đảo, nhiều nơi tuyển thật như vậy. Điều quan trọng là công việc đòi bạn làm gì.',
        explanationEn:
            'Hiring online collaborators is not a red flag by itself; real businesses do it too. What matters is what the job asks you to do.',
      ),
      ScenarioSegment(
        id: 'job_pay',
        textVi: 'Thu nhập 400.000–700.000đ mỗi ngày, ',
        textEn: 'You earn 400,000–700,000 VND a day, ',
        isSuspicious: true,
        explanationVi:
            'Mức lương rất cao cho việc làm trên điện thoại vài phút là mồi nhử điển hình của bẫy "việc nhẹ lương cao".',
        explanationEn:
            'Very high pay for a few minutes of phone work is the classic bait of "easy work, high pay" scams.',
      ),
      ScenarioSegment(
        id: 'job_first_task',
        textVi: 'nhiệm vụ đầu tiên nhận ngay 50.000đ để làm quen. ',
        textEn: 'and the first task pays 50,000 VND right away so you can get started. ',
        isSuspicious: true,
        explanationVi:
            'Kẻ lừa đảo thường trả trước một khoản nhỏ để bạn tin, rồi mới đòi bạn nạp số tiền lớn hơn.',
        explanationEn:
            'Scammers often pay a small amount first to win your trust, before asking you to put in much more.',
      ),
      ScenarioSegment(
        id: 'job_deposit',
        textVi:
            'Từ nhiệm vụ thứ hai, bạn tự thanh toán trước tiền đơn hàng, hệ thống sẽ hoàn lại cả gốc và 20% hoa hồng. ',
        textEn:
            'From the second task on, you pay for the orders first, and the system refunds your money plus a 20% commission. ',
        isSuspicious: true,
        explanationVi:
            'Công việc thật trả lương cho bạn, không bắt bạn bỏ tiền ra trước. Đây là bước họ lấy tiền của bạn và không bao giờ trả lại.',
        explanationEn:
            'A real job pays you; it never makes you pay first. This is the step where they take your money and never return it.',
      ),
      ScenarioSegment(
        id: 'job_evening',
        textVi: 'Bạn có thể làm vào buổi tối sau giờ học. ',
        textEn: 'You can do it in the evening after school. ',
        isSuspicious: false,
        explanationVi:
            'Giờ làm linh hoạt là điều nhiều công việc thật cũng có. Câu này không yêu cầu bạn điều gì.',
        explanationEn:
            'Flexible hours are something many real jobs offer too. This sentence does not ask anything of you.',
      ),
      ScenarioSegment(
        id: 'job_telegram',
        textVi: 'Để nhận việc, bạn thêm Telegram của trưởng nhóm: @shop_hotro_xx. ',
        textEn: 'To get tasks, add the team leader on Telegram: @shop_hotro_xx. ',
        isSuspicious: true,
        explanationVi:
            'Kéo bạn sang Telegram hoặc nhóm kín là để tránh bị kiểm tra và khó truy vết. Các sàn và cửa hàng lớn không tuyển người làm nhiệm vụ kiểu này.',
        explanationEn:
            'Moving you to Telegram or a private group makes the scam harder to check and trace. Big shops and platforms do not hire people for tasks like this.',
      ),
      ScenarioSegment(
        id: 'job_closing',
        textVi: 'Có thắc mắc gì cứ nhắn mình nhé!',
        textEn: 'Message me if you have any questions!',
        isSuspicious: false,
        explanationVi: 'Một câu kết lịch sự, không có yêu cầu hay áp lực gì.',
        explanationEn: 'A polite closing line, with no request and no pressure.',
      ),
    ],
  ),

  // Inspired by research/scam_patterns_vn.md, "fake_scholarship": fake notices
  // about "trao đổi sinh viên" / study programs, being "selected" without a
  // real application, a place-holding deposit, a short deadline, and a form on
  // a non-official website.
  TrainingScenario(
    id: 'exchange_dorm_deposit',
    titleVi: 'Email chương trình trao đổi học sinh',
    titleEn: 'A student exchange program email',
    scamType: 'fake_scholarship',
    segments: [
      ScenarioSegment(
        id: 'sch_greeting',
        textVi: 'Kính gửi bạn học sinh, ',
        textEn: 'Dear student, ',
        isSuspicious: false,
        explanationVi: 'Một lời chào bình thường trong email. Ở đây chưa có yêu cầu gì.',
        explanationEn: 'A normal email greeting. Nothing is being asked here yet.',
      ),
      ScenarioSegment(
        id: 'sch_announce',
        textVi:
            'Văn phòng Hợp tác Quốc tế thông báo chương trình trao đổi học sinh mùa hè 2027 tại Hàn Quốc. ',
        textEn:
            'The International Cooperation Office announces a summer 2027 student exchange program in Korea. ',
        isSuspicious: false,
        explanationVi:
            'Trường thật cũng thông báo các chương trình trao đổi, nên câu này chưa phải dấu hiệu lừa đảo. Dù vậy, hãy kiểm tra trên trang web chính thức của trường.',
        explanationEn:
            'Real schools announce exchange programs too, so this is not a red flag by itself. Still, check it on the school\'s official website.',
      ),
      ScenarioSegment(
        id: 'sch_selected',
        textVi: 'Bạn đã được chọn mà không cần phỏng vấn. ',
        textEn: 'You have been selected without an interview. ',
        isSuspicious: true,
        explanationVi:
            'Được "chọn" khi bạn chưa từng nộp hồ sơ hay phỏng vấn là cách khiến bạn mừng mà quên kiểm tra.',
        explanationEn:
            'Being "selected" when you never applied or had an interview is meant to make you too excited to check.',
      ),
      ScenarioSegment(
        id: 'sch_details',
        textVi: 'Chương trình kéo dài 3 tuần, gồm lớp tiếng Hàn và các buổi tham quan. ',
        textEn: 'The program lasts 3 weeks, with Korean classes and sightseeing trips. ',
        isSuspicious: false,
        explanationVi:
            'Thời gian và hoạt động của chương trình chỉ là thông tin, không đòi bạn làm gì hay trả gì.',
        explanationEn:
            'The program length and activities are just information; they do not ask you to do or pay anything.',
      ),
      ScenarioSegment(
        id: 'sch_deposit',
        textVi:
            'Để giữ chỗ, vui lòng chuyển 2.500.000đ tiền cọc ký túc xá vào tài khoản cá nhân của cô điều phối viên ',
        textEn:
            'To keep your place, please transfer a 2,500,000 VND dorm deposit to the coordinator\'s personal bank account ',
        isSuspicious: true,
        explanationVi:
            'Trường thật không thu tiền qua tài khoản cá nhân, và không bắt đóng "tiền giữ chỗ" trước khi bạn kịp kiểm tra.',
        explanationEn:
            'Real schools never collect money through a personal account, or demand a "keep your place" deposit before you can check.',
      ),
      ScenarioSegment(
        id: 'sch_deadline',
        textVi: 'trước 17h hôm nay. ',
        textEn: 'by 5 PM today. ',
        isSuspicious: true,
        explanationVi:
            'Hạn chót gấp là để bạn không kịp hỏi bố mẹ hay thầy cô.',
        explanationEn:
            'A rushed deadline is there so you have no time to ask a parent or teacher.',
      ),
      ScenarioSegment(
        id: 'sch_link',
        textVi: 'Điền thông tin tại hocbong-traodoi[.]online để nhận thư mời. ',
        textEn: 'Fill in your details at hocbong-traodoi[.]online to get your invitation letter. ',
        isSuspicious: true,
        explanationVi:
            'Đây không phải tên miền của trường. Trang giả thường dùng đuôi rẻ như .online, .top để lấy thông tin của bạn.',
        explanationEn:
            'This is not the school\'s own domain. Fake pages often use cheap endings like .online or .top to collect your details.',
      ),
      ScenarioSegment(
        id: 'sch_closing',
        textVi: 'Chúc bạn một mùa hè thật ý nghĩa!',
        textEn: 'We wish you a wonderful summer!',
        isSuspicious: false,
        explanationVi: 'Một lời chúc thân thiện ở cuối email, không có yêu cầu gì.',
        explanationEn: 'A friendly closing wish, with no request in it.',
      ),
    ],
  ),

  // Inspired by research/scam_patterns_vn.md, "impersonation": a "cán bộ"
  // claiming the victim is "liên quan" to a money-laundering case, demanding a
  // transfer to a "tài khoản tạm giữ" to "chứng minh trong sạch", and insisting
  // on secrecy (the isolation used in "bắt cóc online").
  TrainingScenario(
    id: 'police_holding_account',
    titleVi: 'Tin nhắn từ "cán bộ điều tra"',
    titleEn: 'A message from an "investigator"',
    scamType: 'impersonation',
    segments: [
      ScenarioSegment(
        id: 'pol_opening',
        textVi: 'Chào em, anh gọi không được nên nhắn qua Zalo. ',
        textEn: 'Hi, I could not reach you by phone, so I am messaging you on Zalo. ',
        isSuspicious: false,
        explanationVi:
            'Nhắn tin khi gọi không được là chuyện bình thường. Câu này chưa có yêu cầu gì.',
        explanationEn:
            'Messaging after a missed call is normal. This sentence does not ask for anything yet.',
      ),
      ScenarioSegment(
        id: 'pol_claim',
        textVi: 'Anh là cán bộ điều tra Công an tỉnh. ',
        textEn: 'I am an investigator with the provincial police. ',
        isSuspicious: true,
        explanationVi:
            'Công an làm việc bằng giấy mời hoặc qua công an địa phương, không làm việc qua Zalo hay tin nhắn với người lạ.',
        explanationEn:
            'Police contact you with an official letter or through your local police station, never through Zalo or chat messages.',
      ),
      ScenarioSegment(
        id: 'pol_accuse',
        textVi: 'Số căn cước của em đang liên quan đến một đường dây rửa tiền. ',
        textEn: 'Your ID card number is linked to a money-laundering ring. ',
        isSuspicious: true,
        explanationVi:
            'Buộc tội bất ngờ là để bạn sợ hãi và làm theo mà không kịp suy nghĩ.',
        explanationEn:
            'A sudden accusation is meant to scare you into obeying before you can think.',
      ),
      ScenarioSegment(
        id: 'pol_case_no',
        textVi: 'Hồ sơ vụ việc số 127/HS-xx. ',
        textEn: 'Case file number 127/HS-xx. ',
        isSuspicious: false,
        explanationVi:
            'Một mã hồ sơ nghe có vẻ chính thức nhưng không chứng minh gì cả. Bản thân nó không phải yêu cầu, điều cần chú ý là họ đòi bạn làm gì.',
        explanationEn:
            'A case number sounds official but proves nothing. It is not a request by itself; what matters is what they ask you to do.',
      ),
      ScenarioSegment(
        id: 'pol_transfer',
        textVi:
            'Em phải chuyển hết tiền trong tài khoản sang tài khoản tạm giữ của cơ quan điều tra để chứng minh trong sạch, ',
        textEn:
            'You must move all the money in your account to the investigators\' holding account to prove you are innocent, ',
        isSuspicious: true,
        explanationVi:
            'Không có "tài khoản tạm giữ" nào như vậy. Cơ quan chức năng không bao giờ yêu cầu chuyển tiền qua điện thoại hay tin nhắn.',
        explanationEn:
            'There is no such "holding account". Authorities never ask you to transfer money over the phone or by message.',
      ),
      ScenarioSegment(
        id: 'pol_secret',
        textVi: 'và không được kể với bố mẹ hay thầy cô vì đây là bí mật điều tra. ',
        textEn: 'and you must not tell your parents or teachers, because this is a secret investigation. ',
        isSuspicious: true,
        explanationVi:
            'Bắt giữ bí mật là để cô lập bạn khỏi người có thể giúp. Đây là cách "bắt cóc online" nhắm vào học sinh. Hãy kể ngay cho người lớn.',
        explanationEn:
            'Demanding secrecy cuts you off from people who could help. This is how "online kidnapping" scams target students. Tell an adult right away.',
      ),
      ScenarioSegment(
        id: 'pol_reply',
        textVi: 'Em đọc kỹ rồi trả lời anh nhé.',
        textEn: 'Read this carefully and reply to me.',
        isSuspicious: false,
        explanationVi:
            'Một lời nhắc trả lời bình thường, câu này không có yêu cầu nguy hiểm.',
        explanationEn:
            'An ordinary request to reply; this sentence has no dangerous demand in it.',
      ),
    ],
  ),

  // Inspired by research/scam_patterns_vn.md, "other" (fake shipper): quoting
  // the real price of a recent order, saying the parcel was left "ở chỗ cũ",
  // and pushing an immediate bank transfer before you have seen the parcel.
  TrainingScenario(
    id: 'shipper_usual_spot',
    titleVi: 'Shipper báo đã giao hàng',
    titleEn: 'A courier says your parcel is delivered',
    scamType: 'other',
    segments: [
      ScenarioSegment(
        id: 'ship_intro',
        textVi: 'Chào chị, em là shipper giao đơn hàng chị đặt hôm qua ạ. ',
        textEn: 'Hi, I\'m the courier delivering the order you placed yesterday. ',
        isSuspicious: false,
        explanationVi:
            'Shipper nhắn tin báo giao hàng là chuyện bình thường. Câu này chỉ là lời giới thiệu, không đòi gì.',
        explanationEn:
            'Couriers often message about deliveries. This is just an introduction and asks for nothing.',
      ),
      ScenarioSegment(
        id: 'ship_price',
        textVi: 'Đơn gồm 1 áo khoác, tổng 345.000đ. ',
        textEn: 'The order is 1 jacket, 345,000 VND in total. ',
        isSuspicious: false,
        explanationVi:
            'Giá khớp với đơn của bạn nghe rất thuyết phục, nhưng thông tin đơn hàng có thể bị lộ. Tự nó không phải dấu hiệu lừa đảo, nhưng hãy kiểm tra lại trong ứng dụng mua hàng.',
        explanationEn:
            'A price that matches your order sounds convincing, but order details can leak. It is not a red flag on its own, but check it in your shopping app.',
      ),
      ScenarioSegment(
        id: 'ship_usual_spot',
        textVi: 'Em để hàng ở chỗ cũ trước cửa rồi nhé, ',
        textEn: 'I left it at the usual spot by your door, ',
        isSuspicious: true,
        explanationVi:
            '"Chỗ cũ" là câu quen thuộc của shipper giả: họ không giao gì cả, chỉ muốn bạn tin là hàng đã đến.',
        explanationEn:
            '"The usual spot" is a favourite line of fake couriers: they deliver nothing and just want you to believe the parcel arrived.',
      ),
      ScenarioSegment(
        id: 'ship_transfer',
        textVi: 'chị chuyển khoản giúp em vào số 09xx xxx 284 ',
        textEn: 'please transfer the money to 09xx xxx 284 ',
        isSuspicious: true,
        explanationVi:
            'Đừng chuyển tiền khi chưa tận mắt nhận hàng. Thanh toán đơn hàng nên làm trong ứng dụng mua sắm, không chuyển cho số lạ.',
        explanationEn:
            'Never pay before you have the parcel in your hands. Pay inside the shopping app, not to an unknown number.',
      ),
      ScenarioSegment(
        id: 'ship_rush',
        textVi: 'ngay bây giờ, ',
        textEn: 'right now, ',
        isSuspicious: true,
        explanationVi: 'Thúc giục "ngay bây giờ" là để bạn không kịp ra cửa kiểm tra.',
        explanationEn: 'Rushing you "right now" is so you do not have time to go and check the door.',
      ),
      ScenarioSegment(
        id: 'ship_busy',
        textVi: 'em còn chạy mấy đơn nữa ạ. ',
        textEn: 'I still have a few more deliveries to do. ',
        isSuspicious: false,
        explanationVi:
            'Shipper thật cũng bận nhiều đơn, nên câu này tự nó không phải dấu hiệu lừa đảo.',
        explanationEn:
            'Real couriers are busy with many deliveries too, so this alone is not a red flag.',
      ),
      ScenarioSegment(
        id: 'ship_thanks',
        textVi: 'Cảm ơn chị!',
        textEn: 'Thank you!',
        isSuspicious: false,
        explanationVi: 'Một lời cảm ơn lịch sự, không có yêu cầu gì.',
        explanationEn: 'A polite thank-you with no request in it.',
      ),
    ],
  ),
];
