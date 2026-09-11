import 'package:flutter/material.dart';

import '../Components/glass_surface.dart';
import '../api/repositories.dart';
import '../api/shipping_model.dart';
import '../api/shipping_repository.dart';
import '../l10n/l10n.dart';
import 'ChatInboxScreen.dart';
import 'DeliveryOptionsScreen.dart';
import 'ShipmentsScreen.dart';

/// The front door of the delivery service — the mockup's layout, with every
/// number on it read from this account's own data. The hero is the bundled
/// brand image, so it draws the same on a Douala data connection as on Wi-Fi.
class MabandaDeliveryHomeScreen extends StatefulWidget {
  const MabandaDeliveryHomeScreen({super.key});

  @override
  State<MabandaDeliveryHomeScreen> createState() => _MabandaDeliveryHomeScreenState();
}

const _kInk = Color(0xFF111318);
const _kLime = Color(0xFFC9E505);

class _MabandaDeliveryHomeScreenState extends State<MabandaDeliveryHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Warm the list so the counts on this screen are current when they look.
    ShippingRepository.instance.refreshMine();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/brand/mark.png', height: 28),
                      const SizedBox(width: 8),
                      Text(
                        l10n.deliveryTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF1D1F24),
                        ),
                      ),
                    ],
                  ),
                  // The bell is the inbox. The dot means unread messages —
                  // the same counter the home tab bar shows.
                  ValueListenableBuilder<int>(
                    valueListenable: ChatRepository.instance.totalUnread,
                    builder: (context, unread, _) => Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                          child: IconButton(
                            icon: const Icon(Icons.notifications_none_outlined,
                                color: Colors.black),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ChatInboxScreen()),
                            ),
                          ),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ValueListenableBuilder<List<ShippingRequest>>(
                  valueListenable: ShippingRepository.instance.shipments,
                  builder: (context, all, _) {
                    final active = all.where((s) => !s.isFinished).length;
                    final delivered = all.where((s) => s.status == 'delivered').length;
                    return Column(
                      children: [
                        _HeroCard(active: active, delivered: delivered),
                        const SizedBox(height: 16),
                        _CtaCard(
                          onShip: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DeliveryOptionsScreen()),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _MyShipmentsCard(
                          subtitle: all.isEmpty
                              ? l10n.deliveryNoShipmentsYet
                              : l10n.deliveryCounts(active, all.length - active),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ShipmentsScreen()),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              child: Text(
                l10n.deliveryTagline,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picture card with the glass stats chip. The chip reads this account's
/// own shipments — how many are moving, how many have arrived.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.active, required this.delivered});
  final int active;
  final int delivered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: 220,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kInk,
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: AssetImage('assets/brand/onboarding_hero.png'),
          fit: BoxFit.cover,
          alignment: Alignment(0, -0.35),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(20),
              tint: Colors.white.withValues(alpha: 0.1),
              sigma: 15,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.deliveryStatOnTheWay(active),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${l10n.deliveryStatDelivered(delivered)} · ${l10n.deliveryStatTagline}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({required this.onShip});
  final VoidCallback onShip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: _kInk, borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Opacity(
                opacity: 0.08,
                child: Image.asset('assets/brand/mark.png', width: 180, height: 180),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.deliveryHeroTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 240,
                    child: Text(
                      l10n.deliveryHeroBody,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onShip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kLime,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text('${l10n.deliveryShipCta} →',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyShipmentsCard extends StatelessWidget {
  const _MyShipmentsCard({required this.subtitle, required this.onTap});
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kLime.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Colors.black87),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.shipMyShipments,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
