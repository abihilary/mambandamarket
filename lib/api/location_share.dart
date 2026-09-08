/// Somebody's position, shared into a conversation.
///
/// Two shapes behind one class. A pin is a single fixed point. A live share is
/// the same row moved as the person moves, until they stop it or it runs out —
/// and it always runs out, because a location still broadcasting because
/// somebody forgot is how this feature goes wrong.
class LocationShare {
  const LocationShare({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.isLive,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.startedAt,
    this.updatedAt,
    this.expiresAt,
    this.stoppedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final bool isLive;
  final double lat;
  final double lng;
  final double? accuracyM;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final DateTime? stoppedAt;

  /// Still moving. A share is running only while it is live, un-stopped and
  /// inside its window — all three, because each one ends it on its own.
  bool get isRunning {
    if (!isLive || stoppedAt != null) return false;
    final ends = expiresAt;
    return ends != null && ends.isAfter(DateTime.now());
  }

  /// Ran out on its own rather than being stopped. Worth telling apart: "they
  /// stopped sharing" and "it expired" read very differently.
  bool get hasExpired =>
      isLive && stoppedAt == null && (expiresAt?.isBefore(DateTime.now()) ?? false);

  /// What a map app needs. `geo:` is understood by every Android map app and
  /// the `q=` label is what makes the pin show rather than just re-centring.
  Uri get mapUri => Uri.parse('geo:$lat,$lng?q=$lat,$lng');

  /// The fallback for a device with no app registered for `geo:`.
  Uri get webMapUri =>
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

  static double? _double(Object? v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  static LocationShare? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString();
    final lat = _double(json['lat']);
    final lng = _double(json['lng']);
    // A share without a position is not a share. Dropping it costs one bubble;
    // rendering it would put a pin on Null Island.
    if (id == null || id.isEmpty || lat == null || lng == null) return null;
    return LocationShare(
      id: id,
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      isLive: json['mode']?.toString() == 'live',
      lat: lat,
      lng: lng,
      accuracyM: _double(json['accuracy_m']),
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      stoppedAt: DateTime.tryParse(json['stopped_at']?.toString() ?? ''),
    );
  }

  LocationShare copyWith({
    double? lat,
    double? lng,
    double? accuracyM,
    DateTime? updatedAt,
    DateTime? stoppedAt,
  }) =>
      LocationShare(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        isLive: isLive,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        accuracyM: accuracyM ?? this.accuracyM,
        startedAt: startedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        expiresAt: expiresAt,
        stoppedAt: stoppedAt ?? this.stoppedAt,
      );
}
