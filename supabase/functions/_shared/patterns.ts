// An Toàn - rule-based pre-check for analyze-scam.
//
// A quick keyword/regex scan that runs BEFORE Claude. It never decides the
// result: index.ts only passes the matched scam types to Claude as a hint to
// double-check. Claude's answer stays the only source of risk_level/risk_score.
//
// The patterns come from research/scam_patterns_vn.md (public news and police
// warnings) and the scam examples in lib/features/quiz/quiz_data.dart.
// No network calls, no state: safe to run on every request.

export interface PatternMatch {
  scamType: string;
  matchedPatterns: string[];
}

interface PatternRule {
  scamType: string;
  label: string;
  regexes: RegExp[]; // case-insensitive, derived from Step 1 + quiz_data.dart seeds
}

const PATTERN_RULES: PatternRule[] = [
  // ---- fake_job: "việc nhẹ lương cao", deposit-to-get-tasks ------------------
  {
    scamType: "fake_job",
    label: "easy work, high pay",
    regexes: [/việc nhẹ,? lương cao/i],
  },
  {
    scamType: "fake_job",
    label: "collaborator recruitment",
    regexes: [/cộng tác viên/i, /tuyển ctv\b/i],
  },
  {
    scamType: "fake_job",
    label: "deposit to get tasks or orders",
    regexes: [
      /nạp tiền.{0,20}(nhận|mua|chốt) (đơn|hoa hồng|nhiệm vụ)/i,
      /nạp .{0,40}(nhận|làm) nhiệm vụ/i,
      /phí kích hoạt/i,
    ],
  },
  {
    scamType: "fake_job",
    label: "paid for likes or reviews",
    regexes: [/(like|thả tim|đánh giá|follow).{0,30}(video|sản phẩm|tiktok|shop).{0,40}(nhận|kiếm)/i],
  },
  {
    scamType: "fake_job",
    label: "daily pay promise",
    regexes: [/\d[\d.,]*\s*(k|đ|đồng|nghìn|triệu)\s*\/\s*(ngày|giờ)/i],
  },
  {
    scamType: "fake_job",
    label: "move chat to Telegram",
    regexes: [/(kết bạn|chuyển sang|nhắn|liên hệ)( qua)? telegram/i],
  },

  // ---- fake_scholarship: fees to "keep your place" ----------------------------
  {
    scamType: "fake_scholarship",
    label: "processing or application fee",
    regexes: [/phí (xử lý|hồ sơ|xét hồ sơ)/i],
  },
  {
    scamType: "fake_scholarship",
    label: "fee to keep a place",
    regexes: [/giữ suất/i, /phí (giữ chỗ|đặt cọc)/i],
  },
  {
    scamType: "fake_scholarship",
    label: "priority review promise",
    regexes: [/ưu tiên xét duyệt/i],
  },
  {
    scamType: "fake_scholarship",
    label: "scholarship or exchange that needs payment",
    regexes: [
      /học bổng.{0,120}(phí|chuyển khoản|chuyển \d|đóng|nộp)/i,
      /trao đổi sinh viên.{0,120}(phí|chuyển khoản|đóng|nộp)/i,
    ],
  },

  // ---- phishing: fake bank/e-wallet alerts with a link ------------------------
  {
    scamType: "phishing",
    label: "verify now",
    regexes: [/(xác thực|xác minh) ngay/i, /(xác thực|xác minh|cập nhật).{0,30}(tại|qua|vào) (đường )?(link|liên kết|https?:|\S+\[\.\])/i],
  },
  {
    scamType: "phishing",
    label: "suspicious link",
    regexes: [/\[\.\]/i,/\b[a-z0-9-]+(\[\.\]|\.)(top|xyz|cc|vip|click|icu|online|info)\b/i],
  },
  {
    scamType: "phishing",
    label: "account lock threat",
    regexes: [/tài khoản.{0,30}(bị khóa|tạm khóa|khóa vĩnh viễn)/i, /khóa vĩnh viễn/i],
  },
  {
    scamType: "phishing",
    label: "asks for OTP or password via link",
    regexes: [/(nhập|cung cấp).{0,20}(mã otp|mật khẩu|mã pin).{0,30}(tại|vào|qua) (link|trang|đường dẫn)/i],
  },

  // ---- impersonation: police/court, secrecy, OTP read-back --------------------
  {
    scamType: "impersonation",
    label: "claims to be police or court",
    regexes: [
      /cán bộ (điều tra )?công an/i,
      /tòa án/i,
      /viện kiểm sát/i,
      /cơ quan điều tra/i,
    ],
  },
  {
    scamType: "impersonation",
    label: "accuses you of a crime",
    regexes: [/(liên quan|dính líu).{0,30}(đường dây|ma túy|rửa tiền|chuyên án)/i, /chứng minh (sự )?trong sạch/i],
  },
  {
    scamType: "impersonation",
    label: "money to a holding account",
    regexes: [/tài khoản (tạm giữ|tạm giam|của cơ quan)/i],
  },
  {
    scamType: "impersonation",
    label: "secrecy demand",
    regexes: [/không (được )?kể (chuyện này )?với ai/i, /giữ bí mật/i],
  },
  {
    scamType: "impersonation",
    label: "asks you to read back an OTP",
    regexes: [
      /otp.{0,40}gửi nhầm/i,
      /đọc (giúp|lại|cho) (mình|tôi|anh|chị|em).{0,30}(mã|số|otp)/i,
      /\d+ số vừa nhận/i,
    ],
  },

  // ---- investment: guaranteed returns, referral commissions -------------------
  {
    scamType: "investment",
    label: "unrealistic interest rate",
    regexes: [/(lãi|lợi nhuận)( cam kết)?.{0,10}\d+([.,]\d+)?\s*%\s*\/\s*(ngày|tuần|tháng)/i],
  },
  {
    scamType: "investment",
    label: "guaranteed profit, no risk",
    regexes: [/không rủi ro/i, /cam kết (lợi nhuận|lãi)|(lợi nhuận|lãi) cam kết/i, /hoàn vốn (nhanh|trong)/i],
  },
  {
    scamType: "investment",
    label: "referral commission",
    regexes: [/hoa hồng.{0,15}(mời|giới thiệu)/i, /(mời|giới thiệu).{0,30}hoa hồng/i],
  },
  {
    scamType: "investment",
    label: "crypto/forex group or expert",
    regexes: [
      /đầu tư (tiền ảo|tiền số|tiền điện tử|crypto|forex|ngoại hối)/i,
      /chuyên gia.{0,20}(dẫn dắt|tín hiệu)/i,
      /càng nạp (nhiều|càng)/i,
    ],
  },

  // ---- romance: gift from abroad held by "customs" ----------------------------
  {
    scamType: "romance",
    label: "customs or import fee",
    regexes: [/phí (hải quan|thông quan)/i, /thuế nhập khẩu/i],
  },
  {
    scamType: "romance",
    label: "gift or parcel from a contact",
    regexes: [/gửi quà/i, /gửi (cho )?(em|anh|chị|bạn) (một )?(hộp quà|kiện hàng|món quà|quà)/i, /quà.{0,40}(từ )?nước ngoài/i],
  },
  {
    scamType: "romance",
    label: "parcel held",
    regexes: [/(hải quan|sân bay).{0,10}(đang )?giữ/i],
  },
  {
    scamType: "romance",
    label: "foreign soldier/doctor/engineer persona",
    regexes: [/(quân nhân|bác sĩ|kỹ sư|doanh nhân).{0,30}(người (mỹ|anh|pháp|đức)|nước ngoài|giàn khoan|liên hợp quốc)/i, /việt kiều/i],
  },

  // ---- loan: fee before payout, no checks -------------------------------------
  {
    scamType: "loan",
    label: "fee before payout",
    regexes: [
      /phí bảo hiểm khoản vay/i,
      /trước khi giải ngân/i,
      /giải ngân.{0,30}trước/i,
      /phí (giải ngân|bảo lãnh|làm hồ sơ)/i,
      /chứng minh (năng lực )?tài chính/i,
    ],
  },
  {
    scamType: "loan",
    label: "no-check fast loan",
    regexes: [
      /vay (nhanh|ngay)?.{0,20}trong \d+ ?(phút|giờ)/i,
      /không cần thẩm định|không cần chứng minh thu nhập/i,
      /chỉ cần (cccd|cmnd|căn cước)/i,
    ],
  },
  {
    scamType: "loan",
    label: "frozen loan, pay to unlock",
    regexes: [/(khoản vay|hồ sơ vay).{0,40}(đóng băng|bị khóa)/i, /sai (số tài khoản|nội dung).{0,40}(khoản vay|giải ngân)/i],
  },
  {
    scamType: "loan",
    label: "contacts access",
    regexes: [/danh bạ/i],
  },

  // ---- other: fake parcel/shipper ---------------------------------------------
  {
    scamType: "other",
    label: "delivery fee request",
    regexes: [/phí (vận chuyển|giao lại|giao hàng|ship|lưu kho)/i],
  },
  {
    scamType: "other",
    label: "parcel held",
    regexes: [/giữ.{0,10}(kho|hải quan)/i, /hàng (đang )?bị giữ/i],
  },
  {
    scamType: "other",
    label: "failed delivery, update address",
    regexes: [/không thể giao.{0,30}(sai|thiếu|chưa đủ)/i, /cập nhật (lại )?địa chỉ/i],
  },
  {
    scamType: "other",
    label: "left at the usual spot, pay by transfer",
    regexes: [/(để|gửi)( hàng)?( ở)? chỗ (cũ|mọi lần)/i],
  },
];

export function preCheck(text: string): PatternMatch[] {
  if (typeof text !== "string" || !text.trim()) return [];

  // One entry per scamType, in the order the types first match.
  const byType = new Map<string, string[]>();
  for (const rule of PATTERN_RULES) {
    if (!rule.regexes.some((re) => re.test(text))) continue;
    const labels = byType.get(rule.scamType) ?? [];
    labels.push(rule.label);
    byType.set(rule.scamType, labels);
  }
  return [...byType].map(([scamType, matchedPatterns]) => ({ scamType, matchedPatterns }));
}
