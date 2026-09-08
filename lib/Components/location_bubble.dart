import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/auth_service.dart';
import '../api/live_location.dart';
import '../api/location_share.dart';
import '../l10n/l10n.dart';

/// A shared location, inside a chat bubble.
///
/// There is no map here, and that is deliberate: this app carries no map SDK,
/// and adding one to draw a thumbnail nobody can pan would cost more than it
/// returns. What a person actually does with a shared location is open it in
/// the map app they already use, so the card is built around that one action.
class LocationBubble extends StatefulWidget {
  const LocationBubble({super.key, required this.share, required this.mine});

  final LocationShare share;

  /// Whether the viewer is the one sharing. Only they can stop it.
  final bool mine;

  @override
  State<LocationBubble> createState() => _LocationBubbleState();
}

class _LocationBubbleState extends State<LocationBubble> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    // The controller's copy is the moving one; the message's copy is whatever
    // the last fetch happened to say. Prefer the live one when it is this share.
    return ValueListenableBuilder<LocationShare?>(
      valueListenable: LiveLocation.instance.active,
      builder: (context, live, _) {
        final share = (live != null && live.id == widget.share.id) ? live : widget.share;
        final running = share.isRunning;
        final mine = widget.mine ||
            share.senderId == (AuthService.instance.userId ?? '');

        return Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    running ? Icons.my_location : Icons.location_on_outlined,
                    size: 18,
                    color: running ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _headline(l10n, share),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _detail(l10n, share),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openMap(share),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: Text(l10n.locOpenInMaps, style: const TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 34),
                      ),
                    ),
                  ),
                  if (running && mine) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        LiveLocation.instance.stop();
                        setState(() {});
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 34),
                      ),
                      child: Text(l10n.locStop, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _headline(AppLocalizations l10n, LocationShare share) {
    if (!share.isLive) return l10n.locPinTitle;
    if (share.isRunning) return l10n.locLiveTitle;
    if (share.hasExpired) return l10n.locLiveEnded;
    return l10n.locLiveStopped;
  }

  String _detail(AppLocalizations l10n, LocationShare share) {
    if (share.isRunning) {
      final ends = share.expiresAt;
      final updated = share.updatedAt;
      return [
        if (ends != null) l10n.locUntil(_clock(ends.toLocal())),
        if (updated != null) l10n.locUpdated(_clock(updated.toLocal())),
      ].join(' · ');
    }
    final at = share.updatedAt ?? share.startedAt;
    return at == null ? '' : _clock(at.toLocal());
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _openMap(LocationShare share) async {
    // geo: first — it opens whichever map app the phone actually uses. The web
    // URL is the fallback for a device with nothing registered for it.
    if (await launchUrl(share.mapUri, mode: LaunchMode.externalApplication)) return;
    await launchUrl(share.webMapUri, mode: LaunchMode.externalApplication);
  }
}
