import 'dart:async';

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/notification_repository.dart';
import '../api/notification_router.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';

/// The inbox: everything the platform has said to this person that was not a
/// chat message. A tap goes where the notification's push would have gone.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationRepository.instance;
  final _scroll = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    unawaited(_load());
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _repo.refresh();
      if (mounted) setState(() { _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e; });
    }
  }

  void _maybeLoadMore() {
    if (_loadingMore || !_repo.canLoadMore) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 240) return;
    _loadingMore = true;
    unawaited(_repo.loadMore().whenComplete(() {
      if (mounted) setState(() => _loadingMore = false);
    }));
  }

  Future<void> _open(AppNotification n) async {
    if (n.isUnread) unawaited(_repo.markRead([n.id]));
    await openNotificationTarget({...n.data, 'notification_id': n.id});
  }

  String _ago(BuildContext context, DateTime when) {
    final l10n = context.l10n;
    final d = DateTime.now().difference(when);
    if (d.inMinutes < 1) return l10n.shipJustNow;
    if (d.inHours < 1) return l10n.shipMinutesAgo(d.inMinutes);
    if (d.inDays < 1) return l10n.shipHoursAgo(d.inHours);
    return l10n.shipDaysAgo(d.inDays);
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'shipping':
        return Icons.local_shipping_outlined;
      case 'order':
        return Icons.receipt_long_outlined;
      case 'listing':
        return Icons.sell_outlined;
      case 'direct':
      case 'desk':
        return Icons.support_agent_outlined;
      case 'announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _repo.unread,
            builder: (context, unread, _) => TextButton(
              onPressed: unread == 0 ? null : () => unawaited(_repo.markAllRead()),
              child: Text(l10n.notificationsMarkAllRead),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ValueListenableBuilder<List<AppNotification>>(
            valueListenable: _repo.items,
            builder: (context, items, _) {
              if (_loading && items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_error != null && items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Icon(Icons.cloud_off_outlined, size: 40, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Center(child: Text(l10n.notificationsOpenError, style: TextStyle(color: scheme.onSurfaceVariant))),
                    const SizedBox(height: 12),
                    Center(child: TextButton(onPressed: _load, child: Text(l10n.retry))),
                  ],
                );
              }
              if (items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Icon(Icons.notifications_none_outlined, size: 48, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          l10n.notificationsEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: items.length + (_repo.canLoadMore ? 1 : 0),
                separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                itemBuilder: (context, i) {
                  if (i >= items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                    );
                  }
                  final n = items[i];
                  return _NotificationTile(
                    notification: n,
                    icon: _iconFor(n.kind),
                    ago: _ago(context, n.createdAt),
                    onTap: () => _open(n),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.ago,
    required this.onTap,
  });

  final AppNotification notification;
  final IconData icon;
  final String ago;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final n = notification;
    final unread = n.isUnread;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? tokens.accentFill.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: unread ? tokens.accentFill : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: unread ? tokens.onAccentFill : scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(ago, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, height: 1.35, color: scheme.onSurfaceVariant),
                  ),
                  if (n.imageUrl != null && n.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        n.imageUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: tokens.accentInk, shape: BoxShape.circle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
