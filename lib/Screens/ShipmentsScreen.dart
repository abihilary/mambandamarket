import 'package:flutter/material.dart';

import '../Service/ChatRoomScreen.dart';
import '../api/repositories.dart';
import '../api/shipping_model.dart';
import '../api/shipping_repository.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import 'ShippingRequestScreen.dart';

/// Everything somebody has asked us to ship, and where each of it has got to.
///
/// Live: the repository subscribes to the caller's own request rows, and a
/// checkpoint written anywhere — the dashboard today, a driver's phone later —
/// touches that row, so this list moves without anybody pulling it.
class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final _repo = ShippingRepository.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo.startLive();
    _load();
  }

  Future<void> _load() async {
    await _repo.refreshMine();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _newRequest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShippingRequestScreen()),
    );
    await _repo.refreshMine();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        // Deliberately larger than the house app-bar title. This screen is
        // reached from a floating button rather than the tab bar, so it has to
        // say what it is the moment it lands — the default weight read as
        // chrome and people did not register they had arrived somewhere.
        titleSpacing: 20,
        toolbarHeight: 72,
        title: Text(
          l10n.shipMyShipments,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: ValueListenableBuilder<List<ShippingRequest>>(
        valueListenable: _repo.shipments,
        builder: (context, items, _) {
          if (_loading && items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) return _empty(context);
          return RefreshIndicator(
            onRefresh: _repo.refreshMine,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ShipmentCard(
                shipment: items[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ShipmentDetailScreen(id: items[i].id)),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRequest,
        backgroundColor: context.tokens.accentFill,
        foregroundColor: context.tokens.onAccentFill,
        icon: const Icon(Icons.add),
        label: Text(l10n.shipNewRequest),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(l10n.shipNoneYet,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l10n.shipNoneYetBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.shipment, required this.onTap});

  final ShippingRequest shipment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final lastSeen = shipment.lastSeen;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shipment.itemTitle ?? l10n.shipThreadTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (shipment.unread > 0)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: scheme.primary, shape: BoxShape.circle),
                      child: Text('${shipment.unread}',
                          style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _StatusPill(status: shipment.status),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.route_outlined, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.shipRoute(shipment.fromLocation, shipment.toLocation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              // Only once there is something to say. A shipment nobody has
              // touched yet says nothing rather than "unknown".
              if (lastSeen != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.place_outlined,
                        size: 14, color: context.tokens.accentInk),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${l10n.shipLastSeen}: $lastSeen',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.tokens.accentInk,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
              if (shipment.quotedPrice != null) ...[
                const SizedBox(height: 4),
                Text(l10n.shipQuotedAt(shipment.quotedPrice!),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.tokens.accentFill.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        shippingStatusLabel(context.l10n, status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.brightness == Brightness.dark
              ? context.tokens.accentInk
              : scheme.onSurface,
        ),
      ),
    );
  }
}

/// One shipment, and every checkpoint it has passed.
class ShipmentDetailScreen extends StatefulWidget {
  const ShipmentDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  ShippingRequest? _shipment;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Anything moving refetches this screen, so a checkpoint written while
    // somebody is looking at it appears without them doing anything.
    ShippingRepository.instance.pulse.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ShippingRepository.instance.pulse.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final shipment = await ShippingRepository.instance.detail(widget.id);
      if (mounted) setState(() {
        _shipment = shipment;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat() async {
    final id = _shipment?.conversationId;
    if (id == null) return;
    final thread = ChatRepository.instance.threads.value
        .where((t) => t.id == id)
        .firstOrNull;
    if (thread == null) {
      await ChatRepository.instance.refresh();
      if (!mounted) return;
    }
    final found = ChatRepository.instance.threads.value
        .where((t) => t.id == id)
        .firstOrNull;
    if (found == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(conversation: found)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final s = _shipment;

    return Scaffold(
      appBar: AppBar(
        title: Text(s?.itemTitle ?? l10n.shipThreadTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading && s == null
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? Center(child: Text(l10n.shipFailed))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      _StatusPill(status: s.status),
                      const SizedBox(height: 14),
                      Text(l10n.shipRoute(s.fromLocation, s.toLocation),
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      if (s.quotedPrice != null) ...[
                        const SizedBox(height: 6),
                        Text(l10n.shipQuotedAt(s.quotedPrice!),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                      const SizedBox(height: 24),
                      Text(l10n.shipTrackingTitle,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (s.tracking.isEmpty)
                        Text(l10n.shipNoTrackingYet,
                            style: TextStyle(color: scheme.onSurfaceVariant))
                      else
                        for (var i = 0; i < s.tracking.length; i++)
                          _TimelineRow(
                            event: s.tracking[i],
                            isLatest: i == 0,
                            isLast: i == s.tracking.length - 1,
                          ),
                    ],
                  ),
                ),
      bottomNavigationBar: s?.conversationId == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(l10n.shipChatAbout),
                ),
              ),
            ),
    );
  }
}

/// One checkpoint. The newest is filled in; the rest are outlines, so the eye
/// lands on where the thing is now rather than on where it has been.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isLatest,
    required this.isLast,
  });

  final TrackingEvent event;
  final bool isLatest;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final accent = context.tokens.accentInk;
    final where = event.where;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLatest
                      ? context.tokens.accentFill.withValues(alpha: 0.2)
                      : scheme.surfaceContainerHighest,
                ),
                child: Icon(trackingIcon(event.code),
                    size: 17,
                    color: isLatest ? accent : scheme.onSurfaceVariant),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: scheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trackingLabel(l10n, event),
                    style: TextStyle(
                      fontWeight: isLatest ? FontWeight.bold : FontWeight.w600,
                      color: isLatest ? accent : null,
                    ),
                  ),
                  if (where != null)
                    Text(where,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  // The note is shown under a known checkpoint, and *is* the
                  // checkpoint when the code is one this build has never seen.
                  if (event.note != null && trackingLabel(l10n, event) != event.note)
                    Text(event.note!,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  Text(
                    _when(context, event.happenedAt),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _when(BuildContext context, DateTime at) {
    final local = at.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
