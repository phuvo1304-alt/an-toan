import 'package:vietqr_gen/vietqr_generator.dart' show Bank;

/// Public app config. These two values are SAFE to be in the app
/// (the anon key is designed to be public; security comes from the server).
/// They are passed at run time:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// NEVER put the Gemini key here.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Address of the Edge Function that talks to Gemini.
  static String get analyzeScamUrl => '$supabaseUrl/functions/v1/analyze-scam';
}

// ---------------------------------------------------------------------------
// Settings' "Support this project" donation card (personal/family bank
// transfer via a locally-generated VietQR code -- see
// lib/features/settings/settings_screen.dart). PLACEHOLDERS: fill in the
// real account number and the name actually printed on that account before
// release (which may not be the app author's own name -- Vietnamese bank
// accounts are often held under a parent's name). Do NOT invent digits or a
// name that look real. While kDonationAccountNumber is still
// "REPLACE_ME", the whole section hides itself rather than rendering a
// broken/fake-looking QR.
// ---------------------------------------------------------------------------

const kDonationBankCode = Bank.acb;
const kDonationAccountNumber = 'REPLACE_ME';
const kDonationAccountHolderName = 'REPLACE_ME';
