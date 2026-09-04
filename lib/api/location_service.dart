import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Why a position could not be produced.
///
/// Every one of these is an ordinary state, not an error: a phone with location
/// switched off is a phone being used normally. Nothing in the app is allowed
/// to fail because of one — the feed renders identically without a position,
/// and publishing is never blocked.
enum LocationOutcome {
  ok,

  /// The user said no this time. Asking again later is legitimate.
  denied,

  /// The user said no permanently. Only Settings can undo it, so the app must
  /// stop asking and say where to go instead.
  deniedForever,

  /// Location is off for the whole device.
  servicesOff,

  /// The platform accepted the request and produced nothing — no fix, timeout.
  unavailable,
}

/// A coordinate, rounded to the precision we are willing to store.
@immutable
class Coordinate {
  final double lat;
  final double lng;

  /// When it was captured. A position from last month is still worth showing a
  /// distance from — a city does not move — but it is worth knowing.
  final DateTime at;

  const Coordinate({required this.lat, required this.lng, required this.at});

  /// Three decimals is about 110 m. Rounding here as well as on the server is
  /// deliberate: `app.use('*', logger())` puts the query string in Vercel's
  /// logs, so an unrounded `?near=` would write a precise home address into a
  /// log line no amount of server-side rounding could take back.
  Coordinate get rounded => Coordinate(
        lat: (lat * 1000).roundToDouble() / 1000,
        lng: (lng * 1000).roundToDouble() / 1000,
        at: at,
      );
}

/// Where the user is, approximately, and only if they have said we may know.
///
/// Follows the house pattern (RemoteConfig, BoardRepository): private
/// constructor, one static instance, a ValueNotifier, a SharedPreferences
/// cache, and no method that throws.
///
/// **Coarse only, foreground only.** A precise point on a private seller's
/// listing is their doorstep, and three distance readings from different places
/// trilaterate it. Coarse also keeps the app out of Play's background-location
/// review entirely, which is a review nothing here would survive being worth.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _kLat = 'loc_lat';
  static const _kLng = 'loc_lng';
  static const _kAt = 'loc_at';

  /// The last known position, or null. Readable **synchronously** — that is the
  /// point of it. The feed must never await a platform call to build a request:
  /// a user who has denied permission would otherwise wait on a plugin round
  /// trip before every load, to arrive at the same query they get today.
  final ValueNotifier<Coordinate?> position = ValueNotifier(null);

  Coordinate? get cached => position.value;

  bool _loaded = false;

  /// Read the cache. Called once at startup; safe to call again.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_kLat);
      final lng = prefs.getDouble(_kLng);
      if (lat == null || lng == null) return;
      final at = DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt(_kAt) ?? 0,
        isUtc: true,
      );
      position.value = Coordinate(lat: lat, lng: lng, at: at);
    } catch (_) {
      // A device that cannot read its own preferences still gets a working app,
      // just without a remembered position.
    }
  }

  /// Ask the platform where we are.
  ///
  /// Prompts for permission when it has not been answered yet, so only call
  /// this from something the user pressed. Returns the outcome so the caller
  /// can say something useful; the position itself lands in [position].
  Future<LocationOutcome> refresh() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationOutcome.servicesOff;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationOutcome.deniedForever;
      }
      if (permission == LocationPermission.denied) {
        return LocationOutcome.denied;
      }

      // LocationAccuracy.low is the coarse tier — city-block scale. Asking for
      // `high` here would work and would also be a lie: the manifest declares
      // COARSE only, and the value is rounded to ~110 m before it is stored.
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final coord = Coordinate(
        lat: p.latitude,
        lng: p.longitude,
        at: DateTime.now().toUtc(),
      ).rounded;
      position.value = coord;
      await _write(coord);
      return LocationOutcome.ok;
    } catch (e) {
      // Timeouts, a platform that has no location at all, a permission race —
      // all the same answer to a caller: we do not know where you are.
      debugPrint('[location] refresh failed: $e');
      return LocationOutcome.unavailable;
    }
  }

  /// Forget the position. Nothing calls this yet; it exists so that "stop using
  /// my location" has somewhere to go the moment there is a switch for it.
  Future<void> forget() async {
    position.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLat);
      await prefs.remove(_kLng);
      await prefs.remove(_kAt);
    } catch (_) {}
  }

  Future<void> _write(Coordinate c) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kLat, c.lat);
      await prefs.setDouble(_kLng, c.lng);
      await prefs.setInt(_kAt, c.at.millisecondsSinceEpoch);
    } catch (_) {}
  }
}
