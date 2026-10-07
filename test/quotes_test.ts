// Tests for the red-flag quote check (supabase/functions/analyze-scam/quotes.ts).
// Run: npx deno test test/quotes_test.ts

import { assert, assertEquals } from "jsr:@std/assert@^1.0.0";
import { keepVerifiedFlags, normalizeForMatch, quoteFoundIn } from "../supabase/functions/analyze-scam/quotes.ts";

const msg =
  "Chào bạn, bên mình tuyển cộng tác viên làm online. Nhiệm vụ đầu tiên nhận ngay 50.000đ để làm quen. " +
  "Từ nhiệm vụ thứ hai, bạn tự thanh toán trước tiền đơn hàng, hệ thống sẽ hoàn lại cả gốc và 20% hoa hồng.";

Deno.test("exact snippet is found", () => {
  assert(quoteFoundIn("Nhiệm vụ đầu tiên nhận ngay 50.000đ để làm quen.", msg));
});

Deno.test("tolerates added quote marks, end punctuation, case and spacing", () => {
  assert(quoteFoundIn('"nhiệm vụ đầu tiên   nhận ngay 50.000đ"', msg));
  assert(quoteFoundIn("“Chào bạn, bên mình tuyển cộng tác viên làm online”.", msg));
});

Deno.test("accents are NOT ignored: a misread quote is rejected", () => {
  assert(quoteFoundIn("hoàn lại cả gốc", msg));
  assertEquals(quoteFoundIn("hoàn lại cả góc", msg), false); // gốc -> góc misread
  assertEquals(quoteFoundIn("tuyên cộng tác viên", msg), false); // tuyển -> tuyên
});

Deno.test("invented or paraphrased quotes are rejected", () => {
  assertEquals(quoteFoundIn("Bạn phải nạp 50.000đ để làm quen", msg), false);
  assertEquals(quoteFoundIn("chuyển tiền vào tài khoản cá nhân", msg), false);
});

Deno.test("two lines joined with '...' or '…': each part must appear, in order", () => {
  assert(quoteFoundIn("Chào bạn ... hoàn lại cả gốc", msg));
  assert(quoteFoundIn("Nhiệm vụ đầu tiên nhận ngay 50.000đ… 20% hoa hồng", msg));
  assertEquals(quoteFoundIn("20% hoa hồng ... Chào bạn", msg), false); // wrong order
  assertEquals(quoteFoundIn("Chào bạn ... nạp 2 triệu", msg), false); // one part invented
});

Deno.test("an empty quote claims nothing and is kept", () => {
  assert(quoteFoundIn("", msg));
  assert(quoteFoundIn('""', msg));
});

Deno.test("Unicode composed vs decomposed accents match", () => {
  const decomposed = "gốc".normalize("NFD");
  assert(quoteFoundIn(`hoàn lại cả ${decomposed}`, msg));
  assertEquals(normalizeForMatch("Á"), "á");
});

Deno.test("keepVerifiedFlags drops only the unverifiable flags and counts them", () => {
  const flags = [
    { title: "Trả trước để tạo lòng tin", explanation: "x", quote: "Nhiệm vụ đầu tiên nhận ngay 50.000đ để làm quen." },
    { title: "Bị bắt ứng tiền", explanation: "x", quote: "bạn tự thanh toán trước tiền đơn hàng" },
    { title: "Bịa", explanation: "x", quote: "nạp 1.900.000đ để lên VIP" },
    { title: "Không trích", explanation: "x", quote: "" },
  ];
  const { kept, dropped } = keepVerifiedFlags(flags, msg);
  assertEquals(dropped, 1);
  assertEquals(kept.map((f) => f.title), ["Trả trước để tạo lòng tin", "Bị bắt ứng tiền", "Không trích"]);
});
