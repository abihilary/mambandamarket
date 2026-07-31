import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';
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

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.checkoutOrderFailed),
          backgroundColor: Colors.red.shade700,
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
                controller: _nameController,
                label: l10n.checkoutNameLabel,
                icon: Icons.person_outline,
                error: l10n.checkoutNameRequired,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _phoneController,
                label: l10n.checkoutPhoneLabel,
                icon: Icons.phone_outlined,
                error: l10n.checkoutPhoneRequired,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _addressController,
                label: l10n.checkoutAddressLabel,
                icon: Icons.location_on_outlined,
                error: l10n.checkoutAddressRequired,
              ),
              const SizedBox(height: 12),
              _field(
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
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
            ),
            icon: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
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
  Widget _escrowBanner(AppLocalizations l10n) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.checkoutEscrowTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.checkoutEscrowBody,
                    style: TextStyle(
                        fontSize: 13, height: 1.35, color: Colors.green.shade900),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, color: Colors.grey),
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
                    color: theme.primaryColor,
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
    TextInputType? keyboardType,
  }) =>
      TextFormField(
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
    return InkWell(
      onTap: () => setState(() => _method = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const Divider(height: 24),
          _summaryRow(l10n.checkoutSubtotal, _displaySubtotal),
          const SizedBox(height: 8),
          _summaryRow(l10n.checkoutTotal, _displaySubtotal,
              emphasized: true, color: theme.primaryColor),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
          {bool emphasized = false, Color? color}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasized ? 15 : 13,
              fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
              color: emphasized ? Colors.black : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasized ? 18 : 13,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      );
}
