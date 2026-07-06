/// Build-time configuration, injected with --dart-define. When the Supabase
/// values are absent the app falls back to the in-memory relay, so tests and
/// local runs need no backend.
class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
