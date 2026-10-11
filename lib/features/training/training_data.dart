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

/// How hard a scenario is. Checked by test/training_test.dart, so the label
/// always matches the content:
/// - easy:   2-4 red flags that are fairly visible once you look.
/// - medium: 2-3 red flags, each plausible alone; the combination is the tell.
/// - hard:   0 or 1 red flag in an otherwise normal message (trains "it is
///           probably fine, but watch this one detail" and not over-flagging).
enum TrainingDifficulty { easy, medium, hard }

/// A whole training message, split into segments.
class TrainingScenario {
  final String id;
  final String titleVi;
  final String titleEn;

  /// Same values as SCAM_TYPES in supabase/functions/analyze-scam/index.ts.
  /// For a fully safe scenario: the kind of scam the message could be
  /// mistaken for (that is the trap it trains against).
  final String scamType;
  final TrainingDifficulty difficulty;
  final List<ScenarioSegment> segments;

  const TrainingScenario({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    required this.scamType,
    required this.difficulty,
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
    difficulty: TrainingDifficulty.easy,
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
    difficulty: TrainingDifficulty.easy,
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
    difficulty: TrainingDifficulty.easy,
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
    difficulty: TrainingDifficulty.easy,
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

  // =========================================================================
  // MEDIUM: 2-3 red flags, each plausible on its own. The combination is the tell.
  // =========================================================================

  // Inspired by research/scam_patterns_vn.md, "phishing": a refund or gift that
  // must be "confirmed" on a look-alike site, an OTP request, and a deadline.
  // Channel: SMS.
  TrainingScenario(
    id: 'wallet_refund_link',
    titleVi: 'Tin nhắn hoàn tiền từ ví điện tử',
    titleEn: 'An e-wallet refund text',
    scamType: 'phishing',
    difficulty: TrainingDifficulty.medium,
    segments: [
      ScenarioSegment(
        id: 'refund_notice',
        textVi: '[MoMo] Quý khách có khoản hoàn tiền 1.280.000đ từ một đơn hàng đã hủy. ',
        textEn: '[MoMo] You have a 1,280,000 VND refund from a cancelled order. ',
        isSuspicious: false,
        explanationVi:
            'Hoàn tiền cho đơn bị hủy là chuyện có thật. Câu này chỉ báo tin, chưa đòi bạn làm gì.',
        explanationEn:
            'Refunds for cancelled orders really happen. This sentence only informs you and asks for nothing yet.',
      ),
      ScenarioSegment(
        id: 'refund_link',
        textVi: 'Để nhận tiền, vui lòng đăng nhập tại momo-hoantien[.]site ',
        textEn: 'To receive it, please sign in at momo-hoantien[.]site ',
        isSuspicious: true,
        explanationVi:
            'Tiền hoàn thật tự về ví, không cần đăng nhập qua link. Tên miền này không phải trang chính thức của ví.',
        explanationEn:
            'A real refund lands in your wallet by itself, with no link to sign in. This domain is not the wallet\'s official site.',
      ),
      ScenarioSegment(
        id: 'refund_otp',
        textVi: 'và nhập mã OTP vừa gửi về điện thoại ',
        textEn: 'and enter the OTP just sent to your phone ',
        isSuspicious: true,
        explanationVi:
            'Nhận tiền không bao giờ cần mã OTP. Ai có mã này có thể rút tiền khỏi ví của bạn.',
        explanationEn:
            'Receiving money never needs an OTP. Whoever has that code can take money out of your wallet.',
      ),
      ScenarioSegment(
        id: 'refund_deadline',
        textVi: 'trong vòng 2 giờ, sau đó khoản hoàn tiền sẽ bị hủy. ',
        textEn: 'within 2 hours, after which the refund will be cancelled. ',
        isSuspicious: true,
        explanationVi: 'Hạn chót gấp là để bạn làm theo trước khi kịp kiểm tra trong ứng dụng.',
        explanationEn: 'The short deadline is there so you act before checking inside the app.',
      ),
      ScenarioSegment(
        id: 'refund_code',
        textVi: 'Mã giao dịch: HT-xx4471. ',
        textEn: 'Transaction code: HT-xx4471. ',
        isSuspicious: false,
        explanationVi:
            'Một mã giao dịch trông chính thức nhưng không chứng minh gì. Tự nó không phải dấu hiệu lừa đảo.',
        explanationEn:
            'A transaction code looks official but proves nothing. On its own it is not a red flag.',
      ),
      ScenarioSegment(
        id: 'refund_thanks',
        textVi: 'Cảm ơn quý khách đã sử dụng dịch vụ.',
        textEn: 'Thank you for using our service.',
        isSuspicious: false,
        explanationVi: 'Một lời cảm ơn bình thường, không có yêu cầu gì.',
        explanationEn: 'A normal thank-you with no request in it.',
      ),
    ],
  ),

  // Inspired by research/scam_patterns_vn.md, "investment": an acquaintance
  // praising a group with a "teacher", unrealistic daily returns, screenshots
  // as proof, and a deposit into a platform reached by a link.
  // Channel: Zalo-style chat.
  TrainingScenario(
    id: 'friend_trading_group',
    titleVi: 'Chị quen rủ vào nhóm đầu tư',
    titleEn: 'An acquaintance invites you to an investing group',
    scamType: 'investment',
    difficulty: TrainingDifficulty.medium,
    segments: [
      ScenarioSegment(
        id: 'inv_hello',
        textVi: 'Em ơi, chị Thảo lớp tiếng Anh nè. ',
        textEn: 'Hi, it\'s Thao from your English class. ',
        isSuspicious: false,
        explanationVi:
            'Người quen nhắn hỏi thăm là bình thường. Nếu thấy lạ, hãy gọi điện hỏi lại chính người đó.',
        explanationEn:
            'A message from someone you know is normal. If it feels odd, call that person to check.',
      ),
      ScenarioSegment(
        id: 'inv_group',
        textVi: 'Dạo này chị theo một nhóm đầu tư, có thầy hướng dẫn mỗi tối. ',
        textEn: 'Lately I follow an investing group with a teacher every evening. ',
        isSuspicious: false,
        explanationVi:
            'Học đầu tư có người hướng dẫn tự nó không sai. Hãy xem nhóm này hứa gì và đòi gì ở các câu sau.',
        explanationEn:
            'Learning to invest with a guide is not wrong in itself. Look at what this group promises and asks for next.',
      ),
      ScenarioSegment(
        id: 'inv_return',
        textVi: 'Tháng rồi chị lãi đều 3% mỗi ngày, ',
        textEn: 'Last month I made a steady 3% a day, ',
        isSuspicious: true,
        explanationVi:
            '3% mỗi ngày là hơn gấp đôi số tiền chỉ sau một tháng. Không khoản đầu tư thật nào đều đặn như vậy.',
        explanationEn:
            '3% a day more than doubles your money in a month. No real investment is that steady.',
      ),
      ScenarioSegment(
        id: 'inv_screenshot',
        textVi: 'em xem ảnh chụp tài khoản chị gửi nè. ',
        textEn: 'look at the screenshot of my account I sent you. ',
        isSuspicious: true,
        explanationVi:
            'Ảnh chụp số dư rất dễ làm giả, và sàn giả cũng hiện số lãi ảo. Ảnh không chứng minh rút được tiền thật.',
        explanationEn:
            'Balance screenshots are easy to fake, and fake platforms show made-up profits. A picture does not prove anyone can withdraw.',
      ),
      ScenarioSegment(
        id: 'inv_deposit',
        textVi: 'Em nạp thử 1,8 triệu vào sàn qua link chị gửi, thấy được thì nạp thêm. ',
        textEn: 'Try depositing 1.8 million VND on the platform through my link, and add more if you like it. ',
        isSuspicious: true,
        explanationVi:
            'Nạp tiền vào một "sàn" chỉ vào được qua link riêng là cách các nhóm lừa đảo giữ tiền của bạn. Lúc đầu thường cho rút ít để bạn tin.',
        explanationEn:
            'Depositing on a "platform" you can only reach through a private link is how these groups hold your money. They often let you withdraw a little at first so you trust them.',
      ),
      ScenarioSegment(
        id: 'inv_session',
        textVi: 'Tối nay 8h nhóm có buổi chia sẻ, em vào nghe cho biết nha.',
        textEn: 'The group has a talk at 8 tonight, come and listen.',
        isSuspicious: false,
        explanationVi: 'Một lời mời nghe chia sẻ, chưa đòi tiền hay thông tin gì.',
        explanationEn: 'An invitation to a talk; it asks for no money or details.',
      ),
    ],
  ),

  // Inspired by research/scam_patterns_vn.md, "romance": an online partner
  // never met in person, a sudden money problem abroad, and a request for
  // secrecy. Channel: chat.
  TrainingScenario(
    id: 'online_partner_ticket',
    titleVi: 'Người yêu qua mạng cần tiền vé máy bay',
    titleEn: 'An online partner needs money for a ticket',
    scamType: 'romance',
    difficulty: TrainingDifficulty.medium,
    segments: [
      ScenarioSegment(
        id: 'rom_morning',
        textVi: 'Em ơi, hôm nay anh được nghỉ nên nhắn em sớm. ',
        textEn: 'Hey, I have the day off so I am messaging you early. ',
        isSuspicious: false,
        explanationVi: 'Một lời nhắn thân mật bình thường, không có yêu cầu gì.',
        explanationEn: 'An ordinary friendly message with no request.',
      ),
      ScenarioSegment(
        id: 'rom_months',
        textVi: 'Ba tháng nói chuyện với em là khoảng thời gian vui nhất của anh. ',
        textEn: 'These three months talking to you have been the happiest of my life. ',
        isSuspicious: false,
        explanationVi:
            'Lời tình cảm tự nó không phải dấu hiệu lừa đảo. Nhưng hãy nhớ: hai người chưa từng gặp mặt.',
        explanationEn:
            'Warm words alone are not a red flag. But remember: you two have never met in person.',
      ),
      ScenarioSegment(
        id: 'rom_ticket',
        textVi: 'Anh đã đặt vé về Việt Nam gặp em cuối tháng này, ',
        textEn: 'I booked a flight to Vietnam to meet you at the end of this month, ',
        isSuspicious: false,
        explanationVi: 'Kế hoạch gặp nhau nghe rất vui và tự nó không có gì sai.',
        explanationEn: 'A plan to meet sounds lovely and is not wrong in itself.',
      ),
      ScenarioSegment(
        id: 'rom_card_locked',
        textVi: 'nhưng thẻ ngân hàng của anh bị khóa khi ở nước ngoài, ',
        textEn: 'but my bank card got blocked while I am abroad, ',
        isSuspicious: true,
        explanationVi:
            'Một sự cố bất ngờ ngay trước khi gặp là lý do quen thuộc để xin tiền. Người lớn ở nước ngoài luôn có cách khác để trả tiền vé.',
        explanationEn:
            'A sudden problem right before meeting is a familiar excuse to ask for money. An adult abroad has other ways to pay for a ticket.',
      ),
      ScenarioSegment(
        id: 'rom_borrow',
        textVi: 'em cho anh mượn 6 triệu đóng nốt tiền vé, gặp nhau anh gửi lại ngay. ',
        textEn: 'can you lend me 6 million VND to finish paying, and I will pay you back when we meet. ',
        isSuspicious: true,
        explanationVi:
            'Người bạn chỉ quen qua mạng hỏi vay tiền là dấu hiệu rõ nhất của lừa đảo tình cảm. Lời hứa trả lại không làm nó an toàn hơn.',
        explanationEn:
            'Someone you only know online asking for money is the clearest sign of a romance scam. A promise to repay does not make it safer.',
      ),
      ScenarioSegment(
        id: 'rom_secret',
        textVi: 'Đừng kể với gia đình nha, anh muốn tạo bất ngờ cho mọi người.',
        textEn: 'Don\'t tell your family, I want it to be a surprise for everyone.',
        isSuspicious: true,
        explanationVi:
            'Bảo bạn giấu gia đình là để không ai kịp can ngăn. Đây là lúc nên kể ngay cho người lớn.',
        explanationEn:
            'Asking you to hide it from family stops anyone from warning you. This is exactly when to tell an adult.',
      ),
    ],
  ),

  // Inspired by research/scam_patterns_vn.md, "loan": an "approved" loan that
  // needs an insurance fee paid first, into a staff member's personal account.
  // Channel: chat with a "credit officer".
  TrainingScenario(
    id: 'loan_insurance_fee',
    titleVi: 'Hồ sơ vay đã được duyệt',
    titleEn: 'Your loan application is approved',
    scamType: 'loan',
    difficulty: TrainingDifficulty.medium,
    segments: [
      ScenarioSegment(
        id: 'loan_approved',
        textVi: 'Chào bạn, hồ sơ vay 15 triệu của bạn đã được duyệt sơ bộ. ',
        textEn: 'Hello, your application for a 15 million VND loan has been pre-approved. ',
        isSuspicious: false,
        explanationVi:
            'Nếu bạn thật sự đã nộp hồ sơ, một tin báo duyệt sơ bộ là bình thường. Hãy xem họ yêu cầu gì tiếp theo.',
        explanationEn:
            'If you really applied, a pre-approval message is normal. Look at what they ask for next.',
      ),
      ScenarioSegment(
        id: 'loan_rate',
        textVi: 'Lãi suất 1,2% một tháng, trả góp trong 12 tháng. ',
        textEn: 'The interest rate is 1.2% a month, repaid over 12 months. ',
        isSuspicious: false,
        explanationVi: 'Mức lãi và thời hạn này nghe hợp lý. Câu này chỉ là thông tin khoản vay.',
        explanationEn: 'This rate and term sound reasonable. The sentence is just loan information.',
      ),
      ScenarioSegment(
        id: 'loan_partner',
        textVi: 'Bên mình là đối tác của ngân hàng nên giải ngân rất nhanh. ',
        textEn: 'We partner with a bank, so the payout is very fast. ',
        isSuspicious: false,
        explanationVi:
            'Lời giới thiệu này không kiểm chứng được, nhưng tự nó chưa phải dấu hiệu lừa đảo. Bạn có thể tự hỏi lại ngân hàng.',
        explanationEn:
            'This claim cannot be checked, but on its own it is not a red flag. You can ask the bank yourself.',
      ),
      ScenarioSegment(
        id: 'loan_fee_first',
        textVi: 'Để giải ngân, bạn chuyển trước 1.150.000đ phí bảo hiểm khoản vay ',
        textEn: 'To release the money, first transfer a 1,150,000 VND loan insurance fee ',
        isSuspicious: true,
        explanationVi:
            'Bên cho vay thật không thu phí trước khi giải ngân; phí (nếu có) được trừ vào khoản vay. Đóng phí trước là bẫy phổ biến nhất của vay online giả.',
        explanationEn:
            'Real lenders do not charge before paying out; any fee is taken from the loan. Paying a fee first is the most common fake-loan trap.',
      ),
      ScenarioSegment(
        id: 'loan_personal_account',
        textVi: 'vào tài khoản cá nhân của nhân viên phụ trách hồ sơ. ',
        textEn: 'to the personal account of the officer handling your file. ',
        isSuspicious: true,
        explanationVi:
            'Công ty tài chính thật không bao giờ thu tiền qua tài khoản cá nhân của nhân viên.',
        explanationEn:
            'A real finance company never collects money through an employee\'s personal account.',
      ),
      ScenarioSegment(
        id: 'loan_help',
        textVi: 'Bạn cần hỗ trợ gì thêm cứ nhắn mình nhé.',
        textEn: 'Message me if you need anything else.',
        isSuspicious: false,
        explanationVi: 'Một câu kết lịch sự, không có yêu cầu gì.',
        explanationEn: 'A polite closing line with no request.',
      ),
    ],
  ),

  // Inspired by research/scam_patterns_vn.md, "impersonation" and "phishing":
  // a caller posing as bank staff who asks for card details and the code sent
  // to your phone. Channel: phone-call transcript.
  TrainingScenario(
    id: 'bank_call_card_renewal',
    titleVi: 'Cuộc gọi "gia hạn thẻ" từ ngân hàng',
    titleEn: 'A "card renewal" call from the bank',
    scamType: 'impersonation',
    difficulty: TrainingDifficulty.medium,
    segments: [
      ScenarioSegment(
        id: 'call_greeting',
        textVi: '(Cuộc gọi) Dạ em chào anh, em gọi từ bộ phận chăm sóc khách hàng của ngân hàng. ',
        textEn: '(Phone call) Hello, I am calling from the bank\'s customer care team. ',
        isSuspicious: false,
        explanationVi:
            'Ngân hàng đôi khi có gọi cho khách hàng thật. Lời chào tự nó không nói lên gì.',
        explanationEn:
            'Banks sometimes really call customers. The greeting alone tells you nothing.',
      ),
      ScenarioSegment(
        id: 'call_expiry',
        textVi: 'Thẻ của anh sắp hết hạn, em hỗ trợ gia hạn miễn phí qua điện thoại. ',
        textEn: 'Your card is about to expire, and I can renew it for free over the phone. ',
        isSuspicious: false,
        explanationVi:
            'Thẻ hết hạn là chuyện có thật, và lời đề nghị giúp đỡ chưa đòi gì. Nhưng hãy chú ý câu tiếp theo.',
        explanationEn:
            'Cards do expire, and an offer to help asks for nothing yet. But watch the next sentence.',
      ),
      ScenarioSegment(
        id: 'call_card_number',
        textVi: 'Anh đọc giúp em 16 số trên thẻ và ngày hết hạn để em kiểm tra. ',
        textEn: 'Please read me the 16 digits on the card and the expiry date so I can check. ',
        isSuspicious: true,
        explanationVi:
            'Ngân hàng đã có thông tin thẻ của bạn, họ không cần bạn đọc lại. Số thẻ và ngày hết hạn đủ để kẻ gian mua hàng online.',
        explanationEn:
            'The bank already has your card details and never needs you to read them out. The number and expiry date are enough to shop online with your card.',
      ),
      ScenarioSegment(
        id: 'call_code',
        textVi: 'Lát nữa có một mã 6 số gửi về máy anh, anh đọc lại cho em là xong. ',
        textEn: 'In a moment a 6-digit code will arrive on your phone; just read it back to me. ',
        isSuspicious: true,
        explanationVi:
            'Đó là mã OTP để xác nhận một giao dịch. Nhân viên ngân hàng thật không bao giờ hỏi mã này.',
        explanationEn:
            'That is an OTP to confirm a payment. Real bank staff never ask for it.',
      ),
      ScenarioSegment(
        id: 'call_recorded',
        textVi: 'Cuộc gọi được ghi âm để đảm bảo chất lượng dịch vụ. ',
        textEn: 'This call is recorded for quality purposes. ',
        isSuspicious: false,
        explanationVi:
            'Câu này nghe chuyên nghiệp nhưng không chứng minh gì. Tự nó không phải dấu hiệu lừa đảo.',
        explanationEn:
            'It sounds professional but proves nothing. On its own it is not a red flag.',
      ),
      ScenarioSegment(
        id: 'call_end',
        textVi: 'Anh còn cần em hỗ trợ gì thêm không ạ?',
        textEn: 'Is there anything else I can help you with?',
        isSuspicious: false,
        explanationVi: 'Một câu hỏi lịch sự cuối cuộc gọi, không đòi gì.',
        explanationEn: 'A polite question at the end of the call; it asks for nothing.',
      ),
    ],
  ),

  // =========================================================================
  // HARD: an otherwise normal message with exactly ONE well-hidden red flag.
  // =========================================================================

  // Inspired by research/scam_patterns_vn.md, "phishing": a believable notice
  // whose only problem is a look-alike login link. Channel: email.
  TrainingScenario(
    id: 'school_portal_maintenance',
    titleVi: 'Email bảo trì cổng đăng ký học phần',
    titleEn: 'A course-registration maintenance email',
    scamType: 'phishing',
    difficulty: TrainingDifficulty.hard,
    segments: [
      ScenarioSegment(
        id: 'portal_greeting',
        textVi: 'Kính gửi các em sinh viên, ',
        textEn: 'Dear students, ',
        isSuspicious: false,
        explanationVi: 'Một lời chào bình thường trong email của trường.',
        explanationEn: 'A normal greeting in a school email.',
      ),
      ScenarioSegment(
        id: 'portal_window',
        textVi: 'Phòng Đào tạo thông báo hệ thống đăng ký học phần sẽ bảo trì từ 22h thứ Bảy đến 6h Chủ nhật. ',
        textEn: 'The Academic Office announces that course registration will be down for maintenance from 10 PM Saturday to 6 AM Sunday. ',
        isSuspicious: false,
        explanationVi: 'Thông báo bảo trì có giờ cụ thể là chuyện trường làm thật. Câu này không đòi gì.',
        explanationEn: 'Maintenance notices with exact times are something schools really send. It asks for nothing.',
      ),
      ScenarioSegment(
        id: 'portal_effect',
        textVi: 'Trong thời gian này các em không đăng ký hoặc hủy học phần được. ',
        textEn: 'During this time you cannot add or drop courses. ',
        isSuspicious: false,
        explanationVi: 'Chỉ là thông tin hợp lý về ảnh hưởng của việc bảo trì.',
        explanationEn: 'Just sensible information about what the maintenance affects.',
      ),
      ScenarioSegment(
        id: 'portal_check',
        textVi: 'Sau khi bảo trì, các em đăng nhập lại để kiểm tra thời khóa biểu ',
        textEn: 'Afterwards, sign in again to check your timetable ',
        isSuspicious: false,
        explanationVi: 'Lời nhắc kiểm tra lại thời khóa biểu là bình thường. Vấn đề nằm ở nơi họ bảo bạn đăng nhập.',
        explanationEn: 'A reminder to check your timetable is normal. The problem is where they tell you to sign in.',
      ),
      ScenarioSegment(
        id: 'portal_link',
        textVi: 'tại daotao-sinhvien-portal[.]com bằng tài khoản và mật khẩu sinh viên. ',
        textEn: 'at daotao-sinhvien-portal[.]com with your student username and password. ',
        isSuspicious: true,
        explanationVi:
            'Đây là chi tiết duy nhất sai: cổng của trường nằm trên tên miền của trường, không phải một trang .com lạ. Trang giả này lấy mật khẩu của bạn. Hãy tự gõ địa chỉ trang trường bạn đã biết.',
        explanationEn:
            'This is the one wrong detail: the school portal lives on the school\'s own domain, not a random .com. The fake page steals your password. Type the school address you already know yourself.',
      ),
      ScenarioSegment(
        id: 'portal_contact',
        textVi: 'Mọi thắc mắc vui lòng liên hệ văn phòng khoa.',
        textEn: 'For questions, please contact your faculty office.',
        isSuspicious: false,
        explanationVi: 'Hướng dẫn liên hệ trực tiếp văn phòng khoa là dấu hiệu tốt, không có gì đáng ngờ.',
        explanationEn: 'Pointing you to the faculty office in person is a good sign, nothing suspicious.',
      ),
    ],
  ),

  // Inspired by research/scam_patterns_vn.md, "fake_job": a realistic local job
  // (normal pay, in-person interview) with one hidden ask: a fee before the
  // interview. Channel: chat.
  TrainingScenario(
    id: 'cafe_uniform_fee',
    titleVi: 'Tuyển phục vụ quán cà phê',
    titleEn: 'A café is hiring servers',
    scamType: 'fake_job',
    difficulty: TrainingDifficulty.hard,
    segments: [
      ScenarioSegment(
        id: 'cafe_hiring',
        textVi: 'Quán cà phê bên mình ở quận 3 đang tuyển thêm bạn phục vụ ca tối. ',
        textEn: 'Our café in District 3 is hiring more servers for the evening shift. ',
        isSuspicious: false,
        explanationVi: 'Quán tuyển phục vụ là việc làm thêm rất bình thường của sinh viên.',
        explanationEn: 'A café hiring servers is a very normal student part-time job.',
      ),
      ScenarioSegment(
        id: 'cafe_pay',
        textVi: 'Lương 25.000đ/giờ, được ăn tối tại quán, ',
        textEn: 'Pay is 25,000 VND an hour, with dinner at the café, ',
        isSuspicious: false,
        explanationVi: 'Mức lương này thực tế cho việc phục vụ, không hề "lương cao" bất thường.',
        explanationEn: 'This is realistic pay for serving, not unusually "high pay".',
      ),
      ScenarioSegment(
        id: 'cafe_hours',
        textVi: 'làm từ 18h đến 22h, ít nhất 3 buổi một tuần. ',
        textEn: 'working 6 to 10 PM, at least 3 evenings a week. ',
        isSuspicious: false,
        explanationVi: 'Giờ làm cụ thể và hợp lý, đúng như một công việc thật.',
        explanationEn: 'Clear, reasonable hours, just like a real job.',
      ),
      ScenarioSegment(
        id: 'cafe_interview',
        textVi: 'Bạn qua quán phỏng vấn trực tiếp vào chiều thứ Tư nhé. ',
        textEn: 'Come to the café for an in-person interview on Wednesday afternoon. ',
        isSuspicious: false,
        explanationVi: 'Phỏng vấn trực tiếp tại quán là dấu hiệu tốt của một công việc thật.',
        explanationEn: 'An in-person interview at the café is a good sign of a real job.',
      ),
      ScenarioSegment(
        id: 'cafe_fee',
        textVi: 'Trước buổi phỏng vấn, bạn chuyển khoản 250.000đ tiền đồng phục để bên mình giữ chỗ. ',
        textEn: 'Before the interview, transfer 250,000 VND for the uniform so we can hold your place. ',
        isSuspicious: true,
        explanationVi:
            'Chi tiết duy nhất sai, và rất dễ bỏ qua vì số tiền nhỏ: chỗ làm thật không thu tiền trước khi bạn được nhận. Đồng phục, nếu có, được phát khi bắt đầu làm.',
        explanationEn:
            'The one wrong detail, easy to miss because the amount is small: a real employer does not take money before hiring you. A uniform, if any, is handed out when you start.',
      ),
      ScenarioSegment(
        id: 'cafe_id',
        textVi: 'Nhớ mang theo căn cước khi đến nha.',
        textEn: 'Remember to bring your ID card when you come.',
        isSuspicious: false,
        explanationVi: 'Mang căn cước khi đi phỏng vấn trực tiếp là yêu cầu bình thường.',
        explanationEn: 'Bringing your ID to an in-person interview is a normal request.',
      ),
    ],
  ),

  // Inspired by research/scam_patterns_vn.md, "other" (online shopping): a
  // normal seller message whose one trick is moving payment outside the
  // shopping app with a discount. Channel: in-app chat with a shop.
  TrainingScenario(
    id: 'shop_direct_transfer',
    titleVi: 'Shop nhắn tin sau khi bạn đặt hàng',
    titleEn: 'A shop messages you after you order',
    scamType: 'other',
    difficulty: TrainingDifficulty.hard,
    segments: [
      ScenarioSegment(
        id: 'shop_received',
        textVi: 'Shop đã nhận đơn tai nghe của bạn, cảm ơn bạn đã ủng hộ. ',
        textEn: 'We have received your order for headphones, thank you for your support. ',
        isSuspicious: false,
        explanationVi: 'Shop xác nhận đơn hàng là chuyện bình thường.',
        explanationEn: 'A shop confirming your order is normal.',
      ),
      ScenarioSegment(
        id: 'shop_shipping',
        textVi: 'Đơn sẽ được gửi vào ngày mai và giao trong 2 đến 3 ngày. ',
        textEn: 'It ships tomorrow and arrives in 2 to 3 days. ',
        isSuspicious: false,
        explanationVi: 'Thông tin giao hàng cụ thể, hợp lý.',
        explanationEn: 'Clear, reasonable delivery information.',
      ),
      ScenarioSegment(
        id: 'shop_tracking',
        textVi: 'Bạn có thể theo dõi đơn ngay trong ứng dụng mua hàng. ',
        textEn: 'You can track the order right inside the shopping app. ',
        isSuspicious: false,
        explanationVi: 'Hướng bạn theo dõi trong ứng dụng là dấu hiệu tốt.',
        explanationEn: 'Pointing you to tracking inside the app is a good sign.',
      ),
      ScenarioSegment(
        id: 'shop_warranty',
        textVi: 'Sản phẩm được bảo hành 6 tháng. ',
        textEn: 'The product has a 6-month warranty. ',
        isSuspicious: false,
        explanationVi: 'Thông tin bảo hành bình thường, không đòi gì ở bạn.',
        explanationEn: 'Normal warranty information that asks nothing of you.',
      ),
      ScenarioSegment(
        id: 'shop_offplatform',
        textVi: 'Nếu muốn được giảm thêm 8%, bạn chuyển khoản thẳng cho shop qua tài khoản riêng thay vì thanh toán trong ứng dụng. ',
        textEn: 'For an extra 8% off, transfer the money directly to the shop\'s own account instead of paying in the app. ',
        isSuspicious: true,
        explanationVi:
            'Chi tiết duy nhất sai: kéo bạn thanh toán ra ngoài ứng dụng, nơi bạn mất quyền khiếu nại và hoàn tiền. Một khoản giảm giá nhỏ là mồi nhử.',
        explanationEn:
            'The one wrong detail: getting you to pay outside the app, where you lose buyer protection and refunds. A small discount is the bait.',
      ),
      ScenarioSegment(
        id: 'shop_questions',
        textVi: 'Có gì thắc mắc bạn cứ nhắn shop nhé!',
        textEn: 'Message us if you have any questions!',
        isSuspicious: false,
        explanationVi: 'Một câu kết thân thiện, không có yêu cầu gì.',
        explanationEn: 'A friendly closing line with no request.',
      ),
    ],
  ),

  // =========================================================================
  // HARD, fully safe: NO red flags. Trains against over-flagging. scamType is
  // the kind of scam the message could be mistaken for.
  // =========================================================================

  // Looks like the bank texts scammers copy, but it only reports a payment you
  // made, has no link and asks for nothing. Channel: SMS.
  TrainingScenario(
    id: 'safe_balance_alert',
    titleVi: 'Tin nhắn biến động số dư',
    titleEn: 'A balance-change text',
    scamType: 'phishing',
    difficulty: TrainingDifficulty.hard,
    segments: [
      ScenarioSegment(
        id: 'bal_context',
        textVi: '(Bạn vừa chuyển khoản đóng tiền CLB bóng rổ và nhận được:) ',
        textEn: '(You just paid your basketball club fee by bank transfer, then receive:) ',
        isSuspicious: false,
        explanationVi: 'Bối cảnh: chính bạn vừa chuyển tiền, nên tin báo này là điều bạn đang chờ.',
        explanationEn: 'Context: you just made this transfer yourself, so this is the message you expect.',
      ),
      ScenarioSegment(
        id: 'bal_amount',
        textVi: 'TCB: Tài khoản ...88 -450.000VND lúc 14:32 ngày 06/10. ',
        textEn: 'TCB: Account ...88 -450,000 VND at 14:32 on 06/10. ',
        isSuspicious: false,
        explanationVi: 'Số tiền và giờ khớp với giao dịch bạn vừa làm. Tin báo biến động số dư thật trông đúng như vậy.',
        explanationEn: 'The amount and time match the payment you just made. Real balance alerts look exactly like this.',
      ),
      ScenarioSegment(
        id: 'bal_note',
        textVi: 'Nội dung: Dong tien CLB bong ro. ',
        textEn: 'Note: Basketball club fee. ',
        isSuspicious: false,
        explanationVi: 'Nội dung chuyển khoản do chính bạn ghi. Không dấu là bình thường trong tin nhắn ngân hàng.',
        explanationEn: 'The transfer note is what you typed yourself. Missing accents are normal in bank texts.',
      ),
      ScenarioSegment(
        id: 'bal_balance',
        textVi: 'Số dư: 2.318.000VND. ',
        textEn: 'Balance: 2,318,000 VND. ',
        isSuspicious: false,
        explanationVi: 'Chỉ báo số dư, không đòi bạn làm gì.',
        explanationEn: 'It only shows your balance and asks nothing.',
      ),
      ScenarioSegment(
        id: 'bal_hotline',
        textVi: 'Nếu không phải bạn thực hiện, hãy gọi số tổng đài in trên thẻ. ',
        textEn: 'If you did not make this payment, call the hotline printed on your card. ',
        isSuspicious: false,
        explanationVi:
            'Đây là lời khuyên đúng: gọi số in trên thẻ, không phải số lạ trong tin nhắn. Không có link nào cả.',
        explanationEn:
            'This is good advice: call the number on your card, not a number in the message. There is no link at all.',
      ),
      ScenarioSegment(
        id: 'bal_otp_warning',
        textVi: 'Không cung cấp mã OTP cho bất kỳ ai.',
        textEn: 'Never share your OTP with anyone.',
        isSuspicious: false,
        explanationVi: 'Lời nhắc giữ bí mật OTP là dấu hiệu của tin ngân hàng thật, không phải lừa đảo.',
        explanationEn: 'A reminder to keep your OTP secret is a sign of a real bank text, not a scam.',
      ),
    ],
  ),

  // Looks like the scholarship scams in this file, but it is free, uses
  // official channels and gives time to check. Channel: school email.
  TrainingScenario(
    id: 'safe_school_scholarship',
    titleVi: 'Thông báo học bổng của trường',
    titleEn: 'A scholarship notice from your school',
    scamType: 'fake_scholarship',
    difficulty: TrainingDifficulty.hard,
    segments: [
      ScenarioSegment(
        id: 'ss_greeting',
        textVi: 'Kính gửi các em học sinh lớp 12, ',
        textEn: 'Dear Grade 12 students, ',
        isSuspicious: false,
        explanationVi: 'Lời chào gửi đúng đối tượng học sinh của trường.',
        explanationEn: 'A greeting addressed to the school\'s own students.',
      ),
      ScenarioSegment(
        id: 'ss_fund',
        textVi: 'Quỹ khuyến học của trường mở đợt xét học bổng cho học sinh có hoàn cảnh khó khăn. ',
        textEn: 'The school\'s scholarship fund is accepting applications from students facing financial hardship. ',
        isSuspicious: false,
        explanationVi: 'Trường có quỹ khuyến học là chuyện thật và phổ biến.',
        explanationEn: 'Schools really do have scholarship funds; this is common.',
      ),
      ScenarioSegment(
        id: 'ss_apply',
        textVi: 'Các em nộp hồ sơ trực tiếp tại phòng Công tác học sinh hoặc qua cổng thông tin của trường. ',
        textEn: 'Apply in person at the Student Affairs Office or through the school portal. ',
        isSuspicious: false,
        explanationVi: 'Nộp hồ sơ qua kênh chính thức của trường, có cả cách nộp trực tiếp. Không có link lạ.',
        explanationEn: 'You apply through the school\'s official channels, including in person. No strange links.',
      ),
      ScenarioSegment(
        id: 'ss_deadline',
        textVi: 'Hạn nộp là ngày 31/10, ',
        textEn: 'The deadline is 31 October, ',
        isSuspicious: false,
        explanationVi: 'Hạn nộp còn vài tuần, đủ thời gian để bạn hỏi lại thầy cô. Không phải kiểu "trong 24 giờ".',
        explanationEn: 'The deadline is weeks away, plenty of time to ask a teacher. Not a "within 24 hours" rush.',
      ),
      ScenarioSegment(
        id: 'ss_results',
        textVi: 'kết quả được công bố trên bảng tin và trang web của trường. ',
        textEn: 'and results are posted on the notice board and the school website. ',
        isSuspicious: false,
        explanationVi: 'Kết quả công khai, ai cũng kiểm tra được. Đây là dấu hiệu của thông báo thật.',
        explanationEn: 'Results are public, so anyone can check them. A sign of a real notice.',
      ),
      ScenarioSegment(
        id: 'ss_free',
        textVi: 'Học bổng hoàn toàn miễn phí, trường không thu bất kỳ khoản phí nào.',
        textEn: 'Applying is completely free; the school charges no fee of any kind.',
        isSuspicious: false,
        explanationVi: 'Không thu phí là điểm khác biệt lớn nhất so với học bổng lừa đảo.',
        explanationEn: 'Charging nothing is the biggest difference from a scholarship scam.',
      ),
    ],
  ),

  // =========================================================================
  // NEW ARCHETYPES: 8 synthetic composites, written from scratch in the same
  // spirit as the scenarios above (not real individual cases -- see the file
  // header's safety notes, same standard as quiz_data.dart, so no per-entry
  // sourcing citation is needed here unlike data/scam_case_reference.json).
  // =========================================================================

  // Recognition-only, deliberately. This is the pattern behind real
  // labor-trafficking cases reported in Vietnam, so this scenario sticks to
  // the RECOGNIZABLE lure (vague company, no license, in-person pressure,
  // deposit/ID before any contract) and firm preventive advice. It does NOT
  // describe what happens to victims after they go -- no abuse, violence or
  // confinement detail -- that is not needed to recognize the lure, and this
  // app's users include minors.
  TrainingScenario(
    id: 'overseas_job_labor_lure',
    titleVi: 'Lời mời làm việc ở nước ngoài, hẹn gặp gấp',
    titleEn: 'An overseas job offer with an urgent in-person meeting',
    scamType: 'fake_job',
    difficulty: TrainingDifficulty.easy,
    segments: [
      ScenarioSegment(
        id: 'ovj_intro',
        textVi: 'Chào em, anh thấy em đăng tin tìm việc làm thêm nên nhắn hỏi thử. ',
        textEn: 'Hi, I saw your post looking for part-time work, so I am reaching out. ',
        isSuspicious: false,
        explanationVi:
            'Một lời mở đầu bình thường. Tự nó chưa nói lên điều gì, hãy xem công việc là gì ở các câu sau.',
        explanationEn:
            'An ordinary opening line. On its own it tells you nothing -- look at what the job actually is next.',
      ),
      ScenarioSegment(
        id: 'ovj_offer',
        textVi:
            'Bên anh chuyên đưa lao động phổ thông đi làm việc ở nước ngoài, đợt này cần người gấp cho một xưởng ở Thái Lan. ',
        textEn:
            'We specialize in sending general workers abroad, and right now we urgently need people for a factory in Thailand. ',
        isSuspicious: false,
        explanationVi:
            'Xuất khẩu lao động là ngành có thật. Câu này chưa phải dấu hiệu lừa đảo, nhưng hãy chú ý công ty có nói rõ giấy phép và tên công ty không.',
        explanationEn:
            'Labor export is a real industry. This is not a red flag by itself, but watch whether the company names itself and its license clearly.',
      ),
      ScenarioSegment(
        id: 'ovj_pay',
        textVi: 'Lương 2 triệu một tuần, bao ăn ở, chỉ cần sức khỏe tốt, không cần bằng cấp. ',
        textEn: 'Pay is 2 million VND a week, with meals and housing included -- just need good health, no qualifications. ',
        isSuspicious: true,
        explanationVi:
            'Mức lương này cao bất thường so với công việc phổ thông ở nước ngoài. Lương càng cao càng phi lý là mồi nhử để bạn bỏ qua các dấu hiệu khác.',
        explanationEn:
            'This pay is unrealistically high for unskilled work abroad. An implausibly high wage is bait, designed to make you overlook everything else.',
      ),
      ScenarioSegment(
        id: 'ovj_vague',
        textVi:
            'Anh không tiện nói rõ tên công ty hay giấy phép qua tin nhắn đâu, cứ yên tâm, gặp trực tiếp anh nói cụ thể hơn. ',
        textEn:
            'I cannot share the company name or license over message, don\'t worry, I\'ll explain everything in person. ',
        isSuspicious: true,
        explanationVi:
            'Công ty xuất khẩu lao động thật phải có giấy phép của Bộ Lao động - Thương binh và Xã hội và không ngại nói tên mình. Từ chối nêu tên/giấy phép là dấu hiệu rõ nhất. Hãy tự tra cứu danh sách công ty được cấp phép chính thức -- không dùng số hay trang mà người tuyển dụng đưa cho bạn.',
        explanationEn:
            'A real labor-export company has an official government license and has no reason to hide its name. Refusing to name itself or show a license is the clearest sign. Check the official government list of licensed labor-export agencies yourself -- never a number or page the recruiter gives you.',
      ),
      ScenarioSegment(
        id: 'ovj_meet',
        textVi: 'Em tranh thủ chiều nay qua địa chỉ anh gửi để gặp trực tiếp, ký hợp đồng luôn cho nhanh. ',
        textEn: 'Come by the address I\'ll send you this afternoon so we can meet and sign the contract right away. ',
        isSuspicious: true,
        explanationVi:
            'Không bao giờ đi một mình để gặp mặt cho một lời mời việc làm, nhất là khi bị hẹn gấp trong cùng ngày. Hãy nói với bố mẹ hoặc người lớn tin cậy địa điểm, giờ giấc, và rủ người đi cùng trước khi quyết định bất cứ điều gì.',
        explanationEn:
            'Never go alone to meet someone in person for a job lead, especially on same-day pressure. Tell a parent or trusted adult the place and time, and bring someone with you, before deciding anything.',
      ),
      ScenarioSegment(
        id: 'ovj_deposit',
        textVi: 'Nhớ mang theo CCCD và hộ chiếu, đặt cọc trước một khoản để giữ suất xuất cảnh. ',
        textEn: 'Bring your ID card and passport, and pay a deposit up front to hold your spot to travel. ',
        isSuspicious: true,
        explanationVi:
            'Không công ty tuyển dụng thật nào giữ hộ chiếu/CCCD của bạn hay đòi tiền đặt cọc trước khi có hợp đồng lao động rõ ràng. Nếu bạn hoặc người quen gặp tình huống này, hãy báo ngay cho công an (số 113, xem trong mục Cài đặt của ứng dụng) và kể cho gia đình trước khi làm bất cứ bước tiếp theo nào.',
        explanationEn:
            'No real employer holds your passport/ID or demands a deposit before a clear labor contract exists. If you or someone you know is in this situation, report it to the police (113, in the app\'s Settings) and tell your family before taking any next step.',
      ),
      ScenarioSegment(
        id: 'ovj_group',
        textVi: 'Đợt này công ty đưa một nhóm nhỏ đi cùng chuyến cho vui. ',
        textEn: 'This round, the company is sending a small group together on the same trip. ',
        isSuspicious: false,
        explanationVi: 'Một chi tiết thêm, không tự nó là dấu hiệu lừa đảo.',
        explanationEn: 'An extra detail; not a red flag by itself.',
      ),
      ScenarioSegment(
        id: 'ovj_closing',
        textVi: 'Có gì em nhắn lại cho anh biết sớm nha.',
        textEn: 'Let me know soon if you\'re interested.',
        isSuspicious: false,
        explanationVi: 'Một câu kết bình thường, không có yêu cầu nguy hiểm.',
        explanationEn: 'An ordinary closing line, with no dangerous demand in it.',
      ),
    ],
  ),

  // Modeling/casting scam: filed as "other", not "fake_job" -- there is no
  // ongoing employment relationship or wage being offered, just a one-time
  // "pay to be discovered" grift, closer to the generic deception "other"
  // already covers (fake shipper, fake storefront) than to a job offer.
  TrainingScenario(
    id: 'fake_modeling_casting',
    titleVi: 'Lời mời làm người mẫu ảnh, cần đóng phí hồ sơ',
    titleEn: 'A modeling photoshoot offer requiring a portfolio fee',
    scamType: 'other',
    difficulty: TrainingDifficulty.medium,
    segments: [
      ScenarioSegment(
        id: 'mod_intro',
        textVi:
            'Chào bạn, mình là quản lý casting của một công ty truyền thông, thấy ảnh bạn trên mạng xã hội rất ưng. ',
        textEn: 'Hi, I\'m a casting manager at a media company, and I really liked your photos on social media. ',
        isSuspicious: false,
        explanationVi:
            'Một lời mở đầu tâng bốc thường thấy. Tự nó chưa nói lên điều gì, hãy xem họ đòi gì ở các câu sau.',
        explanationEn:
            'A flattering opener like this is common. On its own it tells you nothing -- look at what they ask for next.',
      ),
      ScenarioSegment(
        id: 'mod_opportunity',
        textVi: 'Bên mình đang tìm gương mặt mới cho một chiến dịch quảng cáo mùa này. ',
        textEn: 'We are looking for new faces for an ad campaign this season. ',
        isSuspicious: false,
        explanationVi: 'Casting tìm gương mặt mới là chuyện có thật trong ngành truyền thông.',
        explanationEn: 'Casting calls for new faces really happen in the media industry.',
      ),
      ScenarioSegment(
        id: 'mod_no_experience',
        textVi: 'Không cần kinh nghiệm, ai cũng có thể thử sức. ',
        textEn: 'No experience needed, anyone can give it a try. ',
        isSuspicious: false,
        explanationVi:
            'Nghe thân thiện và dễ tin, nhưng tự nó chưa phải dấu hiệu lừa đảo. Vấn đề thật nằm ở câu tiếp theo.',
        explanationEn:
            'This sounds friendly and easy to believe, but on its own it is not a red flag. The real problem is in the next line.',
      ),
      ScenarioSegment(
        id: 'mod_fee',
        textVi: 'Để vào vòng chụp thử, bạn đóng 650.000đ phí làm hồ sơ và trang điểm chuyên nghiệp. ',
        textEn: 'To get into the test shoot, you pay a 650,000 VND fee for your portfolio and professional makeup. ',
        isSuspicious: true,
        explanationVi:
            'Công ty người mẫu/casting thật không thu phí để "được phát hiện" hay để thử vai. Tiền chảy theo chiều ngược lại: họ trả bạn, không phải bạn trả họ.',
        explanationEn:
            'A real modeling/casting agency never charges you to "get discovered" or to try out. The money should flow the other way: they pay you, not the reverse.',
      ),
      ScenarioSegment(
        id: 'mod_income',
        textVi: 'Chỉ cần 2 buổi chụp mỗi tháng là có thể thu nhập chục triệu. ',
        textEn: 'Just 2 shoots a month and you could earn tens of millions of VND. ',
        isSuspicious: true,
        explanationVi:
            'Thu nhập cao bất thường cho vài buổi chụp là mồi nhử để bạn thấy khoản phí nhỏ phía trên là "đáng đầu tư".',
        explanationEn:
            'Unrealistically high income for a couple of shoots is bait to make the fee above feel like a worthwhile "investment".',
      ),
      ScenarioSegment(
        id: 'mod_urgency',
        textVi: 'Suất chụp thử tuần này sắp đầy, bạn đóng phí sớm để giữ chỗ nha. ',
        textEn: 'This week\'s test-shoot slots are almost full, pay soon to hold your spot. ',
        isSuspicious: true,
        explanationVi:
            'Tạo cảm giác "sắp hết chỗ" là để bạn đóng tiền ngay, trước khi kịp tìm hiểu hay hỏi người lớn.',
        explanationEn:
            'Creating a sense that slots are "almost gone" pushes you to pay right away, before you can look into it or ask an adult.',
      ),
      ScenarioSegment(
        id: 'mod_closing',
        textVi: 'Bạn nhắn lại mình sớm để sắp lịch nhé!',
        textEn: 'Message me back soon so we can schedule it!',
        isSuspicious: false,
        explanationVi: 'Một câu kết thúc giục trả lời, không có yêu cầu nguy hiểm riêng.',
        explanationEn: 'A closing line nudging a reply, with no separate dangerous demand.',
      ),
    ],
  ),

  // Hijacked-account impersonation: a "friend" (really someone who took over
  // their account) asks for an urgent transfer on their behalf.
  TrainingScenario(
    id: 'hacked_friend_transfer',
    titleVi: 'Tin nhắn Messenger của bạn thân nhờ chuyển khoản',
    titleEn: 'A message from your best friend\'s account asking for a transfer',
    scamType: 'impersonation',
    difficulty: TrainingDifficulty.easy,
    segments: [
      ScenarioSegment(
        id: 'hak_opener',
        textVi: 'Ê, đang rảnh không? Tao có chuyện cần nhờ gấp. ',
        textEn: 'Hey, are you free? I need to ask you something urgent. ',
        isSuspicious: false,
        explanationVi: 'Một lời mở đầu bình thường giữa bạn bè. Chưa có yêu cầu gì ở đây.',
        explanationEn: 'A normal opener between friends. There is no request here yet.',
      ),
      ScenarioSegment(
        id: 'hak_context',
        textVi: 'Tao đang ở ngoài tiệm, định chuyển khoản mua đồ mà app ngân hàng bị lỗi không vào được. ',
        textEn: 'I\'m at a shop trying to pay, but my banking app is glitching and won\'t open. ',
        isSuspicious: false,
        explanationVi:
            'App lỗi là chuyện có thể xảy ra thật. Câu này chỉ là bối cảnh, chưa đòi bạn làm gì.',
        explanationEn:
            'Apps really do glitch sometimes. This is just context and does not ask anything of you yet.',
      ),
      ScenarioSegment(
        id: 'hak_ask',
        textVi: 'Mày chuyển giúp tao 1.850.000đ vào số tài khoản này, xong tao gửi lại ngay khi app ổn. ',
        textEn: 'Can you transfer 1,850,000 VND to this account for me, I\'ll pay you back the moment the app works. ',
        isSuspicious: true,
        explanationVi:
            'Một người bạn bất ngờ nhờ chuyển tiền hộ là dấu hiệu kinh điển của tài khoản bị chiếm: kẻ gian đang dùng tài khoản của bạn bè bạn để lừa chính bạn.',
        explanationEn:
            'A friend suddenly asking you to transfer money on their behalf is the classic sign of a hijacked account: someone else is using your friend\'s account to scam you.',
      ),
      ScenarioSegment(
        id: 'hak_mismatch',
        textVi: 'Số tài khoản tên Nguyễn Văn Khoa, không phải tên tao đâu, tài khoản em họ tao đứng tên giúp á. ',
        textEn: 'The account is under the name Nguyen Van Khoa, not mine -- it\'s my cousin\'s account. ',
        isSuspicious: true,
        explanationVi:
            'Tên chủ tài khoản không khớp với người bạn quen là một điểm bất thường rõ ràng, được giải thích vội bằng một lý do mơ hồ ("nhờ em họ").',
        explanationEn:
            'The account holder\'s name not matching the friend you know is a clear inconsistency, waved away with a vague excuse ("my cousin\'s account").',
      ),
      ScenarioSegment(
        id: 'hak_pressure',
        textVi: 'Gấp lắm, tiệm sắp đóng cửa rồi. ',
        textEn: 'It\'s urgent, the shop is about to close. ',
        isSuspicious: true,
        explanationVi:
            'Thúc giục gấp gáp là để bạn chuyển tiền ngay, thay vì gọi điện (không phải nhắn tin) cho người bạn đó để kiểm tra trước.',
        explanationEn:
            'Rushing you is meant to make you transfer right away, instead of calling (not messaging) that friend to check first.',
      ),
      ScenarioSegment(
        id: 'hak_social',
        textVi: 'Lâu rồi hai đứa chưa đi cà phê nhỉ, khi nào rảnh đi nha. ',
        textEn: 'We haven\'t grabbed coffee in ages, let\'s go sometime. ',
        isSuspicious: false,
        explanationVi: 'Một câu chuyện phiếm bình thường, không có yêu cầu gì.',
        explanationEn: 'Ordinary small talk, with no request in it.',
      ),
      ScenarioSegment(
        id: 'hak_closing',
        textVi: 'Chuyển xong nhắn tao biết với.',
        textEn: 'Let me know once you\'ve sent it.',
        isSuspicious: false,
        explanationVi: 'Một câu kết thúc, không thêm yêu cầu mới.',
        explanationEn: 'A closing line, with no new request.',
      ),
    ],
  ),

  // Deepfake voice/video call impersonating a relative. Channel: video call
  // transcript, same format as bank_call_card_renewal.
  TrainingScenario(
    id: 'deepfake_relative_call',
    titleVi: 'Cuộc gọi video giọng giống hệt chú ruột',
    titleEn: 'A video call that sounds exactly like your uncle',
    scamType: 'impersonation',
    difficulty: TrainingDifficulty.medium,
    segments: [
      ScenarioSegment(
        id: 'dfk_greeting',
        textVi: '(Cuộc gọi video, hình hơi giật và mờ) Chú đây, chú gọi có việc gấp cần con giúp. ',
        textEn: '(Video call, the image is a bit choppy and blurry) It\'s your uncle, I need your help with something urgent. ',
        isSuspicious: false,
        explanationVi:
            'Người thân gọi video nhờ việc là chuyện bình thường. Hình ảnh chập chờn cũng có thể chỉ là mạng yếu thật.',
        explanationEn:
            'A relative video-calling for help is normal, and a choppy picture can genuinely just be a weak connection.',
      ),
      ScenarioSegment(
        id: 'dfk_excuse',
        textVi: 'Chú đang đi công tác ở xa, điện thoại chú sắp hết pin nên gọi nhanh thôi. ',
        textEn: 'I\'m away on a work trip and my phone is almost out of battery, so this has to be quick. ',
        isSuspicious: false,
        explanationVi:
            'Một lý do hợp lý để giải thích cuộc gọi ngắn và hình ảnh không rõ. Không phải dấu hiệu lừa đảo một mình, nhưng hãy để ý nó cũng là lý do tiện lợi để bạn không kịp hỏi kỹ.',
        explanationEn:
            'A plausible reason for a short call and unclear picture. Not a red flag alone, but notice it is also a convenient excuse that stops you asking too many questions.',
      ),
      ScenarioSegment(
        id: 'dfk_ask',
        textVi: 'Chú cần con chuyển gấp 4.000.000đ vào số tài khoản chú nhắn sau, có việc quan trọng chú kể sau. ',
        textEn: 'I need you to urgently transfer 4,000,000 VND to an account I\'ll message you, I\'ll explain later. ',
        isSuspicious: true,
        explanationVi:
            'Yêu cầu chuyển tiền gấp mà không nói rõ lý do ngay là dấu hiệu rất đáng ngờ, dù giọng hay hình có giống người thân đến đâu.',
        explanationEn:
            'An urgent money request with the real reason "explained later" is a serious warning sign, no matter how convincing the voice or face looks.',
      ),
      ScenarioSegment(
        id: 'dfk_no_callback',
        textVi: 'Đừng gọi lại số này nha, chú đang dùng máy mượn tạm thôi. ',
        textEn: 'Don\'t call this number back, I\'m just borrowing this phone for now. ',
        isSuspicious: true,
        explanationVi:
            'Chủ động ngăn bạn gọi lại qua kênh quen thuộc để xác minh là một trong những dấu hiệu rõ nhất của mạo danh. Hãy gọi lại đúng số điện thoại bạn đã lưu của người đó.',
        explanationEn:
            'Actively discouraging you from calling back through a known channel to verify is one of the clearest impersonation signs. Call the number you already have saved for that person instead.',
      ),
      ScenarioSegment(
        id: 'dfk_secret',
        textVi: 'Cũng đừng nói với bố mẹ con vội, để chú tự nói sau. ',
        textEn: 'Don\'t tell your parents yet either, I\'ll explain to them myself later. ',
        isSuspicious: true,
        explanationVi:
            'Bảo giữ bí mật với gia đình là để không ai kịp giúp bạn kiểm tra. Đây chính là lúc nên kể ngay cho người lớn.',
        explanationEn:
            'Asking you to keep it from family stops anyone from helping you check. This is exactly when to tell an adult right away.',
      ),
      ScenarioSegment(
        id: 'dfk_checkin',
        textVi: 'Con khỏe không, lâu rồi không gặp. ',
        textEn: 'How are you doing, it\'s been a while. ',
        isSuspicious: false,
        explanationVi: 'Một câu hỏi thăm bình thường, không có yêu cầu gì.',
        explanationEn: 'An ordinary check-in question, with no request in it.',
      ),
      ScenarioSegment(
        id: 'dfk_closing',
        textVi: 'Chuyển xong nhắn chú biết nhé, chú cúp máy đây.',
        textEn: 'Let me know once you\'ve sent it, I have to go now.',
        isSuspicious: false,
        explanationVi: 'Một câu kết thúc cuộc gọi, không thêm yêu cầu mới.',
        explanationEn: 'A closing line ending the call, with no new request.',
      ),
    ],
  ),

  // QR-code overpayment trick at a food stall: after scanning a swapped QR
  // code, the victim gets an SMS/app message pushing them toward a look-alike
  // "refund" link and an OTP.
  TrainingScenario(
    id: 'qr_code_overpayment',
    titleVi: 'Tin nhắn hoàn tiền sau khi quét mã QR ở quán ăn',
    titleEn: 'A refund text after scanning a QR code at a food stall',
    scamType: 'phishing',
    difficulty: TrainingDifficulty.medium,
    segments: [
      ScenarioSegment(
        id: 'qr_context',
        textVi: '(Bạn vừa quét mã QR để thanh toán tại một quán ăn vỉa hè và nhận được tin nhắn sau:) ',
        textEn: '(You just scanned a QR code to pay at a street food stall and receive the following message:) ',
        isSuspicious: false,
        explanationVi: 'Bối cảnh: bạn vừa thanh toán thật, nên một tin nhắn liên quan không có gì lạ.',
        explanationEn: 'Context: you just made a real payment, so a related message is not unusual by itself.',
      ),
      ScenarioSegment(
        id: 'qr_overpay',
        textVi: 'Hệ thống ghi nhận bạn đã thanh toán 220.000đ cho đơn hàng trị giá 85.000đ. ',
        textEn: 'Our system recorded a payment of 220,000 VND for an order worth 85,000 VND. ',
        isSuspicious: false,
        explanationVi:
            'Lỗi thanh toán dư tiền có thể xảy ra thật. Câu này chỉ là thông báo, chưa đòi bạn làm gì nguy hiểm.',
        explanationEn:
            'Overpayment errors can genuinely happen. This sentence only informs you and does not yet ask anything risky.',
      ),
      ScenarioSegment(
        id: 'qr_link',
        textVi: 'Để nhận lại phần chênh lệch, vui lòng xác nhận tại vi-hoantien-qr[.]shop ',
        textEn: 'To get the difference back, please confirm at vi-hoantien-qr[.]shop ',
        isSuspicious: true,
        explanationVi:
            'Nhận lại tiền thừa không cần "xác nhận" qua một trang lạ. Đây không phải trang của ví điện tử bạn đang dùng.',
        explanationEn:
            'Getting an overpayment back never needs you to "confirm" on some unfamiliar site. This is not your actual wallet\'s page.',
      ),
      ScenarioSegment(
        id: 'qr_otp',
        textVi: 'và nhập mã OTP vừa gửi về điện thoại để hệ thống đối chiếu giao dịch. ',
        textEn: 'and enter the OTP just sent to your phone so the system can verify the transaction. ',
        isSuspicious: true,
        explanationVi: 'Nhận lại tiền không bao giờ cần mã OTP. Ai có mã này có thể rút tiền khỏi ví của bạn.',
        explanationEn: 'Receiving money back never needs an OTP. Whoever has that code can take money out of your wallet.',
      ),
      ScenarioSegment(
        id: 'qr_deadline',
        textVi: 'trong vòng 10 phút, nếu không hệ thống sẽ hủy giao dịch hoàn tiền. ',
        textEn: 'within 10 minutes, or the system will cancel the refund. ',
        isSuspicious: true,
        explanationVi: 'Hạn chót rất ngắn là để bạn làm theo ngay, trước khi kịp nghi ngờ hay hỏi ai.',
        explanationEn: 'A very short deadline pushes you to act immediately, before you can grow suspicious or ask anyone.',
      ),
      ScenarioSegment(
        id: 'qr_thanks',
        textVi: 'Cảm ơn bạn đã sử dụng dịch vụ thanh toán QR.',
        textEn: 'Thank you for using our QR payment service.',
        isSuspicious: false,
        explanationVi: 'Một lời cảm ơn thường thấy, không có yêu cầu gì.',
        explanationEn: 'A common closing thank-you, with no request in it.',
      ),
    ],
  ),

  // Fake university exchange-program recruiter met in person at a school
  // event, following up by chat -- a different channel/mechanism than the
  // email-based exchange_dorm_deposit scenario above.
  TrainingScenario(
    id: 'fake_exchange_recruiter_event',
    titleVi: 'Người lạ ở hội chợ hướng nghiệp mời trao đổi học sinh',
    titleEn: 'A stranger at a career fair invites you to an exchange program',
    scamType: 'fake_scholarship',
    difficulty: TrainingDifficulty.medium,
    segments: [
      ScenarioSegment(
        id: 'exr_intro',
        textVi:
            'Chào em, hôm nay gặp ở hội chợ hướng nghiệp trường vui quá, anh là đại diện chương trình trao đổi học sinh quốc tế. ',
        textEn:
            'Hi, it was great meeting you at the school career fair today -- I represent an international student exchange program. ',
        isSuspicious: false,
        explanationVi:
            'Gặp người giới thiệu chương trình tại một sự kiện trường tổ chức nghe có vẻ đáng tin. Hãy xem chương trình và cách đăng ký cụ thể ra sao.',
        explanationEn:
            'Meeting someone at a school-organized event sounds credible. Look at the program details and how you actually apply.',
      ),
      ScenarioSegment(
        id: 'exr_program',
        textVi: 'Chương trình đưa học sinh giỏi đi trao đổi 1 học kỳ tại Mỹ, có học bổng một phần. ',
        textEn: 'The program sends top students on a one-semester exchange in the US, with a partial scholarship. ',
        isSuspicious: false,
        explanationVi: 'Chương trình trao đổi học sinh có thật và phổ biến. Câu này chỉ là thông tin.',
        explanationEn: 'Student exchange programs are real and common. This sentence is just information.',
      ),
      ScenarioSegment(
        id: 'exr_vague_org',
        textVi: 'Tổ chức của anh hợp tác với nhiều trường nhưng chưa có văn phòng đại diện chính thức ở Việt Nam. ',
        textEn: 'My organization works with many schools but doesn\'t have an official office in Vietnam yet. ',
        isSuspicious: true,
        explanationVi:
            'Một tổ chức giáo dục quốc tế thật thường có văn phòng, website và thông tin kiểm chứng được. "Chưa có văn phòng" là một tổ chức rất khó xác minh.',
        explanationEn:
            'A real international education organization usually has an office, a website and verifiable information. "No office yet" means an organization that is very hard to verify.',
      ),
      ScenarioSegment(
        id: 'exr_no_process',
        textVi: 'Nhìn hồ sơ học tập của em, anh nghĩ em đủ điều kiện nhận suất đặc biệt không cần phỏng vấn. ',
        textEn: 'Looking at your academic record, I think you qualify for a special spot, no interview needed. ',
        isSuspicious: true,
        explanationVi:
            'Được "chọn" chỉ sau một cuộc trò chuyện ngắn, bỏ qua phỏng vấn hay quy trình xét duyệt, là cách khiến bạn mừng mà quên kiểm tra kỹ.',
        explanationEn:
            'Being "selected" after one short conversation, skipping any interview or review process, is designed to make you too excited to check carefully.',
      ),
      ScenarioSegment(
        id: 'exr_fee',
        textVi: 'Em đóng 2.900.000đ phí xử lý hồ sơ nhanh cho anh qua tài khoản cá nhân để anh giữ suất cho em. ',
        textEn: 'Pay me a 2,900,000 VND express processing fee to my personal account, and I\'ll hold your spot. ',
        isSuspicious: true,
        explanationVi:
            'Trường và chương trình trao đổi thật không thu tiền qua tài khoản cá nhân của một người đại diện. Đây là dấu hiệu rõ nhất của lừa đảo.',
        explanationEn:
            'A real school or exchange program never collects money through a representative\'s personal account. This is the clearest sign of a scam.',
      ),
      ScenarioSegment(
        id: 'exr_social_proof',
        textVi: 'Chương trình này nhiều anh chị khóa trước cũng đã tham gia rồi. ',
        textEn: 'Many students from previous years have already joined this program. ',
        isSuspicious: false,
        explanationVi:
            'Một tuyên bố không kiểm chứng được, nhưng tự nó chưa phải dấu hiệu lừa đảo rõ ràng.',
        explanationEn: 'An unverifiable claim, but not a clear red flag by itself.',
      ),
      ScenarioSegment(
        id: 'exr_closing',
        textVi: 'Em suy nghĩ rồi nhắn lại anh nha, đừng để lỡ cơ hội.',
        textEn: 'Think it over and message me back, don\'t miss this opportunity.',
        isSuspicious: false,
        explanationVi: 'Một câu thúc giục thường thấy để kết thúc tin nhắn, không có yêu cầu riêng.',
        explanationEn: 'A common nudging closing line, with no separate request in it.',
      ),
    ],
  ),

  // Gambling/betting app scam: guaranteed-win claims and a "deposit more to
  // unlock bigger withdrawals" lock-in mechanic.
  TrainingScenario(
    id: 'gambling_betting_app',
    titleVi: 'App cá độ bóng đá hứa thắng chắc',
    titleEn: 'A football-betting app promising a sure win',
    scamType: 'investment',
    difficulty: TrainingDifficulty.easy,
    segments: [
      ScenarioSegment(
        id: 'gam_intro',
        textVi: 'Ê, có app soi kèo bóng đá xịn lắm, tao chơi tuần nào cũng có tiền. ',
        textEn: 'Hey, there\'s a really good football-prediction app, I win money every week playing it. ',
        isSuspicious: false,
        explanationVi:
            'Một lời giới thiệu từ bạn bè nghe đáng tin. Hãy xem app này hứa gì ở các câu sau.',
        explanationEn: 'A tip from a friend sounds trustworthy. Look at what this app actually promises next.',
      ),
      ScenarioSegment(
        id: 'gam_how',
        textVi: 'Tải app, nạp tiền vào ví trong app là chơi được liền. ',
        textEn: 'Download the app, deposit into the in-app wallet, and you can start playing right away. ',
        isSuspicious: false,
        explanationVi: 'Cách dùng app nghe đơn giản, tự nó chưa phải dấu hiệu lừa đảo.',
        explanationEn: 'The app sounds simple to use; this alone is not a red flag.',
      ),
      ScenarioSegment(
        id: 'gam_guaranteed',
        textVi: 'Chuyên gia trong app soi kèo chuẩn 95%, cá là thắng. ',
        textEn: 'The app\'s experts predict matches with 95% accuracy, a sure win. ',
        isSuspicious: true,
        explanationVi:
            'Không ai đoán kết quả bóng đá chính xác 95%. Lời hứa "thắng chắc" trong cá cược là phi thực tế và luôn là dấu hiệu lừa đảo.',
        explanationEn:
            'Nobody predicts football results with 95% accuracy. A "sure win" promise in betting is unrealistic and always a red flag.',
      ),
      ScenarioSegment(
        id: 'gam_deposit_more',
        textVi: 'Nạp càng nhiều, hệ số thắng càng cao, có gói VIP nhân đôi tiền thắng. ',
        textEn: 'The more you deposit, the higher your win rate, and there\'s a VIP package that doubles your winnings. ',
        isSuspicious: true,
        explanationVi:
            'Cá cược thật không hoạt động kiểu "nạp nhiều thắng nhiều". Đây là cách dụ bạn bỏ vào ngày càng nhiều tiền.',
        explanationEn:
            'Real betting does not work as "deposit more, win more". This is designed to lure you into putting in increasingly more money.',
      ),
      ScenarioSegment(
        id: 'gam_withdraw_fee',
        textVi: 'Lúc đầu rút thử vài trăm được liền, nhưng muốn rút khoản lớn phải nạp thêm phí kích hoạt ví VIP. ',
        textEn: 'Small withdrawals work fine at first, but to withdraw a large amount you must pay a fee to activate a VIP wallet. ',
        isSuspicious: true,
        explanationVi:
            'Cho rút một ít lúc đầu để tạo lòng tin, rồi đòi thêm phí mới cho rút khoản lớn, là chiêu giữ tiền của bạn phổ biến nhất.',
        explanationEn:
            'Allowing small withdrawals at first to build trust, then demanding a new fee before a big withdrawal, is the most common way these apps keep your money.',
      ),
      ScenarioSegment(
        id: 'gam_classmates',
        textVi: 'Nhiều đứa trong lớp cũng chơi, vui lắm. ',
        textEn: 'A bunch of our classmates play it too, it\'s fun. ',
        isSuspicious: false,
        explanationVi: 'Nhiều người chơi không có nghĩa là app an toàn hay có thật.',
        explanationEn: 'Many people playing does not mean the app is safe or legitimate.',
      ),
      ScenarioSegment(
        id: 'gam_closing',
        textVi: 'Tao gửi link app cho, tải về chơi thử đi.',
        textEn: 'I\'ll send you the app link, download it and give it a try.',
        isSuspicious: false,
        explanationVi: 'Một lời mời bình thường, câu này tự nó không có yêu cầu nguy hiểm.',
        explanationEn: 'An ordinary invitation; this sentence alone has no dangerous demand.',
      ),
    ],
  ),

  // Fake charity drive: mostly a genuine-sounding local appeal, trained
  // against over-flagging real donation requests. The ONE hidden flag is the
  // money going to a PERSONAL account instead of the organization's own.
  TrainingScenario(
    id: 'fake_charity_drive',
    titleVi: 'Lời kêu gọi quyên góp sau cơn bão',
    titleEn: 'A donation appeal after the storm',
    scamType: 'other',
    difficulty: TrainingDifficulty.hard,
    segments: [
      ScenarioSegment(
        id: 'cha_context',
        textVi: 'Hội Chữ thập đỏ phường đang kêu gọi ủng hộ cho các hộ dân bị ngập lụt tuần qua. ',
        textEn: 'The ward Red Cross chapter is calling for donations for households flooded last week. ',
        isSuspicious: false,
        explanationVi: 'Các đợt quyên góp sau thiên tai là chuyện có thật và thường xuyên.',
        explanationEn: 'Donation drives after a natural disaster are real and common.',
      ),
      ScenarioSegment(
        id: 'cha_confirmed',
        textVi: 'Danh sách 40 hộ cần hỗ trợ đã được xác nhận bởi UBND phường. ',
        textEn: 'The list of 40 households needing help has been confirmed by the ward People\'s Committee. ',
        isSuspicious: false,
        explanationVi: 'Một chi tiết cụ thể, kiểm chứng được, thường thấy ở lời kêu gọi thật.',
        explanationEn: 'A specific, checkable detail, typical of a genuine appeal.',
      ),
      ScenarioSegment(
        id: 'cha_purpose',
        textVi: 'Số tiền quyên góp sẽ dùng mua gạo, nước sạch và thuốc men khẩn cấp. ',
        textEn: 'The donations will be used to buy rice, clean water and emergency medicine. ',
        isSuspicious: false,
        explanationVi: 'Mục đích sử dụng rõ ràng, hợp lý cho một đợt cứu trợ.',
        explanationEn: 'A clear, reasonable purpose for a relief drive.',
      ),
      ScenarioSegment(
        id: 'cha_personal_account',
        textVi:
            'Mọi người chuyển khoản ủng hộ vào số tài khoản cá nhân của anh Tuấn, thành viên phụ trách quỹ đợt này, thay vì tài khoản của Hội. ',
        textEn:
            'Please send donations to Mr. Tuan\'s personal account, the member managing this fund, instead of the chapter\'s own account. ',
        isSuspicious: true,
        explanationVi:
            'Đây là chi tiết duy nhất sai, dễ bỏ qua vì phần còn lại nghe rất thật: tiền quyên góp nên vào tài khoản chính thức của tổ chức, có thể tra cứu và đối chiếu công khai -- không phải tài khoản cá nhân của một thành viên, dù được giải thích hợp lý đến đâu.',
        explanationEn:
            'This is the one wrong detail, easy to miss because everything else sounds genuine: donations should go to the organization\'s own official account, which can be publicly checked -- not a member\'s personal account, however reasonable the explanation sounds.',
      ),
      ScenarioSegment(
        id: 'cha_transparency',
        textVi: 'Sau đợt quyên góp sẽ có danh sách và hóa đơn công khai trên trang của Hội. ',
        textEn: 'After the drive, a list and receipts will be posted publicly on the chapter\'s page. ',
        isSuspicious: false,
        explanationVi:
            'Một lời hứa minh bạch nghe yên tâm, nhưng nó không thay đổi việc tiền đang được gửi vào một tài khoản cá nhân ở câu trên.',
        explanationEn:
            'A promise of transparency sounds reassuring, but it does not change the fact that the money above is going to a personal account.',
      ),
      ScenarioSegment(
        id: 'cha_thanks',
        textVi: 'Cảm ơn tấm lòng của mọi người trong lúc khó khăn này. ',
        textEn: 'Thank you all for your generosity during this difficult time. ',
        isSuspicious: false,
        explanationVi: 'Một lời cảm ơn chân thành thường thấy ở các lời kêu gọi quyên góp thật.',
        explanationEn: 'A heartfelt thank-you, common in genuine donation appeals.',
      ),
      ScenarioSegment(
        id: 'cha_closing',
        textVi: 'Ai có thắc mắc gì cứ liên hệ văn phòng Hội Chữ thập đỏ phường nhé.',
        textEn: 'If you have any questions, please contact the ward Red Cross office.',
        isSuspicious: false,
        explanationVi: 'Hướng dẫn liên hệ văn phòng chính thức là một dấu hiệu tốt.',
        explanationEn: 'Pointing you to the official office is a good sign.',
      ),
    ],
  ),
];
