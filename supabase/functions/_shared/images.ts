// An Toàn - analyze-scam: image input rules (pure functions, no network).
// Kept separate from index.ts so they can be unit-tested with `deno test`
// (index.ts starts the server when imported).

/// At most this many screenshots per check (cost control: this app is free).
export const MAX_IMAGES = 3;

/// Per image, decoded size. Same as before for a single image.
export const MAX_IMAGE_BYTES = 4 * 1024 * 1024;

/// Per image when 2-3 images are sent. The app sends these at <= 1024 px on
/// the long side (JPEG q80, typically 100-300 KB), so 1.5 MB is generous.
export const MAX_MULTI_IMAGE_BYTES = 1.5 * 1024 * 1024;

/// All images together, decoded. Deliberately LOWER than 3 x the multi-image
/// cap (3 x 1.5 = 4.5 MB), otherwise this check could never trigger: three
/// individually valid images (e.g. 3 x 1.4 MB = 4.2 MB) can still be refused
/// here. Base64 adds a third, so the JSON body stays under ~5.4 MB: far below
/// both the Supabase gateway (measured: accepts at least 30 MB) and Anthropic's
/// 32 MB request limit / 10 MB per-image limit.
export const MAX_TOTAL_IMAGE_BYTES = 4 * 1024 * 1024;

export const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];

export interface ImageInput {
  data: string; // base64, no data: prefix
  mime: string;
}

export type ImageParseResult =
  | { ok: true; images: ImageInput[] }
  | { ok: false; error: string; status: number };

/// Decoded byte size of a base64 string (ignores padding).
export function decodedSize(b64: string): number {
  const padding = b64.endsWith("==") ? 2 : b64.endsWith("=") ? 1 : 0;
  return Math.floor((b64.length * 3) / 4) - padding;
}

const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

/// Reads the images from a request body and checks every rule.
///
/// Accepts the new `images: [{ image_base64, image_mime }, ...]` field. The old
/// single `image_base64` / `image_mime` fields are still accepted as one image,
/// so the app keeps working in the gap between deploying this function and
/// shipping the new app. Sending both forms at once is rejected.
export function parseImages(body: unknown): ImageParseResult {
  const b = (body ?? {}) as Record<string, unknown>;
  const hasArray = b.images !== undefined && b.images !== null;
  const hasLegacy = typeof b.image_base64 === "string" && b.image_base64 !== "";

  if (hasArray && hasLegacy) return { ok: false, error: "bad_request", status: 400 };

  let raw: unknown[];
  if (hasArray) {
    if (!Array.isArray(b.images)) return { ok: false, error: "bad_request", status: 400 };
    raw = b.images;
  } else if (hasLegacy) {
    raw = [{ image_base64: b.image_base64, image_mime: b.image_mime }];
  } else {
    return { ok: true, images: [] };
  }

  if (raw.length > MAX_IMAGES) return { ok: false, error: "too_many_images", status: 400 };

  const perImageCap = raw.length > 1 ? MAX_MULTI_IMAGE_BYTES : MAX_IMAGE_BYTES;
  const images: ImageInput[] = [];
  let total = 0;
  for (const item of raw) {
    const it = (item ?? {}) as Record<string, unknown>;
    const data = typeof it.image_base64 === "string" ? it.image_base64 : "";
    const mime = typeof it.image_mime === "string" ? it.image_mime : "";
    if (!data || !BASE64.test(data)) return { ok: false, error: "bad_request", status: 400 };
    if (!ALLOWED_IMAGE_TYPES.includes(mime)) return { ok: false, error: "bad_image_type", status: 415 };
    const size = decodedSize(data);
    if (size > perImageCap) return { ok: false, error: "image_too_large", status: 413 };
    total += size;
    images.push({ data, mime });
  }
  if (total > MAX_TOTAL_IMAGE_BYTES) return { ok: false, error: "image_too_large", status: 413 };

  return { ok: true, images };
}

// deno-lint-ignore no-explicit-any
type ContentBlock = Record<string, any>;

/// The content blocks for the images, in the order given.
///
/// One image: exactly the same blocks as before this change.
/// Several: a framing note that they are consecutive parts of ONE conversation
/// in order, then "Image 1:", image, "Image 2:", image... (labels as
/// recommended in Anthropic's vision docs, so the model can refer to them).
export function imageContentBlocks(images: ImageInput[]): ContentBlock[] {
  const imageBlock = (img: ImageInput): ContentBlock => ({
    type: "image",
    source: { type: "base64", media_type: img.mime, data: img.data },
  });

  if (images.length === 0) return [];
  if (images.length === 1) {
    return [
      { type: "text", text: "The following image is the USER CONTENT (untrusted). Read any text in it and analyze it." },
      imageBlock(images[0]),
    ];
  }

  const blocks: ContentBlock[] = [{
    type: "text",
    text: `The following ${images.length} images are the USER CONTENT (untrusted). ` +
      "They are most likely consecutive screenshots of ONE conversation or message thread, " +
      "given in order: Image 1 comes first. Read the text in all of them and analyze them " +
      "together as one conversation, not as unrelated messages.",
  }];
  images.forEach((img, i) => {
    blocks.push({ type: "text", text: `Image ${i + 1}:` });
    blocks.push(imageBlock(img));
  });
  return blocks;
}
