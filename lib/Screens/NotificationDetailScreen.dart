import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../api/notification_router.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';

/// One notification, in full: the picture, every line of the text, when it
/// came, and — when it points somewhere — one button that goes there.
///
/// The shade shows a line and a half; the inbox three. A note from the desk
/// or an announcement with a paragraph in it needs somewhere to be read.
class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final AppNotification notification;

  String _kindLabel(AppLocalizations l10n, String kind) {
    switch (kind) {
      case 'shipping':
        return l10n.notificationChannelShipping;
      case 'order':
        return l10n.notificationChannelOrders;
      case 'listing':
        return l10n.notifKindListing;
      case 'direct':
      case 'desk':
        return l10n.notifKindFromMambanda;
      case 'announcement':
        return l10n.notificationChannelAnnouncements;
      default:
        return l10n.notifKindUpdate;
    }
  }

  String? _actionLabel(AppLocalizations l10n, Map<String, String> data) {
    if (!notificationHasTarget(data)) return null;
    switch (data['type']) {
      case 'message':
        return l10n.notifActionChat;
      case 'shipping':
        return l10n.notifActionTrack;
      case 'order':
        return l10n.notifActionOrder;
      case 'listing':
        return l10n.notifActionListing;
      case 'url':
        return l10n.notifActionLink;
      default:
        return l10n.notifActionOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final n = notification;
    final locale = LocaleController.instance.locale.value?.languageCode ?? Localizations.localeOf(context).languageCode;
    final when = DateFormat.yMMMd(locale).add_Hm().format(n.createdAt.toLocal());
    final action = _actionLabel(l10n, n.data);
    final image = (n.imageUrl ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: Text(_kindLabel(l10n, n.kind))),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (image.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: scheme.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    when,
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, letterSpacing: 0.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.title,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 14),
                  SelectableText(
                    n.body,
                    style: TextStyle(fontSize: 15.5, height: 1.5, color: scheme.onSurface),
                  ),
                  if ((n.data['reference'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tag, size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(n.data['reference']!, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accentFill,
                      foregroundColor: tokens.onAccentFill,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => openNotificationTarget({...n.data, 'notification_id': n.id}),
                    child: Text(action),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
