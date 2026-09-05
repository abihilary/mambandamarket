/// Backend configuration.
///
/// Both values below are safe to ship in the client: the Supabase publishable
/// key only grants what Row-Level Security allows, and the API enforces
/// ownership server-side. No secret key ever belongs in the app.
///
/// Override per environment without editing code:
///   flutter run --dart-define=API_BASE_URL=http://localhost:8787
class AppConfig {
  const AppConfig._();

  /// MambandaMarket Core API.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mambanda-api.blacksilvergroups.xyz',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vnmmqujmeoamuksgdoqd.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ImOqFcjPQ4I7uwlf5UHeOA_ykbjOkgz',
  );

  /// OAuth **Web** client ID from Google Cloud, used as `serverClientId`.
  ///
  /// Not a secret — it is the public half, and Google's own samples ship it in
  /// the client. The secret that pairs with it lives only in Supabase.
  ///
  /// It is the *web* client on purpose, not the Android one: the Android client
  /// is matched by package name and signing certificate and issues nothing you
  /// can hand to a server, while `serverClientId` is what makes Google mint an
  /// ID token audienced to the backend — which is exactly what Supabase
  /// verifies.
  ///
  /// Empty means "not configured yet", and sign-in falls back to the hosted
  /// browser flow. That fallback is deliberate: an unconfigured native flow
  /// fails at the account picker with nothing to say, and this is the app's
  /// only social sign-in.
  /// Not a secret: it ships inside every copy of the app, and Google treats
  /// it as public. The secret that pairs with it never leaves Supabase.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '649457496601-fu6aolhjuc4urbap4o5a5j0hqs6ivfmk.apps.googleusercontent.com',
  );

  static bool get hasNativeGoogleSignIn => googleWebClientId.isNotEmpty;

  /// Public base for images stored in Supabase Storage buckets.
  static String storagePublicUrl(String bucket, String path) =>
      '$supabaseUrl/storage/v1/object/public/$bucket/$path';
}
