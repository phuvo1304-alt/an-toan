# Vietnam scam patterns (research notes)

Purpose: describe the *recurring structure* of common scams in Vietnam, so the
rule-based pre-check in `supabase/functions/analyze-scam/patterns.ts` and the
quiz content rest on public reporting rather than guesses.

Method and limits:
- One web search per category (8 searches in total), restricted to allowed
  sources: VnExpress, Tuổi Trẻ, Thanh Niên, Dân Trí, Công An Nhân Dân and
  VietnamNet. No private messages, DMs or closed groups were used.
- The structure notes summarise what these articles report, as returned by the
  search tool. They were not checked line by line against the full articles.
- Dates are taken from the article URL where it encodes one; otherwise "date
  not shown".
- No real message is copied. Every number, domain and account below is
  invented and obfuscated, in the same style as `lib/features/quiz/quiz_data.dart`
  (`vcb-xacthuc[.]top`, `09xx xxx 512`).

---

## fake_job (việc nhẹ lương cao / cộng tác viên)

Sources:
- [Cảnh giác hình thức lừa đảo 'việc nhẹ lương cao'](https://thanhnien.vn/canh-giac-hinh-thuc-lua-dao-viec-nhe-luong-cao-185241015151541406.htm) (Thanh Niên, 2024-10-15)
- [Lừa đảo 'việc nhẹ, lương cao' rầm rộ trở lại dịp Tết Ất Tỵ 2025](https://thanhnien.vn/lua-dao-viec-nhe-luong-cao-ram-ro-tro-lai-dip-tet-at-ty-2025-185250115145206465.htm) (Thanh Niên, 2025-01-15)
- [Sập bẫy 'làm nhiệm vụ, nhận tiền hoa hồng'](https://tuoitre.vn/sap-bay-lam-nhiem-vu-nhan-tien-hoa-hong-2022080508001051.htm) (Tuổi Trẻ, 2022-08-05)
- [Xưng nhân viên Điện Máy Xanh, Tiki lừa đảo 'việc nhẹ lương cao'](https://tuoitre.vn/xung-nhan-vien-dien-may-xanh-tiki-lua-dao-viec-nhe-luong-cao-nhieu-nguoi-van-dinh-20230701223554971.htm) (Tuổi Trẻ, 2023-07-01)

Recurring structure: the scammer claims to recruit "cộng tác viên" (CTV) for a
well-known shop, e-commerce platform or TikTok, promising a high daily or
monthly income for easy "nhiệm vụ" (likes, reviews, "chốt đơn" order
confirmations). The first small task pays out to build trust. After that,
tasks require the victim to "nạp tiền" (deposit), to buy orders or pay a
"phí kích hoạt" (activation fee), with a promised refund plus "hoa hồng"
(commission). Next comes a "VIP" or bigger-package step demanding much larger
deposits, and excuses ("wrong syntax", "task not finished") to block
withdrawals. The chat is often moved to Telegram or Zalo. The articles note
that the big platforms run no such task-based collaborator programmes.
Typical shape: `Tuyển CTV… 300k/ngày… nạp 200k kích hoạt… Zalo 09xx xxx 512`.

## fake_scholarship (học bổng giả)

Sources:
- [Công an TP.HCM cảnh báo chiêu lừa 'học bổng du học' chiếm đoạt hàng tỉ đồng](https://tuoitre.vn/cong-an-tp-hcm-canh-bao-chieu-lua-hoc-bong-du-hoc-chiem-doat-hang-ti-dong-20251102112712795.htm) (Tuổi Trẻ, 2025-11-02)
- [Nhiều thủ đoạn lừa đảo yêu cầu chuyển tiền nhận giấy báo dự thi, trao đổi sinh viên, học bổng](https://tuoitre.vn/nhieu-thu-doan-lua-dao-yeu-cau-chuyen-tien-nhan-giay-bao-du-thi-trao-doi-sinh-vien-hoc-bong-20250603094430601.htm) (Tuổi Trẻ, 2025-06-03)
- [Cảnh báo lừa đảo ở các chương trình trao đổi sinh viên quốc tế, du học](https://thanhnien.vn/canh-bao-lua-dao-o-cac-chuong-trinh-trao-doi-sinh-vien-quoc-te-du-hoc-185250604112248172.htm) (Thanh Niên, 2025-06-04)
- [Thủ đoạn "bắt cóc online" mới: Giả mạo học bổng du học quốc tế](https://cand.com.vn/tai-chinh-40/thu-doan-bat-coc-online-moi-gia-mao-hoc-bong-du-hoc-quoc-te-chiem-doat-hang-ty-dong--i786750) (Công An Nhân Dân, date not shown)
- [Sự thật về thông báo chương trình "học bổng quốc tế"](https://dantri.com.vn/giao-duc/su-that-ve-thong-bao-chuong-trinh-hoc-bong-quoc-te-20251003155624910.htm) (Dân Trí, 2025-10-03)

Recurring structure: fake Facebook pages, emails or websites copy the logo and
name of a real university, ministry or partner programme. They advertise "học
bổng toàn phần", "miễn 100% học phí" or "trao đổi sinh viên" with a simple
application, then send a fake acceptance letter. Money is requested under
changing labels: "phí hồ sơ", "phí giữ suất / giữ chỗ", "đặt cọc", "phí xử lý"
or tuition up front, with a short deadline and a hint of "ưu tiên xét duyệt"
(priority review). Some cases escalate into isolating the student ("bắt cóc
online"). Official advice is to verify only via the school's own website,
embassy or the Ministry of Education and Training. Typical shape: `Chúc mừng em
được chọn… để giữ suất chuyển 1.500.000đ phí hồ sơ trong 48 giờ`.

## phishing (tin nhắn/website giả mạo ngân hàng)

Sources:
- [Ngỡ ngàng vì nhận tin nhắn lừa đảo dọa khóa tài khoản ngân hàng](https://vietnamnet.vn/ngo-ngang-vi-nhan-tin-nhan-lua-dao-doa-khoa-tai-khoan-ngan-hang-i289507.html) (VietnamNet, date not shown)
- [Tin nhắn lừa đảo, giả mạo ngân hàng trở lại "tấn công" người dùng](https://dantri.com.vn/cong-nghe/tin-nhan-lua-dao-gia-mao-ngan-hang-tro-lai-tan-cong-nguoi-dung-20220422225902239.htm) (Dân Trí, 2022-04-22)
- [Cảnh báo thủ đoạn giả mạo website ngân hàng để chiếm đoạt tài sản](https://dantri.com.vn/phap-luat/canh-bao-thu-doan-gia-mao-website-ngan-hang-de-chiem-doat-tai-san-20260406184451779.htm) (Dân Trí, 2026-04-06)
- [Cảnh báo mạo danh tin nhắn của Vietcombank chiếm đoạt tiền của khách](https://tuoitre.vn/canh-bao-mao-danh-tin-nhan-cua-vietcombank-chiem-doat-tien-cua-khach-20210521201628408.htm) (Tuổi Trẻ, 2021-05-21)

Recurring structure: an SMS, sometimes appearing in the same thread as the
bank's real brandname, says the account is "bị khóa / tạm khóa", needs
"cập nhật thông tin", is receiving a transfer that must be "xác minh", or
offers an upgrade (e.g. "Priority") or a refund or gift. It includes a link to a
login page that copies the bank's look, which asks for the username, password
and OTP. Urgency comes from a deadline ("trong 24h") and a threat ("khóa vĩnh
viễn"). Domain shape: bank abbreviation plus a Vietnamese keyword plus a cheap
TLD, e.g. `vcb-xacthuc[.]top`, `xx-bank-hotro[.]xyz`. Banks say they never
ask for a password or OTP through a link.

## impersonation (giả danh công an/tòa án, người quen, chiếm OTP)

Sources:
- [Giả danh công an gọi điện đe dọa, đến tận nhà lấy 1 tỉ và 5,2 cây vàng](https://tuoitre.vn/gia-danh-cong-an-goi-dien-de-doa-den-tan-nha-lay-1-ti-va-5-2-cay-vang-2025022414220777.htm) (Tuổi Trẻ, 2025-02-24)
- [Thao túng tâm lý nạn nhân qua điện thoại để lừa đảo chiếm đoạt tài sản](https://vietnamnet.vn/thao-tung-tam-ly-nan-nhan-qua-dien-thoai-de-lua-dao-chiem-doat-tai-san-2167274.html) (VietnamNet, date not shown)
- [Nhận được những cuộc gọi này, dập máy ngay để tránh bị lừa đảo](https://dantri.com.vn/cong-nghe/nhan-duoc-nhung-cuoc-goi-nay-dap-may-ngay-de-tranh-bi-lua-dao-20240523002355793.htm) (Dân Trí, 2024-05-23)
- [Nam sinh bị 'bắt cóc online' ở TP HCM, báo gia đình chuyển 800 triệu đồng](https://vnexpress.net/nam-sinh-bi-bat-coc-online-o-tp-hcm-bao-gia-dinh-chuyen-800-trieu-dong-5128168.html) (VnExpress, date not shown)

Recurring structure: the caller claims to be "cán bộ" of the police, procuracy
("viện kiểm sát") or court ("tòa án"), usually from a distant province so it is
hard to check. They say the victim is "liên quan" to a drug, money-laundering
or fraud case ("chuyên án", "đường dây"). The victim must move money to a
"tài khoản tạm giữ" or "tài khoản của cơ quan điều tra" to "chứng minh trong
sạch", or install an app. They insist on secrecy ("không được kể với ai") and
on isolation, which is the basis of "bắt cóc online" against students. Calls
often use VoIP. Authorities say they summon people by letter and never ask for
transfers by phone. A student-level variant from the quiz seed: a "friend"
whose account was already taken over says an OTP was "gửi nhầm" and asks you to
read it back, which hands over your own account.

## investment (đầu tư tiền ảo / lợi nhuận cam kết)

Sources:
- [Bắt nhóm chiêu dụ đầu tư tiền ảo trên toàn quốc với 'lợi nhuận siêu lớn'](https://tuoitre.vn/bat-nhom-chieu-du-dau-tu-tien-ao-tren-toan-quoc-voi-loi-nhuan-sieu-lon-lua-dao-10-000-ty-dong-20250528073026871.htm) (Tuổi Trẻ, 2025-05-28)
- [Lại nở rộ lừa đảo đầu tư tiền ảo, nhiều người bị lừa hàng tỉ đồng](https://tuoitre.vn/lai-no-ro-lua-dao-dau-tu-tien-ao-nhieu-nguoi-bi-lua-hang-ti-dong-20240923222125661.htm) (Tuổi Trẻ, 2024-09-23)
- [Lại rộ lên lừa đảo đầu tư tiền số](https://thanhnien.vn/lai-ro-len-lua-dao-dau-tu-tien-so-185250406164158362.htm) (Thanh Niên, 2025-04-06)
- ["Sập bẫy" đầu tư tài chính, tiền ảo qua mạng xã hội](https://cand.com.vn/ho-so-interpol/sap-bay-dau-tu-tai-chinh-tien-ao-qua-mang-xa-hoi-i737657/) (Công An Nhân Dân, date not shown)

Recurring structure: a group or "chuyên gia" (expert) on social media promises
"lợi nhuận cao, không rủi ro" and "cam kết lãi 20–30%/tháng" (sometimes per
week or day), "hoàn vốn nhanh", plus "hoa hồng khi mời thêm người" (a referral
pyramid). Social proof is faked: shows of wealth, screenshots of winnings, and
fake accounts chatting in the group to create FOMO. The victim deposits on a
"sàn" (platform) controlled by the group. The balance shows huge gains but
withdrawals are blocked, then more deposits are demanded. One rule of thumb
quoted: any offer promising more than about 3× the bank deposit rate is a
warning sign. Typical shape: `Nhóm VIP… lãi 30%/tuần… không rủi ro… càng nạp
nhiều lãi càng cao`.

## romance (lừa đảo tình cảm / gửi quà)

Sources:
- [Kịp thời ngăn chặn vụ lừa đảo "chuyển tiền phí để nhận quà của Việt kiều Mỹ"](https://cand.com.vn/Cong-nghe/kip-thoi-ngan-chan-vu-lua-dao-chuyen-tien-phi-de-nhan-qua-cua-viet-kieu-my-i775769) (Công An Nhân Dân, date not shown)
- [Một người phụ nữ 64 tuổi suýt mất 5.000 USD vì tin lời "người yêu" qua mạng](https://tuoitre.vn/nld/mot-nguoi-phu-nu-64-tuoi-suyt-mat-5000-usd-vi-tin-loi-nguoi-yeu-qua-mang-196260422171649658.htm) (Tuổi Trẻ/NLĐ, 2026-04-22)
- [Nhức nhối cạm bẫy tình ảo](https://amp.cand.com.vn/ho-so-interpol/nhuc-nhoi-cam-bay-tinh-ao-i767520/) (Công An Nhân Dân, date not shown)
- [Tái diễn thủ đoạn "kết bạn tặng quà" để lừa tiền](https://cand.com.vn/Ho-so-Interpol/Tai-dien-thu-doan-ket-ban-tang-qua-de-lua-tien-i348872/) (Công An Nhân Dân, date not shown)

Recurring structure: a stranger befriends the victim on social media and
quickly builds affection. They claim to be a foreigner or overseas Vietnamese
("Việt kiều") with a trusted job: soldier, doctor, engineer or businessperson.
They announce a gift or parcel ("quà", "kiện hàng") with cash, jewellery or
phones. Then a second actor posing as customs ("hải quan"), the post office, a
bank or the police says the parcel is held ("bị giữ") and demands "phí hải
quan", "phí thông quan", "thuế nhập khẩu" or "phí vận chuyển quốc tế". These
fees are repeated and grow each time. Emotional pressure ("nhớ em", "anh sẽ
trả lại") replaces the official urgency of other scams.

## loan (vay tiền online / phí trước khi giải ngân)

Sources:
- [Vạch trần thủ đoạn lừa đảo cho vay tiền online lãi suất thấp](https://vietnamnet.vn/vach-tran-thu-doan-lua-dao-cho-vay-tien-online-lai-suat-thap-789212.html) (VietnamNet, date not shown)
- [Nhiều người sập bẫy lừa 'đảm bảo được vay tiền, chỉ cần nộp phí'](https://tuoitre.vn/nhieu-nguoi-sap-bay-lua-dam-bao-duoc-vay-tien-chi-can-nop-phi-20210320233731389.htm) (Tuổi Trẻ, 2021-03-20)
- [Cảnh giác khi vay tiền online](https://dantri.com.vn/phap-luat/canh-giac-khi-vay-tien-online-20251126193329988.htm) (Dân Trí, 2025-11-26)
- [Cảnh giác khi vay tiền qua các công ty tài chính trên mạng](https://dantri.com.vn/phap-luat/canh-giac-khi-vay-tien-qua-cac-cong-ty-tai-chinh-tren-mang-20250608095525474.htm) (Dân Trí, 2025-06-08)

Recurring structure: an ad or page posing as a bank or finance company offers
a fast, low-interest loan with almost no checks ("không cần thẩm định", "chỉ
cần CCCD", "duyệt trong 5 phút"). After a fake contract, money is requested
before payout under rotating labels: "phí làm hồ sơ", "phí bảo hiểm khoản vay",
"phí bảo lãnh", "phí giải ngân", "chứng minh năng lực tài chính" (10–15% of the
loan), or "sai số tài khoản / sai nội dung" that has "frozen" the loan and needs
a fee to unlock. Some apps request access to contacts ("danh bạ") and later use
it to shame or threaten. Real lenders say they charge nothing before payout.

## other (giao hàng/bưu kiện giả, giả shipper)

Sources:
- [Giả shipper 'gửi hàng ở chỗ cũ' để lừa người mua chuyển khoản](https://vnexpress.net/gia-shipper-gui-hang-o-cho-cu-de-lua-nguoi-mua-chuyen-khoan-4802599.html) (VnExpress, date not shown)
- [Phát hoảng với chiêu lừa đóng 'phí ship' 16 ngàn đồng rồi mất mấy trăm triệu đồng](https://thanhnien.vn/phat-hoang-voi-chieu-lua-dong-phi-ship-16-ngan-dong-roi-mat-may-tram-trieu-dong-185250506105957967.htm) (Thanh Niên, 2025-05-06)
- [Cảnh báo tin nhắn giả mạo bưu điện](https://thanhnien.vn/canh-bao-tin-nhan-gia-mao-buu-dien-185251218215611171.htm) (Thanh Niên, 2025-12-18)
- [Lừa đảo mạo danh hãng chuyển phát liên tục tấn công người dùng Việt](https://vietnamnet.vn/lua-dao-mao-danh-hang-chuyen-phat-lien-tuc-tan-cong-nguoi-dung-viet-2313490.html) (VietnamNet, date not shown)

Recurring structure, in two variants:
- **Fake shipper call or chat:** the scammer quotes the real price of an order
  the victim just placed (suggesting leaked order data), says the parcel was
  left "ở chỗ cũ / chỗ mọi lần", and asks for a bank transfer. If the victim
  pays, a second message claims the money was sent "nhầm" (by mistake), for
  example into a membership fee, and pushes a refund process that drains more.
- **Fake post office or courier SMS:** the parcel "không thể giao" because of a
  wrong or missing address, or is "bị giữ" at the warehouse. The victim must
  "cập nhật địa chỉ" and pay a tiny "phí giao lại / phí ship / phí lưu kho" via
  a link, and the page then captures card details and OTP.

The small amount (around 15–16k đ) is the bait. Domain shape:
`giaohang-vn[.]info`, `vnp-buucuc[.]cc`.
