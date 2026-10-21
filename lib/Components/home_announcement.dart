import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/notification_repository.dart';
import '../api/notification_router.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';

/// An announcement Mambanda floated on Home — news, a new service, the
/// newsletter. It is the person's inbox entry for that campaign: tapping opens
/// it (or where it links to), ✕ closes it, and either marks it read, so it
/// stays closed on every device and leaves the bell.
///
/// Nothing at all when there is no announcement, so Home looks as it always
/// did on an ordinary day.
class HomeAnnouncementCard extends StatelessWidget {
  const HomeAnnouncementCard({super.key});

  Future<void> _open(AppNotification n) async {
    final repo = NotificationRepository.instance;
    if (notificationHasTarget(n.data)) {
      repo.homeCard.value = null;
      await openNotificationTarget({...n.data, 'notification_id': n.id});
    } else {
      await repo.dismissHomeCard();
      await openNotificationDetail(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppNotification?>(
      valueListenable: NotificationRepository.instance.homeCard,
      builder: (context, n, _) {
        if (n == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final tokens = context.tokens;
        final image = n.imageUrl;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Material(
            color: scheme.surfaceContainerHigh,
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: tokens.accentFill.withValues(alpha: 0.55),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(n),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (image != null && image.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          image,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 64, height: 64),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ] else ...[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tokens.accentFill,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.campaign_outlined,
                          color: tokens.onAccentFill,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            n.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: context.l10n.homeAnnouncementClose,
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          NotificationRepository.instance.dismissHomeCard(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
