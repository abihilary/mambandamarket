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

  /// Public base for images stored in Supabase Storage buckets.
  static String storagePublicUrl(String bucket, String path) =>
      '$supabaseUrl/storage/v1/object/public/$bucket/$path';
}
