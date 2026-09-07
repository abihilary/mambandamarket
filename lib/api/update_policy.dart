/// What the app should do about updates, as a pure function of the facts.
///
/// No Flutter, no I/O, no singletons — so it can be unit-tested against every
/// combination the gate has to get right, and the widget that uses it stays a
/// thin layer over a decision made here.
enum UpdateDecision {
  /// Nothing to say.
  none,

  /// A newer build exists on the store. Suggest it; never insist.
  nudge,

  /// This build is below the supported floor and has been given notice.
  warn,

  /// Below the floor and past the deadline. The app stops here.
  blocked,
}

/// How long "Later" keeps a nudge quiet for the same build.
const Duration snoozeFor = Duration(days: 3);

UpdateDecision decideUpdate({
  required int? build,
  required String mode, // off | notify | block, already sanitised
  required int latestBuild,
  required int minSupportedBuild,
  required DateTime? blocksAt,
  required DateTime serverNow,
  required int? snoozedBuild,
  required DateTime? snoozedAt,
  required DateTime now,
}) {
  if (build == null || mode == 'off') return UpdateDecision.none;

  // The floor first: being unsupported outranks there merely being something
  // newer.
  if (minSupportedBuild > 0 && build < minSupportedBuild) {
    if (mode == 'notify' || blocksAt == null) return UpdateDecision.warn;
    return serverNow.isBefore(blocksAt) ? UpdateDecision.warn : UpdateDecision.blocked;
  }

  if (latestBuild <= build) return UpdateDecision.none;

  // A snooze belongs to one build. A newer release clears it on its own, so a
  // "Later" three weeks ago says nothing about the build that shipped today.
  final snoozed = snoozedBuild == latestBuild &&
      snoozedAt != null &&
      now.difference(snoozedAt) < snoozeFor;
  return snoozed ? UpdateDecision.none : UpdateDecision.nudge;
}
