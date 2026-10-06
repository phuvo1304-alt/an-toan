// Tests for the analyze-scam image rules (supabase/functions/analyze-scam/images.ts).
// Run: npx deno test test/images_test.ts

import { assert, assertEquals } from "jsr:@std/assert@^1.0.0";
import {
  ALLOWED_IMAGE_TYPES,
  decodedSize,
  imageContentBlocks,
  MAX_IMAGE_BYTES,
  MAX_IMAGES,
  MAX_MULTI_IMAGE_BYTES,
  MAX_TOTAL_IMAGE_BYTES,
  parseImages,
} from "../supabase/functions/analyze-scam/images.ts";

/// A base64 string that decodes to exactly `bytes` bytes (bytes divisible by 3).
function b64OfSize(bytes: number, fill = "A"): string {
  assert(bytes % 3 === 0, "use a multiple of 3 so there is no padding");
  return fill.repeat((bytes / 3) * 4);
}
const img = (data: string, mime = "image/jpeg") => ({ image_base64: data, image_mime: mime });
const small = (tag: string) => img(b64OfSize(3000, tag));

Deno.test("limits are what the app was designed around", () => {
  assertEquals(MAX_IMAGES, 3);
  assertEquals(MAX_IMAGE_BYTES, 4 * 1024 * 1024);
  assert(MAX_MULTI_IMAGE_BYTES < MAX_IMAGE_BYTES);
  // Whole request stays far below the Supabase gateway (>= 30 MB measured)
  // and Anthropic's 32 MB request limit, even with base64 overhead.
  assertEquals(MAX_TOTAL_IMAGE_BYTES, 4 * 1024 * 1024);
  assert(Math.ceil(MAX_TOTAL_IMAGE_BYTES * 4 / 3) < 6 * 1024 * 1024);
  assertEquals(ALLOWED_IMAGE_TYPES, ["image/jpeg", "image/png", "image/webp"]);
});

Deno.test("decodedSize handles padding", () => {
  assertEquals(decodedSize("QUJD"), 3); // "ABC"
  assertEquals(decodedSize("QUI="), 2); // "AB"
  assertEquals(decodedSize("QQ=="), 1); // "A"
});

// ---- Valid requests ---------------------------------------------------------
for (const n of [1, 2, 3]) {
  Deno.test(`valid request with ${n} image(s) keeps the order`, () => {
    const tags = ["B", "C", "D"].slice(0, n);
    const r = parseImages({ images: tags.map(small) });
    assert(r.ok);
    assertEquals(r.images.length, n);
    assertEquals(r.images.map((i) => i.data[0]), tags);
  });
}

Deno.test("no image fields at all (Text/Voice tabs) -> zero images, no error", () => {
  const r = parseImages({ text: "hello", language: "vi" });
  assertEquals(r, { ok: true, images: [] });
});

Deno.test("old single-image fields still work as one image", () => {
  const r = parseImages({ image_base64: b64OfSize(3000), image_mime: "image/png" });
  assert(r.ok);
  assertEquals(r.images, [{ data: b64OfSize(3000), mime: "image/png" }]);
});

// ---- Rejections ---------------------------------------------------------------
Deno.test("4 images -> too_many_images (400)", () => {
  const r = parseImages({ images: ["B", "C", "D", "E"].map(small) });
  assertEquals(r, { ok: false, error: "too_many_images", status: 400 } as const);
});

Deno.test("oversized single image -> image_too_large (413)", () => {
  const ok = parseImages({ images: [img(b64OfSize(MAX_IMAGE_BYTES - (MAX_IMAGE_BYTES % 3)))] });
  assert(ok.ok, "just under the single-image cap is fine");
  const r = parseImages({ images: [img(b64OfSize(MAX_IMAGE_BYTES + 3 - (MAX_IMAGE_BYTES % 3)))] });
  assertEquals(r, { ok: false, error: "image_too_large", status: 413 } as const);
});

Deno.test("in a multi-image request each image has the smaller cap", () => {
  const big = b64OfSize(Math.floor(MAX_MULTI_IMAGE_BYTES / 3) * 3 + 3); // just over 1.5 MB
  const r = parseImages({ images: [small("B"), img(big)] });
  assertEquals(r, { ok: false, error: "image_too_large", status: 413 } as const);
  // The same image alone is allowed (single-image cap is 4 MB).
  assert(parseImages({ images: [img(big)] }).ok);
});

Deno.test("combined size: 3 individually valid images can still be refused", () => {
  const MB = 1024 * 1024;
  const sized = (mb: number) => img(b64OfSize(Math.floor((mb * MB) / 3) * 3));
  // The check must be reachable: 3 x the per-image cap is above the total cap.
  assert(3 * MAX_MULTI_IMAGE_BYTES > MAX_TOTAL_IMAGE_BYTES);
  // 3 x 1.4 MB: each passes the 1.5 MB per-image cap, together 4.2 MB > 4 MB.
  for (const one of [sized(1.4)]) assert(decodedSize(one.image_base64) <= MAX_MULTI_IMAGE_BYTES);
  const over = parseImages({ images: [sized(1.4), sized(1.4), sized(1.4)] });
  assertEquals(over, { ok: false, error: "image_too_large", status: 413 } as const);
  // 3 x 1.3 MB = 3.9 MB: allowed.
  const under = parseImages({ images: [sized(1.3), sized(1.3), sized(1.3)] });
  assert(under.ok);
  // 2 images can never reach it (2 x 1.5 MB = 3 MB < 4 MB).
  assert(parseImages({ images: [sized(1.49), sized(1.49)] }).ok);
});

Deno.test("disallowed mime type -> bad_image_type (415)", () => {
  for (const mime of ["image/heic", "image/gif", "application/pdf", ""]) {
    const r = parseImages({ images: [small("B"), img(b64OfSize(3000), mime)] });
    assertEquals(r, { ok: false, error: "bad_image_type", status: 415 } as const, mime);
  }
});

Deno.test("malformed input -> bad_request (400)", () => {
  const bad = { ok: false, error: "bad_request", status: 400 } as const;
  assertEquals(parseImages({ images: "not-an-array" }), bad);
  assertEquals(parseImages({ images: [img("not base64!!")] }), bad);
  assertEquals(parseImages({ images: [img("")] }), bad);
  assertEquals(parseImages({ images: [null] }), bad);
  // Both the old and the new form at once is ambiguous.
  assertEquals(parseImages({ images: [small("B")], image_base64: b64OfSize(3000), image_mime: "image/jpeg" }), bad);
});

// ---- Content blocks -----------------------------------------------------------
Deno.test("1 image: exactly the same two blocks as before the change", () => {
  const blocks = imageContentBlocks([{ data: "QUJD", mime: "image/png" }]);
  assertEquals(blocks, [
    { type: "text", text: "The following image is the USER CONTENT (untrusted). Read any text in it and analyze it." },
    { type: "image", source: { type: "base64", media_type: "image/png", data: "QUJD" } },
  ]);
});

Deno.test("3 images: framing note, then labelled images in the given order", () => {
  const images = [
    { data: "Rk9P", mime: "image/jpeg" },
    { data: "QkFS", mime: "image/png" },
    { data: "QkFa", mime: "image/webp" },
  ];
  const blocks = imageContentBlocks(images);
  assertEquals(blocks.length, 1 + 2 * 3);
  assertEquals(blocks[0].type, "text");
  assert(blocks[0].text.includes("3 images are the USER CONTENT (untrusted)"));
  assert(blocks[0].text.includes("ONE conversation"));
  assert(blocks[0].text.includes("Image 1 comes first"));
  assertEquals(blocks.slice(1).map((b) => b.type === "text" ? b.text : b.source.data),
    ["Image 1:", "Rk9P", "Image 2:", "QkFS", "Image 3:", "QkFa"]);
  assertEquals(blocks[4].source.media_type, "image/png");
});

Deno.test("0 images: no blocks", () => {
  assertEquals(imageContentBlocks([]), []);
});
