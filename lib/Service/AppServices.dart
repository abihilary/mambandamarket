/// Legacy in-memory stubs used by the UI prototype.
///
/// The real implementations now live in `lib/api/`:
///   - favorites  → `FavoritesRepository` (api/repositories.dart)
///   - user/account → `AuthService` + `Me`/`Profile` (api/auth_service.dart)
///
/// Kept only as a signpost while the remaining screens are migrated; delete
/// once nothing imports it.
library;

export '../api/auth_service.dart';
export '../api/repositories.dart';
