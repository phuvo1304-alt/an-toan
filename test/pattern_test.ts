// Tests for the rule-based pre-check (supabase/functions/analyze-scam/patterns.ts).
// Run: npx deno test test/pattern_test.ts
//
// For each category: input [0] is the messageVi of the matching isScam:true
// question in lib/features/quiz/quiz_data.dart, copied verbatim. That file has
// only ONE scam per category, so input [1] is an extra example written for this
// test from research/scam_patterns_vn.md (obfuscated numbers/domains, no real
// message copied).

import { assert, assertEquals } from "jsr:@std/assert@^1.0.0";
import { preCheck } from "../supabase/functions/analyze-scam/patterns.ts";

const SCAM_INPUTS: Record<string, [string, string]> = {
  fake_job: [
    // quiz_data.dart: fake_job_tiktok
    "Tuyển cộng tác viên online! Việc nhẹ lương cao: chỉ cần like video TikTok, " +
      "nhận 300.000đ/ngày. Nạp 200.000đ phí kích hoạt tài khoản để bắt đầu nhận nhiệm vụ. " +
      "Inbox Zalo 09xx xxx 512.",
    // written for this test
    "Shop tuyển CTV chốt đơn tại nhà, hoa hồng 15%. Nhiệm vụ đầu tiên nhận ngay 50k, " +
      "nhiệm vụ sau cần nạp tiền để mua đơn, xong hoàn lại cả gốc lẫn lãi. Kết bạn Telegram để nhận việc.",
  ],
  fake_scholarship: [
    // quiz_data.dart: fake_scholarship_fee
    "Chúc mừng em đã được chọn nhận học bổng du học toàn phần trị giá 500 triệu đồng! " +
      "Để giữ suất, em vui lòng chuyển 1.500.000đ phí hồ sơ trong 48 giờ. " +
      "Vui lòng không chia sẻ thông tin này với người khác.",
    // written for this test
    "Thông báo: Em đủ điều kiện tham gia chương trình trao đổi sinh viên tại Nhật, miễn 100% học phí. " +
      "Vui lòng đóng phí giữ chỗ 3.000.000đ trước thứ Sáu để được ưu tiên xét duyệt.",
  ],
  phishing: [
    // quiz_data.dart: fake_bank_locked
    "[Vietcombank] Tài khoản của quý khách đã bị tạm khóa do đăng nhập bất thường. " +
      "Vui lòng xác thực trong 24h tại vcb-xacthuc[.]top để tránh bị khóa vĩnh viễn.",
    // written for this test
    "Thông báo: Tài khoản của bạn sẽ bị khóa vĩnh viễn do chưa cập nhật sinh trắc học. " +
      "Truy cập xx-sinhtrachoc[.]xyz để xác minh ngay.",
  ],
  impersonation: [
    // quiz_data.dart: otp_friend_request
    "Ê, mình lỡ đăng ký Zalo bằng số của bạn nên mã OTP gửi nhầm qua máy bạn rồi. " +
      "Bạn đọc giúp mình 6 số vừa nhận được với, gấp lắm!",
    // written for this test
    "Đây là cán bộ điều tra Công an quận. Anh có liên quan đến một đường dây rửa tiền, yêu cầu chuyển " +
      "toàn bộ tiền vào tài khoản tạm giữ để chứng minh trong sạch. Không được kể chuyện này với ai.",
  ],
  investment: [
    // quiz_data.dart: investment_crypto
    "Nhóm đầu tư tiền ảo VIP: lợi nhuận cam kết 30%/tuần, không rủi ro! Đã có 5.000 " +
      "thành viên kiếm tiền mỗi ngày. Chỉ cần nạp tối thiểu 1 triệu, càng nạp nhiều lãi " +
      "càng cao.",
    // written for this test
    "Chuyên gia dẫn dắt nhóm kín đầu tư forex, lãi 5%/ngày, hoàn vốn nhanh trong 1 tuần. " +
      "Mời thêm bạn bè nhận hoa hồng 10%.",
  ],
  romance: [
    // quiz_data.dart: romance_gift_fee
    "Anh nhớ em lắm. Anh đã gửi cho em một hộp quà từ nước ngoài, có điện thoại và " +
      "vòng tay. Hải quan giữ lại, em đóng giúp 3 triệu phí thông quan nhé, anh sẽ trả lại sau.",
    // written for this test
    "Em yêu, anh là kỹ sư người Anh đang làm việc trên giàn khoan. Anh gửi em kiện hàng có tiền mặt " +
      "và trang sức, bên vận chuyển báo cần nộp thuế nhập khẩu 8 triệu mới giao được.",
  ],
  loan: [
    // quiz_data.dart: loan_app_fee
    "Vay nhanh 20 triệu trong 5 phút, không cần thẩm định, chỉ cần CCCD! Tải ứng dụng " +
      "tại link bên dưới, đóng 500.000đ phí bảo hiểm khoản vay trước khi giải ngân.",
    // written for this test
    "Hồ sơ vay 30 triệu của anh đã được duyệt nhưng ghi sai số tài khoản nên khoản vay bị đóng băng. " +
      "Anh chuyển 3 triệu phí chứng minh tài chính để mở khóa giải ngân.",
  ],
  other: [
    // quiz_data.dart: fake_parcel_sms
    "Đơn hàng của bạn không thể giao do sai địa chỉ. Vui lòng cập nhật địa chỉ và " +
      "thanh toán phí giao lại 15.000đ tại giaohang-vn[.]info trong hôm nay.",
    // written for this test
    "Shipper đây ạ, hàng của chị em để ở chỗ cũ rồi nhé, chị chuyển khoản 289k tiền hàng " +
      "giúp em vào số 09xx xxx 731.",
  ],
};

for (const [scamType, inputs] of Object.entries(SCAM_INPUTS)) {
  inputs.forEach((input, i) => {
    Deno.test(`${scamType} [${i}] is flagged as ${scamType}`, () => {
      const result = preCheck(input);
      assert(result.length > 0, `expected matches, got none`);
      assert(
        result.some((r) => r.scamType === scamType),
        `expected ${scamType}, got ${JSON.stringify(result)}`,
      );
    });
  });
}

const SAFE_INPUTS = [
  "Chủ nhà nhắc em chuyển tiền nhà tháng này như mọi tháng trước ngày 5, vẫn số tài khoản cũ nha.",
  "Đơn hàng GHN của bạn đang được giao, shipper sẽ liên hệ trong khoảng 30 phút tới.",
  "Lương tháng 10 đã được chuyển vào tài khoản đăng ký.",
];

SAFE_INPUTS.forEach((input, i) => {
  Deno.test(`safe [${i}] has no matches`, () => {
    assertEquals(preCheck(input), []);
  });
});

Deno.test("empty string has no matches", () => {
  assertEquals(preCheck(""), []);
});
