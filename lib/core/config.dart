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
// lib/features/settings/settings_screen.dart). While kDonationAccountNumber
// is still "REPLACE_ME", the whole section hides itself rather than
// rendering a broken/fake-looking QR.
//
// kDonationAccountHolderName is display text only in our own UI -- it is
// NEVER passed to vietqr_gen's VietQR.generate() (which has no account-
// holder-name parameter at all) and is never encoded in the QR payload
// itself. It's written unaccented/uppercase to match how Vietnamese banks
// themselves display a VietQR account holder's name, not because the
// library requires any particular format.
// ---------------------------------------------------------------------------

const kDonationBankCode = Bank.acb;
const kDonationAccountNumber = '41087687';
const kDonationAccountHolderName = 'VO NGUYEN TRONG PHU';

/// Whether the donation account info looks real, not the "REPLACE_ME"
/// placeholder -- pure and parameterized (not a getter over the constants
/// above) specifically so BOTH states stay independently testable
/// regardless of what the real constants currently hold. Settings calls
/// this with the real kDonation* constants to decide whether to show the
/// section at all.
bool isDonationInfoConfigured(String accountNumber, String accountHolderName) =>
    accountNumber != 'REPLACE_ME' && accountHolderName != 'REPLACE_ME';
