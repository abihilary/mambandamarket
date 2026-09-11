import 'package:flutter/material.dart';

import '../api/shipping_model.dart';
import '../api/shipping_repository.dart';
import '../l10n/l10n.dart';
import 'DeliveryOptionsScreen.dart';
import 'ShipmentsScreen.dart';

/// The front door of the delivery service: one hero, one way in, and the
/// customer's own shipment count. The count is read from the repository, so
/// it says what is true for this account — including "nothing yet".
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
    // Warm the list so the count on this screen is current when they look.
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
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
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
                  const Spacer(),
                  // Keeps the title centred against the back button.
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Hero(
                      onShip: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DeliveryOptionsScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<List<ShippingRequest>>(
                      valueListenable: ShippingRepository.instance.shipments,
                      builder: (context, all, _) {
                        final active = all.where((s) => !s.isFinished).length;
                        final past = all.length - active;
                        return _MyShipmentsCard(
                          subtitle: all.isEmpty
                              ? l10n.deliveryNoShipmentsYet
                              : l10n.deliveryCounts(active, past),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ShipmentsScreen()),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
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

/// The dark hero card. The brand mark is the only picture — from the bundle,
/// so it draws on a Douala data connection the same as on Wi-Fi.
class _Hero extends StatelessWidget {
  const _Hero({required this.onShip});
  final VoidCallback onShip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kInk,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Opacity(
                opacity: 0.08,
                child: Image.asset('assets/brand/mark.png', width: 200, height: 200),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kLime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping_outlined, color: _kLime, size: 22),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.deliveryHeroTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.deliveryHeroBody,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: onShip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kLime,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(l10n.deliveryShipCta,
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
                    Text(
                      l10n.shipMyShipments,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black),
                    ),
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
