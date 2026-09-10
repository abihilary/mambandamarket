import 'dart:async';

import 'package:flutter/material.dart';
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
class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final _repo = ShippingRepository.instance;
  bool _loading = true;
  bool _past = false;

  late final List<ShippingRequest> _mockActive = [
    ShippingRequest(
      id: 'mock_active_1',
      status: 'in_transit',
      source: 'external',
      itemTitle: 'Smartphone',
      reference: 'MB-48291',
      fromLocation: 'Edéa',
      toLocation: 'Bertoua',
      quotedTotalCents: 500000,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lastEventCode: 'in_transit',
      lastPlaceName: 'Bafia',
      etaDaysMin: 0,
      etaDaysMax: 0,
      tracking: [
        TrackingEvent(id: '1', code: 'received', happenedAt: DateTime.now().subtract(const Duration(hours: 5)), note: 'Order confirmed'),
        TrackingEvent(id: '2', code: 'picked_up', happenedAt: DateTime.now().subtract(const Duration(hours: 4)), note: 'Picked up'),
        TrackingEvent(id: '3', code: 'in_transit', happenedAt: DateTime.now().subtract(const Duration(minutes: 12)), note: 'In transit', placeName: 'Bafia'),
      ],
    ),
  ];

  late final List<ShippingRequest> _mockDelivered = [
    ShippingRequest(
      id: 'mock_delivered_1',
      status: 'delivered',
      source: 'external',
      itemTitle: 'Laptop',
      reference: 'MB-48210',
      fromLocation: 'Yaoundé',
      toLocation: 'Douala',
      quotedTotalCents: 3500000,
      deliveredAt: DateTime.now().subtract(const Duration(days: 3)),
      tracking: [
        TrackingEvent(id: '4', code: 'delivered', happenedAt: DateTime.now().subtract(const Duration(days: 3)), note: 'Delivered on Aug 10, 2026'),
      ],
    ),
    ShippingRequest(
      id: 'mock_delivered_2',
      status: 'delivered',
      source: 'external',
      itemTitle: 'Tablet',
      reference: 'MB-48211',
      fromLocation: 'Douala',
      toLocation: 'Buea',
      quotedTotalCents: 1500000,
      deliveredAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    ShippingRequest(
      id: 'mock_delivered_3',
      status: 'delivered',
      source: 'external',
      itemTitle: 'Monitor',
      reference: 'MB-48212',
      fromLocation: 'Kribi',
      toLocation: 'Yaoundé',
      quotedTotalCents: 2000000,
      deliveredAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF111318), // Dark header background
      appBar: AppBar(
        backgroundColor: const Color(0xFF111318),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Shipments',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF9F9F9), // Light body background
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: ValueListenableBuilder<List<ShippingRequest>>(
          valueListenable: _repo.shipments,
          builder: (context, live, _) {
            // Force include mock data for verification during simulation
            final all = [..._mockActive, ..._mockDelivered, ...live];

            if (_loading && live.isEmpty && all.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final activeCount = all.where((s) => !s.isFinished).length;
            final deliveredCount = all.where((s) => s.isFinished).length;

            final items = all.where((s) => s.isFinished == _past).toList(growable: false);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1F24),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabChip(
                            label: 'Active ($activeCount)',
                            selected: !_past,
                            onTap: () => setState(() => _past = false),
                          ),
                        ),
                        Expanded(
                          child: _TabChip(
                            label: 'Delivered ($deliveredCount)',
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
                              Icon(Icons.local_shipping_outlined,
                                  size: 48, color: scheme.onSurfaceVariant),
                              const SizedBox(height: 12),
                              Text(_past ? l10n.shipNonePast : l10n.shipNoneActive,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, i) => _ShipmentCardDesign(
                              shipment: items[i],
                              onTap: () {
                                final s = items[i];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ShipmentDetailScreen(
                                        id: s.id,
                                        mockRequest: s.id.startsWith('mock') ? s : null,
                                      )),
                                );
                              },
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
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC9E505) : Colors.transparent,
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

class _ShipmentCardDesign extends StatelessWidget {
  final ShippingRequest shipment;
  final VoidCallback onTap;

  const _ShipmentCardDesign({required this.shipment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColor = shipment.status == 'delivered' ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              // Item Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: shipment.id.startsWith('mock')
                      ? Image.network(
                          shipment.itemTitle == 'Smartphone'
                              ? 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=200'
                              : 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=200',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, color: Colors.grey),
                        )
                      : const Icon(Icons.inventory_2, color: Colors.grey),
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
                          shipment.displayRef,
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        Icon(
                          shipment.status == 'delivered' ? Icons.more_vert : Icons.chevron_right,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
                    Text(
                      shipment.itemTitle ?? shipment.itemDescription ?? 'Package',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          shipment.status == 'delivered' ? Icons.check_circle : Icons.local_shipping,
                          color: statusColor,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          shippingStatusLabel(l10n, shipment.status),
                          style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${shipment.fromLocation} → ${shipment.toLocation}',
                          style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (shipment.status != 'delivered') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Arriving: Aug 16, 02:00 – 05:00 PM',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Delivered on Aug 10, 2026',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                shipment.codPrice ?? 'FCFA 0',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: shipment.status == 'delivered' ? Colors.grey[100] : const Color(0xFFC9E505),
                foregroundColor: shipment.status == 'delivered' ? Colors.black87 : Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                shipment.status == 'delivered' ? 'View Details' : 'Track Package →',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShipmentDetailScreen extends StatefulWidget {
  const ShipmentDetailScreen({super.key, required this.id, this.mockRequest});
  final String id;
  final ShippingRequest? mockRequest;

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
    if (widget.mockRequest != null) {
      _shipment = widget.mockRequest;
      _loading = false;
      _docsLoading = false;
      _docs = [
        ShippingDocument(
          kind: 'confirmation',
          number: '${widget.mockRequest!.reference}-CONF',
          url: Uri.parse('https://example.com/doc1.pdf'),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        ShippingDocument(
          kind: 'receipt',
          number: '${widget.mockRequest!.reference}-RECT',
          url: Uri.parse('https://example.com/doc2.pdf'),
          createdAt: DateTime.now(),
        ),
      ];
    } else {
      ShippingRepository.instance.pulse.addListener(_load);
      _load();
    }
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
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: '${doc.number}.pdf')],
        subject: doc.number,
      );
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
      backgroundColor: const Color(0xFF111318), // Dark header
      appBar: AppBar(
        backgroundColor: const Color(0xFF111318),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Track Shipment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _loading && s == null
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? Center(child: Text(l10n.shipFailed))
              : Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: RefreshIndicator(
                    onRefresh: () => widget.mockRequest != null ? Future.value() : _load(),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // 1. Banner Header
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xFF111318),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                          ),
                          child: Stack(
                            children: [
                              // Background Illustration
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.6,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                                    child: Image.network(
                                      'https://images.unsplash.com/photo-1519003722824-194d4455a60c?w=800&auto=format&fit=crop&q=60',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox(),
                                    ),
                                  ),
                                ),
                              ),
                              // Gradient Overlay
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.4),
                                        const Color(0xFF111318),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your package is on the way!',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${s.fromLocation} → ${s.toLocation}',
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 2. Timeline
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                          child: Column(
                            children: [
                              if (s.tracking.isEmpty)
                                Text(l10n.shipNoTrackingYet, style: TextStyle(color: scheme.onSurfaceVariant))
                              else
                                ...List.generate(s.tracking.length + 2, (index) {
                                  // Mocking some future steps for Image 2 parity
                                  if (index < s.tracking.length) {
                                    final event = s.tracking[index];
                                    final isTransit = event.code == 'in_transit';
                                    return _TimelineRowDesign(
                                      event: event,
                                      isLatest: index == s.tracking.length - 1,
                                      isLast: false,
                                      isCompleted: !isTransit,
                                      isActive: isTransit,
                                    );
                                  } else if (index == s.tracking.length) {
                                    return const _TimelineRowDesignMock(
                                      title: 'Arriving today',
                                      subtitle: 'Aug 16, 02:00 – 05:00 PM',
                                      isLatest: false,
                                      isLast: false,
                                      isCompleted: false,
                                    );
                                  } else {
                                    return const _TimelineRowDesignMock(
                                      title: 'Delivered',
                                      subtitle: 'Pending',
                                      isLatest: false,
                                      isLast: true,
                                      isCompleted: false,
                                    );
                                  }
                                }),
                            ],
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Divider(),
                        ),

                        // 3. Current Location Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Current location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F9F9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.green.withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC9E505).withOpacity(0.1),
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
                                            'Your package is in ${s.lastSeen ?? 'transit'}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const Text(
                                            'Updated 12 min ago',
                                            style: TextStyle(color: Colors.grey, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 80,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                        image: const DecorationImage(
                                          image: NetworkImage('https://static-maps.yandex.ru/1.x/?lang=en_US&ll=11.5,3.8&z=10&l=map&size=160,100'),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (_docs.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Documents & Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                for (final doc in _docs)
                                  _DocumentRow(
                                    doc: doc,
                                    busy: _sharing == doc.number,
                                    onOpen: () => _openDoc(doc),
                                    onShare: () => _shareDoc(doc),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openChat,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  side: BorderSide(color: Colors.green.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                label: const Text('Chat with courier', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openMap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9E505),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 56),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.map_outlined, size: 20),
                label: const Text('Track on map', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRowDesign extends StatelessWidget {
  const _TimelineRowDesign({
    required this.event,
    required this.isLatest,
    required this.isLast,
    this.isCompleted = true,
    this.isActive = false,
  });

  final TrackingEvent event;
  final bool isLatest;
  final bool isLast;
  final bool isCompleted;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return _BaseTimelineRow(
      title: trackingLabel(context.l10n, event),
      subtitle: _when(event.happenedAt),
      isLatest: isLatest,
      isLast: isLast,
      isCompleted: isCompleted,
      isActive: isActive,
    );
  }

  String _when(DateTime at) {
    final local = at.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[local.month - 1]} ${local.day}, ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _TimelineRowDesignMock extends StatelessWidget {
  const _TimelineRowDesignMock({
    required this.title,
    required this.subtitle,
    required this.isLatest,
    required this.isLast,
    required this.isCompleted,
  });

  final String title;
  final String subtitle;
  final bool isLatest;
  final bool isLast;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return _BaseTimelineRow(
      title: title,
      subtitle: subtitle,
      isLatest: isLatest,
      isLast: isLast,
      isCompleted: isCompleted,
    );
  }
}

class _BaseTimelineRow extends StatelessWidget {
  const _BaseTimelineRow({
    required this.title,
    required this.subtitle,
    required this.isLatest,
    required this.isLast,
    required this.isCompleted,
    this.isActive = false,
  });

  final String title;
  final String subtitle;
  final bool isLatest;
  final bool isLast;
  final bool isCompleted;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFFC9E505);
    
    return IntrinsicHeight(
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        decoration: isActive ? BoxDecoration(
          color: const Color(0xFFC9E505).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ) : null,
        padding: isActive ? const EdgeInsets.symmetric(vertical: 12, horizontal: 8) : const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? Colors.green : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : (isActive ? Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ) : null),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isCompleted ? Colors.green : Colors.grey[300],
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
                              fontWeight: (isCompleted || isActive) ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                              color: (isCompleted || isActive) ? Colors.black : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.map_outlined, size: 18, color: Colors.black),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFC9E505).withOpacity(0.1),
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
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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
            child: Text(l10n.shipDocOpen, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
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
