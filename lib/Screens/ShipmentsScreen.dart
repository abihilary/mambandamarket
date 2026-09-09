import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Service/ChatRoomScreen.dart';
import '../api/auth_service.dart';
import '../api/location_share.dart';
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

  /// Active, or everything that is over — delivered, cancelled, declined.
  /// "Past" rather than "Delivered" because three of those five ends are not
  /// deliveries and a tab named for one of them would be wrong for the rest.
  bool _past = false;

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
        builder: (context, all, _) {
          if (_loading && all.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (all.isEmpty) return _empty(context);
          final items = all.where((s) => s.isFinished == _past).toList(growable: false);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l10n.shipTabActive)),
                    ButtonSegment(value: true, label: Text(l10n.shipTabPast)),
                  ],
                  selected: {_past},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => _past = v.first),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _repo.refreshMine,
                  child: items.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: [
                            const SizedBox(height: 48),
                            Icon(Icons.local_shipping_outlined,
                                size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(_past ? l10n.shipNonePast : l10n.shipNoneActive,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
                ),
              ),
            ],
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
    final eta = shipment.isFinished ? null : shipment.eta();
    final price = shipment.codPrice;

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
              if (shipment.displayRef.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(shipment.displayRef,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
                ),
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
              if (eta != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule_outlined, size: 14, color: context.tokens.accentInk),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _etaLine(l10n, eta),
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
              if (price != null) ...[
                const SizedBox(height: 6),
                Text(
                  shipment.status == 'delivered'
                      ? l10n.shipCollected(price)
                      : l10n.shipPayOnDeliveryAmount(price),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _etaLine(AppLocalizations l10n, EtaWindow eta) => switch (eta.kind) {
      EtaKind.late => l10n.shipArrivingLate,
      EtaKind.today => l10n.shipArrivingToday,
      EtaKind.range => l10n.shipArrivingIn(
          eta.minDays == eta.maxDays
              ? l10n.shipEtaDaysOne(eta.maxDays)
              : eta.minDays == 0
                  ? l10n.shipEtaUpTo(eta.maxDays)
                  : l10n.shipEtaDays(eta.minDays, eta.maxDays),
        ),
    };

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
  List<ShippingDocument> _docs = const [];
  bool _docsLoading = true;
  bool _accepting = false;
  String? _sharing;

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
    // Separately, so paperwork that is not ready never hides the shipment.
    try {
      final docs = await ShippingRepository.instance.documents(widget.id);
      if (mounted) setState(() {
        _docs = docs;
        _docsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _docsLoading = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await ShippingRepository.instance.accept(widget.id);
      _snack(context.l10n.shipAccepted);
      await _load();
      unawaited(ShippingRepository.instance.refreshMine());
    } catch (_) {
      _snack(context.l10n.shipAcceptFailed);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _openDoc(ShippingDocument doc) async {
    final ok = await launchUrl(doc.url, mode: LaunchMode.externalApplication);
    if (!ok) _snack(context.l10n.shipDocOpenFailed);
  }

  Future<void> _shareDoc(ShippingDocument doc) async {
    if (_sharing != null) return;
    setState(() => _sharing = doc.number);
    try {
      final file = await ShippingRepository.instance.documentFile(doc);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf', name: '${doc.number}.pdf')],
        subject: doc.number,
      ));
    } catch (_) {
      _snack(context.l10n.shipDocOpenFailed);
    } finally {
      if (mounted) setState(() => _sharing = null);
    }
  }

  Future<void> _openMap() async {
    final s = _shipment;
    if (s == null || !s.hasPosition) return;
    if (await launchUrl(mapUriFor(s.lastLat!, s.lastLng!), mode: LaunchMode.externalApplication)) return;
    await launchUrl(webMapUriFor(s.lastLat!, s.lastLng!), mode: LaunchMode.externalApplication);
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
                      Row(
                        children: [
                          _StatusPill(status: s.status),
                          if (s.displayRef.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Text(s.displayRef,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                )),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(l10n.shipRoute(s.fromLocation, s.toLocation),
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      if (s.tier != null && s.etaDaysMin != null) ...[
                        const SizedBox(height: 4),
                        Text(etaText(l10n, s.etaDaysMin, s.etaDaysMax),
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                      ],
                      if (s.isQuotePending) ...[
                        const SizedBox(height: 16),
                        _AcceptQuotePanel(shipment: s, busy: _accepting, onAccept: _accept),
                      ] else if (s.codPrice != null && (!s.isFinished || s.status == 'delivered')) ...[
                        const SizedBox(height: 16),
                        _CodBanner(shipment: s),
                      ],
                      if (s.hasPosition && !s.isFinished) ...[
                        const SizedBox(height: 16),
                        _LocationCard(shipment: s, onOpen: _openMap),
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
                      const SizedBox(height: 28),
                      Text(l10n.shipDocumentsTitle,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (_docsLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                        )
                      else if (_docs.isEmpty)
                        Text(l10n.shipDocNone,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))
                      else
                        for (final doc in _docs)
                          _DocumentRow(
                            doc: doc,
                            busy: _sharing == doc.number,
                            onOpen: () => _openDoc(doc),
                            onShare: () => _shareDoc(doc),
                          ),
                      if (!_docsLoading && _docs.isNotEmpty && (AuthService.instance.user?.email ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(l10n.shipDocEmailed(AuthService.instance.user!.email!),
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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

/// What is paid at the door. Nothing before.
class _CodBanner extends StatelessWidget {
  const _CodBanner({required this.shipment});
  final ShippingRequest shipment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final price = shipment.codPrice!;
    final delivered = shipment.status == 'delivered';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.accentFill.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(delivered ? Icons.task_alt : Icons.payments_outlined, color: tokens.accentInk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(delivered ? l10n.shipCollected(price) : l10n.shipCodBannerTitle(price),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (!delivered)
                  Text(l10n.shipCodBannerBody,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The desk set a price. Nothing moves until they say yes to it.
class _AcceptQuotePanel extends StatelessWidget {
  const _AcceptQuotePanel({required this.shipment, required this.busy, required this.onAccept});
  final ShippingRequest shipment;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final until = shipment.quoteExpiresAt?.toLocal();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.accentInk, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.shipNewPriceTitle(shipment.quotedPrice ?? ''),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: tokens.accentInk)),
          const SizedBox(height: 4),
          Text(l10n.shipNewPriceBody,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          if (until != null)
            Text(l10n.shipNewPriceUntil('${until.day}/${until.month}/${until.year}'),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: busy ? null : onAccept,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
            ),
            child: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.shipAcceptPrice, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Where it was last seen, and a way to look at that on a map.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.shipment, required this.onOpen});
  final ShippingRequest shipment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final at = shipment.lastEventAt?.toLocal();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.place_outlined, color: context.tokens.accentInk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.shipCurrentLocation,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                Text(shipment.lastSeen ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (at != null)
                  Text('${at.day}/${at.month} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton(onPressed: onOpen, child: Text(l10n.shipOpenInMaps)),
        ],
      ),
    );
  }
}

/// One document: open it, or send it somewhere.
class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.doc, required this.busy, required this.onOpen, required this.onShare});
  final ShippingDocument doc;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf_outlined, color: context.tokens.accentInk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.isReceipt ? l10n.shipDocReceipt : l10n.shipDocConfirmation,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(doc.number,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ],
            ),
          ),
          TextButton(onPressed: onOpen, child: Text(l10n.shipDocOpen)),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  onPressed: onShare,
                  tooltip: l10n.shipDocShare,
                  icon: const Icon(Icons.share_outlined, size: 20),
                ),
        ],
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
