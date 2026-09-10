import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Service/ChatRoomScreen.dart';
import '../api/models.dart';
import '../api/shipping_model.dart';
import '../api/shipping_repository.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import '../theme/app_theme.dart';
import 'ShipmentsScreen.dart';

/// The success screen after sending a shipping request.
///
/// Matches Image #10: celebratory dark-themed screen with a big box graphic,
/// item summary, and direct tracking actions.
class ShipmentConfirmedScreen extends StatelessWidget {
  const ShipmentConfirmedScreen({super.key, required this.request, this.conversation});

  final ShippingRequest request;
  final Conversation? conversation;

  bool get _priced => request.quotedTotalCents != null;

  void _home(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = request.codPrice;

    // Forces dark theme for this screen specifically to match the design.
    return Theme(
      data: AppTheme.dark(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _home(context);
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF07080C), // Deep dark background
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // 1. Celebratory Box Graphic
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Sparkle/Glow Effect
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.lime.withOpacity(0.15),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              // 3D Cardboard Box Placeholder
                              // Note: In production, replace with a local asset like 'assets/graphics/confirmed_box.png'
                              Image.network(
                                'https://cdni.iconscout.com/illustration/premium/thumb/package-delivery-illustration-download-in-svg-png-gif-file-formats--shipping-logistics-courier-post-service-pack-business-illustrations-6407233.png',
                                height: 160,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.inventory_2,
                                  size: 120,
                                  color: Colors.lime,
                                ),
                              ),
                              // Floating Checkmark Badge
                              Positioned(
                                bottom: 20,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF4CAF50), // Design Green
                                    size: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 2. Title & Subtitle
                        const Text(
                          'Shipment Confirmed!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your package has been scheduled\nfor pickup.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // 3. Item Summary Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Item Thumbnail Placeholder
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.smartphone_rounded,
                                  color: Colors.grey,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request.itemTitle ?? request.itemDescription ?? 'Package',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${request.fromLocation} → ${request.toLocation}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      price ?? 'Quoted in chat',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Bottom Actions
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShipmentDetailScreen(id: request.id),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC9E505), // Brand Lime
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'View Tracking',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _home(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Back to Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // 5. Footer Branding
                      Center(
                        child: Text(
                          'Safe • Fast • Reliable',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
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
