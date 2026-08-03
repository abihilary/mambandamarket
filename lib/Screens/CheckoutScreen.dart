import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'OrderDetailScreen.dart';

/// Buying a verified company's listing in-app.
///
/// Two things are deliberately loud here: the escrow promise (the buyer's money
/// is held, not handed over) and the total. Everything else — delivery details,
/// quantity, payment wallet — is ordinary form work.
class CheckoutScreen extends StatefulWidget {
  /// Must be a buyable listing (`companyId != null`); callers gate on
  /// [api.Listing.isBuyable] before pushing this screen.
  final api.Listing listing;

  const CheckoutScreen({super.key, required this.listing});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _noteController = TextEditingController();
  final _momoController = TextEditingController();

  // Keyed in visual order so a failed validation can scroll to the first
  // offending field. The Mobile Money number sits below the fold on most
  // phones: without this, tapping Pay looked like it did nothing at all.
  final _nameKey = GlobalKey();
  final _phoneKey = GlobalKey();
  final _addressKey = GlobalKey();
  final _cityKey = GlobalKey();
  final _momoKey = GlobalKey();

  int _quantity = 1;

  /// Wallet the payment processor should charge. `campay` fronts both.
  String _method = 'mtn_momo';

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from the profile so the common case is a two-tap purchase.
    final profile = AuthService.instance.me.value?.profile;
    _nameController.text = profile?.displayName ?? '';
    _phoneController.text = profile?.phone ?? '';
    _momoController.text = profile?.phone ?? '';
    _cityController.text = profile?.city ?? widget.listing.city ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _noteController.dispose();
    _momoController.dispose();
    super.dispose();
  }

  /// Stock cap — never let the buyer order more than the company listed.
  int get _maxQuantity =>
      widget.listing.quantity < 1 ? 1 : widget.listing.quantity;

  int get _subtotalCents => widget.listing.priceCents * _quantity;

  /// The platform's commission comes out of the company's side, so what the
  /// buyer sees as subtotal is also what they pay.
  String get _displaySubtotal =>
      api.formatPrice(_subtotalCents, currency: widget.listing.currency);

  /// Bring the first empty required field into view.
  ///
  /// Form.validate() marks every offender, but says nothing if the offender is
  /// scrolled off screen — which is exactly where the Mobile Money number sits.
  /// The button then appears to do nothing at all.
  void _revealFirstInvalid() {
    final ordered = <MapEntry<GlobalKey, TextEditingController>>[
      MapEntry(_nameKey, _nameController),
      MapEntry(_phoneKey, _phoneController),
      MapEntry(_addressKey, _addressController),
      MapEntry(_cityKey, _cityController),
      MapEntry(_momoKey, _momoController),
    ];
    for (final entry in ordered) {
      if (entry.value.text.trim().isNotEmpty) continue;
      final fieldContext = entry.key.currentContext;
      if (fieldContext != null) {
        Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 300),
          alignment: 0.25,
        );
      }
      return;
    }
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) {
      _revealFirstInvalid();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.checkoutFixFields)),
      );
      return;
    }

    if (AuthService.instance.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.checkoutSignInRequired)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final order = await OrdersRepository.instance.create(
        companyId: widget.listing.companyId!,
        items: [(listingId: widget.listing.id, quantity: _quantity)],
        deliveryName: _nameController.text.trim(),
        deliveryPhone: _phoneController.text.trim(),
        deliveryAddress: _addressController.text.trim(),
        deliveryCity: _cityController.text.trim(),
        note: _noteController.text,
      );

      // The order now exists. Whatever the payment leg does, the user must end
      // up on it — losing the screen would leave them unable to pay or cancel.
      var message = l10n.checkoutPaymentPending;
      try {
        final payment = await OrdersRepository.instance.pay(
          order.id,
          provider: 'campay',
          method: _method,
          phone: _momoController.text.trim(),
        );
        final url = payment.redirectUrl;
        if (url != null && url.isNotEmpty) {
          final opened = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
          if (!opened) message = l10n.checkoutPaymentOpenFailed;
        }
      } catch (_) {
        // Manual/pending payment, or the processor refused to start: the order
        // is still valid and payable from its detail screen.
        message = l10n.checkoutPaymentFailed;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order.id),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.isUnauthorized ? l10n.checkoutSignInRequired : e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.checkoutOrderFailed),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final listing = widget.listing;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.checkoutTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _escrowBanner(l10n),
              const SizedBox(height: 16),
              _itemCard(theme, listing),
              const SizedBox(height: 16),

              _sectionTitle(l10n.checkoutDeliveryTitle),
              const SizedBox(height: 8),
              _field(
                fieldKey: _nameKey,
                controller: _nameController,
                label: l10n.checkoutNameLabel,
                icon: Icons.person_outline,
                error: l10n.checkoutNameRequired,
              ),
              const SizedBox(height: 12),
              _field(
                fieldKey: _phoneKey,
                controller: _phoneController,
                label: l10n.checkoutPhoneLabel,
                icon: Icons.phone_outlined,
                error: l10n.checkoutPhoneRequired,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _field(
                fieldKey: _addressKey,
                controller: _addressController,
                label: l10n.checkoutAddressLabel,
                icon: Icons.location_on_outlined,
                error: l10n.checkoutAddressRequired,
              ),
              const SizedBox(height: 12),
              _field(
                fieldKey: _cityKey,
                controller: _cityController,
                label: l10n.checkoutCityLabel,
                icon: Icons.location_city_outlined,
                error: l10n.checkoutCityRequired,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: l10n.checkoutNoteLabel,
                  hintText: l10n.checkoutNoteHint,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              _sectionTitle(l10n.checkoutPaymentTitle),
              const SizedBox(height: 8),
              _methodTile(
                value: 'mtn_momo',
                label: l10n.checkoutMethodMtn,
                color: Colors.amber.shade700,
              ),
              const SizedBox(height: 8),
              _methodTile(
                value: 'orange_money',
                label: l10n.checkoutMethodOrange,
                color: Colors.deepOrange,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: _momoKey,
                controller: _momoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.checkoutMomoLabel,
                  helperText: l10n.checkoutMomoHelper,
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.checkoutMomoRequired
                    : null,
              ),
              const SizedBox(height: 20),

              _summaryCard(l10n, theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
            ),
            icon: _submitting
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: theme.colorScheme.onPrimary),
                  )
                : const Icon(Icons.lock_outline),
            label: Text(
              l10n.checkoutPayNow(_displaySubtotal),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  /// The trust promise, above everything else on the screen.
  ///
  /// The pastel green plate would disappear on the dark ground, so the fill is
  /// the success token at low alpha instead. The icon and headline keep the
  /// green — that's the signal — while the paragraph runs at full text contrast
  /// so it stays readable on both grounds.
  Widget _escrowBanner(AppLocalizations l10n) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_user_outlined, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.checkoutEscrowTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.checkoutEscrowBody,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _itemCard(ThemeData theme, api.Listing listing) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              listing.primaryImageUrl,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 64,
                height: 64,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.displayPrice,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          // Quantity stepper, capped at what's in stock.
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _quantity <= 1
                    ? null
                    : () => setState(() => _quantity--),
              ),
              Text('$_quantity',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _quantity >= _maxQuantity
                    ? null
                    : () => setState(() => _quantity++),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String error,
    Key? fieldKey,
    TextInputType? keyboardType,
  }) =>
      TextFormField(
        key: fieldKey,
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? error : null,
      );

  Widget _methodTile({
    required String value,
    required String label,
    required Color color,
  }) {
    final selected = _method == value;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => setState(() => _method = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          // [color] is the wallet's own brand mark (MTN yellow, Orange orange),
          // so it stays fixed; only the plate under it follows the theme.
          color: selected
              ? color.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.smartphone, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Radio<String>(
              value: value,
              groupValue: _method,
              activeColor: color,
              onChanged: (v) {
                if (v != null) setState(() => _method = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(AppLocalizations l10n, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.checkoutSummaryTitle,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Text(
                l10n.checkoutUnitPrice(widget.listing.displayPrice, _quantity),
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const Divider(height: 24),
          _summaryRow(l10n.checkoutSubtotal, _displaySubtotal),
          const SizedBox(height: 8),
          _summaryRow(l10n.checkoutTotal, _displaySubtotal,
              emphasized: true, color: theme.colorScheme.primary),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool emphasized = false, Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasized ? 15 : 13,
            fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
            color: emphasized ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 18 : 13,
            fontWeight: FontWeight.bold,
            color: color ?? scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
