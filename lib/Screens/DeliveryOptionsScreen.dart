import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'ShippingRequestScreen.dart';

class DeliveryOptionsScreen extends StatelessWidget {
  const DeliveryOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white, // White background instead of default/cream
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Mabanda Delivery'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What do you want\nto do?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how you want to use our delivery service.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _OptionCard(
              icon: Icons.shopping_cart_outlined,
              color: Colors.lime,
              title: 'Deliver my purchase',
              subtitle: 'Bought something on Mabanda?\nLet us deliver it for you.',
              buttonText: 'Arrange Delivery →',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShippingRequestScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.local_shipping_outlined,
              color: Colors.lightGreen,
              title: 'Ship something',
              subtitle: 'Need to send an item to someone?\nGet a delivery quote.',
              buttonText: 'Get a Quote →',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShippingRequestScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.public_outlined,
              color: Colors.green,
              title: 'Buy & Deliver',
              subtitle: 'Found something outside Mabanda?\nWe\'ll buy and deliver it for you.',
              buttonText: 'Ask Mabanda →',
              onTap: () {
                // Future implementation for concierge
              },
            ),
            const Spacer(),
            Center(
              child: Image.asset(
                'assets/brand/mark.png',
                height: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Safe • Fast • Reliable',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, // Pure white background
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)), // Green outline
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    buttonText,
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
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
