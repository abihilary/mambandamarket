import 'package:flutter/material.dart';

import '../api/shipping_draft.dart';
import '../l10n/l10n.dart';
import 'ShippingRequestScreen.dart';

/// Three ways in, which are really the two the backend knows: a Mambanda
/// listing, or something from outside. "Buy & deliver" is the outside path
/// with a link — the form's optional URL field is exactly that — so it opens
/// the same screen rather than a promise of a feature that does not exist.
class DeliveryOptionsScreen extends StatelessWidget {
  const DeliveryOptionsScreen({super.key});

  void _open(BuildContext context, ShippingSource source) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShippingRequestScreen(initialSource: source)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deliveryTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deliveryOptionsTitle,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.15),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.deliveryOptionsBody,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _OptionCard(
              icon: Icons.storefront_outlined,
              title: l10n.deliveryOptPurchaseTitle,
              subtitle: l10n.deliveryOptPurchaseBody,
              buttonText: l10n.deliveryOptPurchaseCta,
              onTap: () => _open(context, ShippingSource.mambanda),
            ),
            const SizedBox(height: 14),
            _OptionCard(
              icon: Icons.local_shipping_outlined,
              title: l10n.deliveryOptShipTitle,
              subtitle: l10n.deliveryOptShipBody,
              buttonText: l10n.deliveryOptShipCta,
              onTap: () => _open(context, ShippingSource.external),
            ),
            const SizedBox(height: 14),
            _OptionCard(
              icon: Icons.link_rounded,
              title: l10n.deliveryOptBuyTitle,
              subtitle: l10n.deliveryOptBuyBody,
              buttonText: l10n.deliveryOptBuyCta,
              onTap: () => _open(context, ShippingSource.external),
            ),
            const Spacer(),
            Center(
              child: Image.asset(
                'assets/brand/mark.png',
                height: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.deliveryTagline,
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9E505).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onSurface),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.3)),
                    const SizedBox(height: 8),
                    Text(
                      '$buttonText →',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
