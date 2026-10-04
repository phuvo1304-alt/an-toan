/// One quiz question: a message, whether it is a scam, and why.
class QuizQuestion {
  final String id;
  final String messageVi;
  final String messageEn;
  final bool isScam;
  final String explanationVi;
  final String explanationEn;

  const QuizQuestion({
    required this.id,
    required this.messageVi,
    required this.messageEn,
    required this.isScam,
    required this.explanationVi,
    required this.explanationEn,
  });

  String message(String languageCode) =>
      languageCode == 'en' ? messageEn : messageVi;

  String explanation(String languageCode) =>
      languageCode == 'en' ? explanationEn : explanationVi;
}

/// The bundled quiz. 8 scams (one per common Vietnam pattern) + 4 normal
/// messages, so the answer is not always "scam".
///
/// Safety notes for the content:
/// - Links are "defanged" ([.] instead of .) so they can never be opened.
/// - Phone and account numbers are partly hidden (xxx) so none of them
///   belongs to a real person.
const quizQuestions = <QuizQuestion>[
  // ---- Scams ---------------------------------------------------------------
  QuizQuestion(
    id: 'fake_job_tiktok',
    isScam: true,
    messageVi:
        'Tuyển cộng tác viên online! Việc nhẹ lương cao: chỉ cần like video TikTok, '
        'nhận 300.000đ/ngày. Nạp 200.000đ phí kích hoạt tài khoản để bắt đầu nhận nhiệm vụ. '
        'Inbox Zalo 09xx xxx 512.',
    messageEn:
        'Online collaborators wanted! Easy work, high pay: just like TikTok videos and '
        'earn 300,000 VND a day. Deposit 200,000 VND to activate your account and start '
        'getting tasks. Message us on Zalo 09xx xxx 512.',
    explanationVi:
        'Đây là bẫy "việc nhẹ lương cao". Công việc thật không bao giờ bắt bạn nạp tiền '
        'để được làm việc. Thường lúc đầu họ trả vài khoản nhỏ để bạn tin, rồi yêu cầu nạp '
        'số tiền ngày càng lớn và không trả lại.',
    explanationEn:
        'This is an "easy work, high pay" trap. A real job never asks you to pay to start '
        'working. They often pay small amounts first to win your trust, then ask for bigger '
        'and bigger deposits that you never get back.',
  ),
  QuizQuestion(
    id: 'fake_bank_locked',
    isScam: true,
    messageVi:
        '[Vietcombank] Tài khoản của quý khách đã bị tạm khóa do đăng nhập bất thường. '
        'Vui lòng xác thực trong 24h tại vcb-xacthuc[.]top để tránh bị khóa vĩnh viễn.',
    messageEn:
        '[Vietcombank] Your account has been temporarily locked due to unusual sign-in '
        'activity. Please verify within 24 hours at vcb-xacthuc[.]top to avoid a permanent lock.',
    explanationVi:
        'Ngân hàng không gửi link lạ để bạn "xác thực" tài khoản. Tên miền ".top" không '
        'phải trang chính thức, và lời đe dọa "khóa vĩnh viễn trong 24h" là để bạn hoảng '
        'mà làm theo. Hãy tự mở ứng dụng ngân hàng hoặc gọi số tổng đài in sau thẻ.',
    explanationEn:
        'Banks do not send strange links asking you to "verify" your account. A ".top" '
        'address is not the official website, and the "permanent lock in 24 hours" threat '
        'is meant to make you panic. Open your bank app yourself or call the number on the '
        'back of your card.',
  ),
  QuizQuestion(
    id: 'fake_scholarship_fee',
    isScam: true,
    messageVi:
        'Chúc mừng em đã được chọn nhận học bổng du học toàn phần trị giá 500 triệu đồng! '
        'Để giữ suất, em vui lòng chuyển 1.500.000đ phí hồ sơ trong 48 giờ. '
        'Vui lòng không chia sẻ thông tin này với người khác.',
    messageEn:
        'Congratulations, you have been selected for a full study-abroad scholarship worth '
        '500 million VND! To keep your place, please transfer a 1,500,000 VND processing fee '
        'within 48 hours. Please do not share this with anyone.',
    explanationVi:
        'Học bổng thật không bắt bạn trả phí để "giữ suất", nhất là khi bạn chưa từng nộp '
        'đơn. Hạn chót gấp và lời dặn "đừng kể với ai" là để bạn không kịp hỏi thầy cô hay '
        'bố mẹ.',
    explanationEn:
        'Real scholarships do not charge a fee to "keep your place", especially one you '
        'never applied for. The tight deadline and "tell no one" request are there so you '
        'do not have time to ask a teacher or parent.',
  ),
  QuizQuestion(
    id: 'fake_parcel_sms',
    isScam: true,
    messageVi:
        'Đơn hàng của bạn không thể giao do sai địa chỉ. Vui lòng cập nhật địa chỉ và '
        'thanh toán phí giao lại 15.000đ tại giaohang-vn[.]info trong hôm nay.',
    messageEn:
        'Your parcel could not be delivered because of a wrong address. Please update your '
        'address and pay a 15,000 VND redelivery fee at giaohang-vn[.]info today.',
    explanationVi:
        'Số tiền nhỏ khiến bạn dễ mất cảnh giác, nhưng trang này lấy thông tin thẻ ngân '
        'hàng của bạn. Tin nhắn không nói tên cửa hàng hay mã đơn. Hãy kiểm tra đơn hàng '
        'trong ứng dụng bạn đã mua.',
    explanationEn:
        'The small amount makes you relax, but the page steals your card details. The '
        'message does not name the shop or the order number. Check the order inside the app '
        'you bought from.',
  ),
  QuizQuestion(
    id: 'investment_crypto',
    isScam: true,
    messageVi:
        'Nhóm đầu tư tiền ảo VIP: lợi nhuận cam kết 30%/tuần, không rủi ro! Đã có 5.000 '
        'thành viên kiếm tiền mỗi ngày. Chỉ cần nạp tối thiểu 1 triệu, càng nạp nhiều lãi '
        'càng cao.',
    messageEn:
        'VIP crypto investment group: guaranteed 30% profit per week, zero risk! 5,000 '
        'members already earn money every day. Minimum deposit just 1 million VND, the more '
        'you deposit the more you earn.',
    explanationVi:
        'Không có khoản đầu tư thật nào "cam kết lợi nhuận" mà "không rủi ro", và 30% mỗi '
        'tuần là phi thực tế. Những nhóm này thường cho bạn thấy lãi giả trên màn hình, '
        'nhưng không cho rút tiền.',
    explanationEn:
        'No real investment can promise "guaranteed profit" with "zero risk", and 30% a '
        'week is impossible. These groups usually show fake profits on screen but never let '
        'you withdraw.',
  ),
  QuizQuestion(
    id: 'loan_app_fee',
    isScam: true,
    messageVi:
        'Vay nhanh 20 triệu trong 5 phút, không cần thẩm định, chỉ cần CCCD! Tải ứng dụng '
        'tại link bên dưới, đóng 500.000đ phí bảo hiểm khoản vay trước khi giải ngân.',
    messageEn:
        'Borrow 20 million VND in 5 minutes, no checks, just your ID card! Download the app '
        'from the link below and pay a 500,000 VND loan insurance fee before the money is sent.',
    explanationVi:
        'Ứng dụng cho vay đòi "phí" trước khi giải ngân thường lấy tiền rồi biến mất. Nhiều '
        'ứng dụng còn đọc danh bạ trong điện thoại để đe dọa người thân của bạn. Không bao '
        'giờ cài ứng dụng vay từ link lạ.',
    explanationEn:
        'Loan apps that want a "fee" before paying out usually take the money and disappear. '
        'Many also read your contacts to threaten your family. Never install a loan app from '
        'a random link.',
  ),
  QuizQuestion(
    id: 'otp_friend_request',
    isScam: true,
    messageVi:
        'Ê, mình lỡ đăng ký Zalo bằng số của bạn nên mã OTP gửi nhầm qua máy bạn rồi. '
        'Bạn đọc giúp mình 6 số vừa nhận được với, gấp lắm!',
    messageEn:
        'Hey, I accidentally signed up for Zalo with your number, so the OTP went to your '
        'phone. Can you read me the 6 digits you just got? It is really urgent!',
    explanationVi:
        'Mã OTP là chìa khóa tài khoản của bạn. Có người đang cố đăng nhập vào tài khoản '
        'CỦA BẠN, và nếu bạn đọc mã, họ chiếm được tài khoản rồi lừa tiếp bạn bè của bạn. '
        'Tài khoản của bạn bè cũng có thể đã bị chiếm, nên hãy gọi điện trực tiếp cho họ để hỏi.',
    explanationEn:
        'An OTP is the key to your account. Someone is trying to sign in to YOUR account, '
        'and if you read them the code they take it over and use it to trick your friends. '
        'Your friend\'s account may already be hacked, so call them directly to check.',
  ),
  QuizQuestion(
    id: 'romance_gift_fee',
    isScam: true,
    messageVi:
        'Anh nhớ em lắm. Anh đã gửi cho em một hộp quà từ nước ngoài, có điện thoại và '
        'vòng tay. Hải quan giữ lại, em đóng giúp 3 triệu phí thông quan nhé, anh sẽ trả lại sau.',
    messageEn:
        'I miss you so much. I sent you a gift box from abroad with a phone and a bracelet. '
        'Customs is holding it, can you pay the 3 million VND clearance fee? I will pay you back.',
    explanationVi:
        'Đây là kiểu lừa đảo tình cảm: người lạ quen qua mạng, nhanh chóng tạo tình cảm, '
        'rồi bịa ra lý do cần bạn chuyển tiền. Món quà và "hải quan" đều không có thật. '
        'Hãy kể cho người lớn đáng tin cậy.',
    explanationEn:
        'This is a romance scam: an online stranger builds feelings quickly, then invents a '
        'reason you need to send money. The gift and the "customs" are not real. Talk to a '
        'trusted adult.',
  ),

  // ---- Normal messages -----------------------------------------------------
  QuizQuestion(
    id: 'safe_teacher_meeting',
    isScam: false,
    messageVi:
        'Thông báo: Họp phụ huynh lớp 11A2 vào 8h sáng Chủ nhật này tại phòng B105. '
        'Các em nhắc bố mẹ đến đúng giờ nhé. - GVCN',
    messageEn:
        'Notice: Parent meeting for class 11A2 at 8 AM this Sunday in room B105. '
        'Please remind your parents to be on time. - Homeroom teacher',
    explanationVi:
        'Tin nhắn chỉ thông báo lịch họp: không có link, không đòi tiền, không xin mã OTP '
        'hay thông tin cá nhân. Nếu thấy lạ, bạn vẫn có thể hỏi lại thầy cô trên lớp.',
    explanationEn:
        'The message just announces a meeting: no link, no request for money, OTP or '
        'personal details. If anything feels off, you can still ask your teacher in class.',
  ),
  QuizQuestion(
    id: 'safe_bank_otp_self',
    isScam: false,
    messageVi:
        '(Bạn vừa tự chuyển tiền trong ứng dụng ngân hàng, và nhận được:) '
        'Ma OTP cua quy khach la 482913. Tuyet doi KHONG cung cap ma nay cho bat ky ai, '
        'ke ca nhan vien ngan hang.',
    messageEn:
        '(You just started a transfer in your bank app yourself, and receive:) '
        'Your OTP is 482913. NEVER share this code with anyone, including bank staff.',
    explanationVi:
        'Đây là tin OTP bình thường vì CHÍNH BẠN vừa thực hiện giao dịch, và nó dặn bạn '
        'không đưa mã cho ai. Mã chỉ để bạn tự nhập vào ứng dụng. Nếu bạn nhận OTP khi '
        'không làm gì cả, có người đang thử đăng nhập vào tài khoản của bạn.',
    explanationEn:
        'This is a normal OTP message because YOU just made the transaction, and it warns '
        'you not to share the code. The code is only for you to type into the app. If you get '
        'an OTP when you did nothing, someone is trying to get into your account.',
  ),
  QuizQuestion(
    id: 'safe_mom_errand',
    isScam: false,
    messageVi:
        'Mẹ đây. Chiều nay đi học về con ghé tiệm mua giúp mẹ ổ bánh mì với hộp sữa nhé. '
        'Tối mẹ về muộn.',
    messageEn:
        'It\'s Mom. On your way home from school this afternoon, please pick up a loaf of '
        'bread and a carton of milk. I\'ll be home late tonight.',
    explanationVi:
        'Một lời nhắn bình thường trong gia đình: không đòi chuyển khoản, không có link, '
        'không gấp gáp. Nhưng hãy cẩn thận nếu "người thân" nhắn từ số lạ và xin tiền gấp: '
        'khi đó hãy gọi điện để kiểm tra.',
    explanationEn:
        'A normal family message: no transfer request, no link, no pressure. But be careful '
        'if a "relative" texts from an unknown number asking for money urgently: call them to '
        'check.',
  ),
  QuizQuestion(
    id: 'safe_club_meeting',
    isScam: false,
    messageVi:
        'CLB Tiếng Anh: Buổi sinh hoạt tuần này dời sang thứ Năm, 16h30 tại thư viện '
        'trường. Bạn nào bận thì báo lại cho lớp trưởng CLB nhé.',
    messageEn:
        'English Club: This week\'s meeting moves to Thursday, 4:30 PM in the school '
        'library. If you are busy, let the club leader know.',
    explanationVi:
        'Tin nhắn chỉ đổi lịch sinh hoạt ở một địa điểm bạn biết, không yêu cầu tiền, link '
        'hay thông tin cá nhân. Đây là tin nhắn bình thường.',
    explanationEn:
        'The message only changes a meeting time at a place you know, and asks for no money, '
        'links or personal details. This is a normal message.',
  ),
];
