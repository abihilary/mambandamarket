import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Service/ChatRoomScreen.dart';
import '../api/location_share.dart';
import '../api/repositories.dart';
import '../api/shipping_model.dart';
import '../api/shipping_repository.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import 'ShippingRequestScreen.dart';

/// Everything somebody has asked us to ship, and where each of it has got to.
///
/// The look is the delivery mockup: a dark header, a white sheet with rounded
/// shoulders, lime segmented tabs. Everything on it comes from the API — the
/// list, the counts, the ETA, the price, the documents. Nothing here is
/// invented for the screen to look full.
class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

/// The delivery surfaces share a fixed dark header and a white sheet, in both
/// app themes — it is the mockup's look, not a themed one, so the sheet's own
/// text colours are set explicitly rather than read from the scheme.
const _kInk = Color(0xFF111318);
const _kInkRaised = Color(0xFF1D1F24);
const _kSheet = Color(0xFFF9F9F9);
const _kLime = Color(0xFFC9E505);

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final _repo = ShippingRepository.instance;
  bool _loading = true;
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
      backgroundColor: _kInk,
      appBar: AppBar(
        backgroundColor: _kInk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.shipMyShipments,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: _kSheet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: ValueListenableBuilder<List<ShippingRequest>>(
          valueListenable: _repo.shipments,
          builder: (context, all, _) {
            if (_loading && all.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final activeCount = all.where((s) => !s.isFinished).length;
            final pastCount = all.length - activeCount;
            final items = all.where((s) => s.isFinished == _past).toList(growable: false);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _kInkRaised,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabChip(
                            label: '${l10n.shipTabActive} ($activeCount)',
                            selected: !_past,
                            onTap: () => setState(() => _past = false),
                          ),
                        ),
                        Expanded(
                          child: _TabChip(
                            label: '${l10n.shipTabPast} ($pastCount)',
                            selected: _past,
                            onTap: () => setState(() => _past = true),
                          ),
                        ),
                      ],
                    ),
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
                              Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey[500]),
                              const SizedBox(height: 12),
                              Text(
                                _past ? l10n.shipNonePast : l10n.shipNoneActive,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 16),
                            itemBuilder: (context, i) => _ShipmentCard(
                              shipment: items[i],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShipmentDetailScreen(id: items[i].id),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
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
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _kLime : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// A shipment's title: what they called it, else how they described it, else
/// its reference — never a made-up word.
String _titleOf(ShippingRequest s) {
  final title = s.itemTitle?.trim();
  if (title != null && title.isNotEmpty) return title;
  final desc = s.itemDescription?.trim();
  if (desc != null && desc.isNotEmpty) return desc;
  return s.displayRef;
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

/// `9 Sept, 23:01` in the phone's language — not a hard-coded English month.
String _when(BuildContext context, DateTime at) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.MMMd(locale).add_Hm().format(at.toLocal());
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.shipment, required this.onTap});
  final ShippingRequest shipment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = shipment;
    final delivered = s.status == 'delivered';
    final statusColor = delivered
        ? Colors.green
        : s.isFinished
            ? Colors.grey
            : Colors.orange;
    final eta = s.isFinished ? null : s.eta();
    final price = s.codPrice;

    // The one line under the route: when it is coming, or when it came.
    String? whenLine;
    if (delivered && s.deliveredAt != null) {
      whenLine = '${shippingStatusLabel(l10n, s.status)} · ${_when(context, s.deliveredAt!)}';
    } else if (eta != null) {
      whenLine = _etaLine(l10n, eta);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  delivered ? Icons.inventory_2 : Icons.local_shipping_outlined,
                  color: Colors.grey[500],
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.displayRef,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                      ],
                    ),
                    Text(
                      _titleOf(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          delivered ? Icons.check_circle : Icons.local_shipping,
                          color: statusColor,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          shippingStatusLabel(l10n, s.status),
                          style: TextStyle(
                              color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${s.fromLocation} → ${s.toLocation}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    if (whenLine != null) ...[
                      const SizedBox(height: 4),
                      Text(whenLine, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (price != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  delivered ? l10n.shipCollected(price) : l10n.shipPayOnDelivery,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  price,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: s.isFinished ? Colors.grey[100] : _kLime,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                s.isFinished ? l10n.shipViewDetails : '${l10n.shipTrackPackage} →',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail ──────────────────────────────────────────────────────────────────

class ShipmentDetailScreen extends StatefulWidget {
  const ShipmentDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

/// The stops a Douala delivery goes through, in order. Real events are shown
/// as they happen; the stops not reached yet are drawn greyed so the customer
/// can see what is still to come — that is the mockup's "future steps", made
/// from the actual journey rather than invented dates.
const _kJourney = ['received', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered'];

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
      if (mounted) {
        setState(() {
          _shipment = shipment;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    // Separately, so a document hiccup never hides the shipment itself.
    try {
      final docs = await ShippingRepository.instance.documents(widget.id);
      if (mounted) {
        setState(() {
          _docs = docs;
          _docsLoading = false;
        });
      }
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
    final l10n = context.l10n;
    setState(() => _accepting = true);
    try {
      await ShippingRepository.instance.accept(widget.id);
      _snack(l10n.shipAccepted);
      await _load();
      unawaited(ShippingRepository.instance.refreshMine());
    } catch (_) {
      _snack(l10n.shipAcceptFailed);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _openDoc(ShippingDocument doc) async {
    final l10n = context.l10n;
    final ok = await launchUrl(doc.url, mode: LaunchMode.externalApplication);
    if (!ok) _snack(l10n.shipDocOpenFailed);
  }

  Future<void> _shareDoc(ShippingDocument doc) async {
    if (_sharing != null) return;
    final l10n = context.l10n;
    setState(() => _sharing = doc.number);
    try {
      final file = await ShippingRepository.instance.documentFile(doc);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf', name: '${doc.number}.pdf')],
        subject: doc.number,
      ));
    } catch (_) {
      _snack(l10n.shipDocOpenFailed);
    } finally {
      if (mounted) setState(() => _sharing = null);
    }
  }

  Future<void> _openMap() async {
    final s = _shipment;
    if (s == null) return;
    if (!s.hasPosition) {
      _snack(context.l10n.shipNoTrackingYet);
      return;
    }
    if (await launchUrl(mapUriFor(s.lastLat!, s.lastLng!), mode: LaunchMode.externalApplication)) {
      return;
    }
    await launchUrl(webMapUriFor(s.lastLat!, s.lastLng!), mode: LaunchMode.externalApplication);
  }

  Future<void> _openChat() async {
    final id = _shipment?.conversationId;
    if (id == null) return;
    var thread = ChatRepository.instance.threads.value.where((t) => t.id == id).firstOrNull;
    if (thread == null) {
      await ChatRepository.instance.refresh();
      if (!mounted) return;
      thread = ChatRepository.instance.threads.value.where((t) => t.id == id).firstOrNull;
    }
    if (thread == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(conversation: thread!)),
    );
  }

  /// The timeline rows: every real event, then whichever canonical stops have
  /// not happened yet. A brand-new request with no events still shows "we
  /// have the request" — its creation is a real moment, not a placeholder.
  List<Widget> _timeline(BuildContext context, ShippingRequest s) {
    final l10n = context.l10n;
    final events = [...s.tracking]..sort((a, b) => a.happenedAt.compareTo(b.happenedAt));
    if (events.isEmpty && s.createdAt != null) {
      events.add(TrackingEvent(id: 'created', code: 'received', happenedAt: s.createdAt!));
    }
    final done = s.isFinished;

    // How far along the canonical journey the furthest real event sits.
    var reached = -1;
    for (final e in events) {
      final i = _kJourney.indexOf(e.code);
      if (i > reached) reached = i;
    }
    final pending = done ? const <String>[] : _kJourney.skip(reached + 1).toList();

    final eta = done ? null : s.eta();
    final rows = <Widget>[];
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final latest = i == events.length - 1;
      final where = e.where;
      rows.add(_TimelineRow(
        title: trackingLabel(l10n, e),
        subtitle: where == null
            ? _when(context, e.happenedAt)
            : '${_when(context, e.happenedAt)} · $where',
        state: latest && !done ? _StepState.active : _StepState.done,
        isLast: latest && pending.isEmpty,
        onMap: latest && e.hasPosition
            ? () => launchUrl(mapUriFor(e.lat!, e.lng!), mode: LaunchMode.externalApplication)
            : null,
      ));
    }
    for (var i = 0; i < pending.length; i++) {
      final code = pending[i];
      rows.add(_TimelineRow(
        title: trackingLabel(l10n, TrackingEvent(id: code, code: code, happenedAt: DateTime.now())),
        subtitle: code == 'delivered' && eta != null ? _etaLine(l10n, eta) : '',
        state: _StepState.pending,
        isLast: i == pending.length - 1,
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = _shipment;

    return Scaffold(
      backgroundColor: _kInk,
      appBar: AppBar(
        backgroundColor: _kInk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          s != null && s.displayRef.isNotEmpty ? s.displayRef : l10n.shipTrackingTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
      body: _loading && s == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : s == null
              ? Center(child: Text(l10n.shipFailed, style: const TextStyle(color: Colors.white)))
              : Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _Banner(shipment: s),
                        if (s.isQuotePending)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                            child: _AcceptQuotePanel(
                                shipment: s, busy: _accepting, onAccept: _accept),
                          ),
                        if (s.codPrice != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                            child: _CodBanner(shipment: s),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                          child: Column(children: _timeline(context, s)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Divider(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: _LocationCard(shipment: s, onOpen: _openMap),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _Documents(
                            docs: _docs,
                            loading: _docsLoading,
                            sharing: _sharing,
                            onOpen: _openDoc,
                            onShare: _shareDoc,
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: s == null
          ? null
          : Container(
              color: Colors.white,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: s.conversationId == null ? null : _openChat,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        foregroundColor: Colors.black,
                        side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                      label: Text(l10n.shipChatAbout,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openMap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kLime,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 56),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: Text(l10n.shipOpenInMaps,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
                ),
              ),
            ),
    );
  }
}

/// The dark banner under the app bar: what is happening, and the route. The
/// backdrop is the brand mark from the bundle — nothing fetched over the
/// network to draw a header.
class _Banner extends StatelessWidget {
  const _Banner({required this.shipment});
  final ShippingRequest shipment;

  String _headline(AppLocalizations l10n) {
    final s = shipment;
    return switch (s.status) {
      'delivered' => l10n.shipBannerDelivered,
      'cancelled' || 'declined' || 'expired' => l10n.shipBannerClosed,
      'quoted' => l10n.shipBannerQuoted,
      'in_transit' || 'sourcing' => l10n.shipBannerOnTheWay,
      _ => l10n.shipBannerBooked,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = shipment;
    final eta = s.isFinished ? null : s.eta();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _kInk,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.55,
                child: Image.asset(
                  'assets/brand/onboarding_hero.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.6),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.35), _kInk],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headline(l10n),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.fromLocation} → ${s.toLocation}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (eta != null) ...[
                    const SizedBox(height: 2),
                    Text(_etaLine(l10n, eta),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is paid at the door — or, once it has been, what was.
class _CodBanner extends StatelessWidget {
  const _CodBanner({required this.shipment});
  final ShippingRequest shipment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = shipment.codPrice!;
    final delivered = shipment.status == 'delivered';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kLime.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(delivered ? Icons.check_circle_outline : Icons.payments_outlined,
              color: Colors.black87),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivered ? l10n.shipCollected(price) : l10n.shipCodBannerTitle(price),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black),
                ),
                if (!delivered)
                  Text(l10n.shipCodBannerBody,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A price the desk set by hand, waiting for a yes. This is the whole manual
/// path: without it a request the rate card could not price never moves.
class _AcceptQuotePanel extends StatelessWidget {
  const _AcceptQuotePanel({required this.shipment, required this.busy, required this.onAccept});
  final ShippingRequest shipment;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final until = shipment.quoteExpiresAt?.toLocal();
    final locale = Localizations.localeOf(context).toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLime, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.shipNewPriceTitle(shipment.quotedPrice ?? ''),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black)),
          const SizedBox(height: 4),
          Text(l10n.shipNewPriceBody, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          if (until != null)
            Text(l10n.shipNewPriceUntil(DateFormat.yMd(locale).format(until)),
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: busy ? null : onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kLime,
              foregroundColor: Colors.black,
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.shipAcceptPrice, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Where it was last seen. Always on the page, honest when there is nothing
/// yet. The map tile is a drawn map, not a photo of somewhere else; tapping
/// it opens the real coordinates in the phone's maps app.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.shipment, required this.onOpen});
  final ShippingRequest shipment;
  final VoidCallback onOpen;

  static String _ago(AppLocalizations l10n, DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return l10n.shipJustNow;
    if (d.inHours < 1) return l10n.shipMinutesAgo(d.inMinutes);
    if (d.inDays < 1) return l10n.shipHoursAgo(d.inHours);
    return l10n.shipDaysAgo(d.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = shipment;
    final place = s.lastSeen;
    final at = s.lastEventAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.shipCurrentLocation,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kSheet,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kLime.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place != null ? l10n.shipPackageIn(place) : l10n.shipNoTrackingYet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                    ),
                    if (at != null)
                      Text(
                        l10n.shipUpdatedAgo(_ago(l10n, at)),
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _MiniMap(active: s.hasPosition, onTap: s.hasPosition ? onOpen : null),
            ],
          ),
        ),
      ],
    );
  }
}

/// An 80×50 map-looking tile: a soft grid with a pin, lit when there are real
/// coordinates behind it. A live map image would need a maps provider key;
/// until there is one, this says "map" without pretending to be one.
class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.active, this.onTap});
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFE8F1DC) : Colors.grey[200],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 80,
          height: 50,
          child: CustomPaint(
            painter: _MapGridPainter(active: active),
            child: Center(
              child: Icon(
                active ? Icons.location_on : Icons.location_off_outlined,
                size: 20,
                color: active ? Colors.green[700] : Colors.grey[500],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({required this.active});
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = (active ? Colors.green[300]! : Colors.grey[400]!).withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    // A few "streets": two verticals, two horizontals, one diagonal.
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), road);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.75, size.height), road);
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.3), road);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.75), road);
    canvas.drawLine(Offset(0, size.height), Offset(size.width * 0.55, 0), road..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => old.active != active;
}

class _Documents extends StatelessWidget {
  const _Documents({
    required this.docs,
    required this.loading,
    required this.sharing,
    required this.onOpen,
    required this.onShare,
  });
  final List<ShippingDocument> docs;
  final bool loading;
  final String? sharing;
  final void Function(ShippingDocument) onOpen;
  final void Function(ShippingDocument) onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emailedTo = docs.map((d) => d.emailedTo).whereType<String>().firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.shipDocumentsAndReceipt,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 16),
        if (loading && docs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (docs.isEmpty)
          Text(l10n.shipDocNone, style: TextStyle(fontSize: 13, color: Colors.grey[600]))
        else ...[
          for (final doc in docs)
            _DocumentRow(
              doc: doc,
              busy: sharing == doc.number,
              onOpen: () => onOpen(doc),
              onShare: () => onShare(doc),
            ),
          if (emailedTo != null)
            Text(l10n.shipDocEmailed(emailedTo),
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ],
    );
  }
}

enum _StepState { done, active, pending }

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.isLast,
    this.onMap,
  });

  final String title;
  final String subtitle;
  final _StepState state;
  final bool isLast;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    final done = state == _StepState.done;
    final active = state == _StepState.active;
    final lit = done || active;

    return IntrinsicHeight(
      child: Container(
        decoration: active
            ? BoxDecoration(
                color: _kLime.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        padding: active
            ? const EdgeInsets.symmetric(vertical: 12, horizontal: 8)
            : const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: done ? Colors.green : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: lit ? Colors.green : Colors.grey[300]!, width: 2),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : active
                          ? Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.green, shape: BoxShape.circle),
                            )
                          : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: done ? Colors.green : Colors.grey[300],
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: lit ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                              color: lit ? Colors.black : Colors.grey,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                    if (onMap != null)
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        elevation: 1,
                        child: InkWell(
                          onTap: onMap,
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.map_outlined, size: 18, color: Colors.black),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow(
      {required this.doc, required this.busy, required this.onOpen, required this.onShare});
  final ShippingDocument doc;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kLime.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.black),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.isReceipt ? l10n.shipDocReceipt : l10n.shipDocConfirmation,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black)),
                const SizedBox(height: 2),
                Text(doc.number,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpen,
            child: Text(l10n.shipDocOpen,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  onPressed: onShare,
                  tooltip: l10n.shipDocShare,
                  icon: const Icon(Icons.share_outlined, size: 20, color: Colors.black54),
                ),
        ],
      ),
    );
  }
}
