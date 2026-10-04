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
