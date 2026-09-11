import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Service/ChatRoomScreen.dart';
import '../api/models.dart';
import '../api/shipping_model.dart';
import '../api/shipping_repository.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import 'ShipmentsScreen.dart';

/// The moment after sending a request.
///
/// The first success screen in the app. Everything else ends in a snackbar
/// over the next screen, which is fine for "listing published" — but a
/// delivery booking has a reference to remember, a price to expect at the
/// door and a document to keep, and none of that survives a snackbar.
///
/// The same screen serves both paths. A request the catalogue could not price
/// says "we'll quote you in the chat" rather than landing somewhere different,
/// so the manual path never feels like the failure path.
class ShipmentConfirmedScreen extends StatelessWidget {
  const ShipmentConfirmedScreen({super.key, required this.request, this.conversation});

  final ShippingRequest request;
  final Conversation? conversation;

  bool get _priced => request.quotedTotalCents != null;

  Future<void> _openConfirmation(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final docs = await ShippingRepository.instance.documents(request.id);
      final doc = docs.where((d) => !d.isReceipt).firstOrNull;
      if (!context.mounted) return;
      if (doc == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.shipDocNotReady)));
        return;
      }
      final ok = await launchUrl(doc.url, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.shipDocOpenFailed)));
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.shipDocNotReady)));
    }
  }

  void _home(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final price = request.codPrice;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: tokens.accentFill, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded, size: 56, color: tokens.onAccentFill),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _priced ? l10n.shipConfirmedTitle : l10n.shipRequestSentTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
              if (request.displayRef.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  request.displayRef,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.accentInk,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                _priced && price != null ? l10n.shipConfirmedBody(price) : l10n.shipRequestSentBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.itemTitle ?? request.itemDescription ?? l10n.shipThreadTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.route_outlined, size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(l10n.shipRoute(request.fromLocation, request.toLocation),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                    if (request.tier != null && request.etaDaysMin != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_outlined, size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(etaText(l10n, request.etaDaysMin, request.etaDaysMax),
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      price != null ? l10n.shipPayOnDeliveryAmount(price) : l10n.shipSummaryPriceManual,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: tokens.accentInk),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  if (_priced || conversation == null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => ShipmentDetailScreen(id: request.id)),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => ChatRoomScreen(conversation: conversation!)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                icon: Icon(_priced || conversation == null ? Icons.local_shipping_outlined : Icons.chat_bubble_outline),
                label: Text(_priced || conversation == null ? l10n.shipViewTracking : l10n.shipOpenChat,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openConfirmation(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(l10n.shipDownloadConfirmation),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _home(context),
                child: Text(l10n.shipBackToHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
