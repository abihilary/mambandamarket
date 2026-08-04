import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Components/order_status_chip.dart';
import '../api/api_client.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// One purchase, from the buyer's side.
///
/// The escrow state gets the most prominent block on the screen: while the
/// money is held, "Confirm delivery" is the single action that releases it, and
/// the confirmation dialog says so in as many words.
class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  api.Order? _order;
  bool _loading = true;
  bool _busy = false;

  /// Set when loading failed. Real API messages are kept verbatim; this
  /// sentinel stands in for anything else, and is localized at build time.
  static const String _kLoadError = '__order_detail_load__';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await OrdersRepository.instance.detail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _kLoadError;
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime? at) {
    if (at == null) return '';
    return MaterialLocalizations.of(context).formatFullDate(at.toLocal());
  }

  /// Runs [action] then reloads, so the screen always reflects what the server
  /// actually holds rather than an optimistic guess about the money.
  Future<void> _run(Future<void> Function() action, String successMessage) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.orderActionFailed),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelivery(api.Order order) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.orderConfirmTitle),
        content: Text(l10n.orderConfirmBody(order.displayTotal)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.orderConfirmKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.orderConfirmRelease),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => OrdersRepository.instance.confirm(order.id),
      l10n.orderConfirmedSuccess,
    );
  }

  Future<void> _cancelOrder(api.Order order) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.orderCancelTitle),
        content: Text(l10n.orderCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.orderCancelKeep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.orderCancelConfirm,
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => OrdersRepository.instance.cancel(order.id),
      l10n.orderCancelledSuccess,
    );
  }

  /// Retry (or first-time) payment for an order that is still unpaid.
  Future<void> _pay(api.Order order) async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<({String method, String phone})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PaySheet(initialPhone: order.deliveryPhone ?? ''),
    );
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    var message = l10n.checkoutPaymentPending;
    try {
      final payment = await OrdersRepository.instance.pay(
        order.id,
        provider: 'campay',
        method: choice.method,
        phone: choice.phone,
      );
      final url = payment.redirectUrl;
      if (url != null && url.isNotEmpty) {
        final opened =
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!opened) message = l10n.checkoutPaymentOpenFailed;
      }
    } on ApiException catch (e) {
      message = e.message;
    } catch (_) {
      message = l10n.orderActionFailed;
    }
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final order = _order;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          order == null ? l10n.orderDetailTitle : '${l10n.orderDetailTitle} ${order.reference}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : order == null
                ? _errorState(l10n)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _headerCard(l10n, order),
                        const SizedBox(height: 16),
                        _escrowCard(l10n, order),
                        // Above the items: when a driver is at the door, the
                        // code is the only thing on this screen that matters.
                        if (order.shipment != null) ...[
                          const SizedBox(height: 16),
                          _shipmentCard(l10n, order.shipment!),
                        ],
                        const SizedBox(height: 16),
                        _itemsCard(l10n, order),
                        const SizedBox(height: 16),
                        _deliveryCard(l10n, order),
                        if (order.note != null && order.note!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _noteCard(l10n, order),
                        ],
                        const SizedBox(height: 16),
                        _totalsCard(l10n, order),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar:
          order == null ? null : _actions(l10n, order),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _errorState(AppLocalizations l10n) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final message =
        _error == _kLoadError ? l10n.orderDetailLoadError : (_error ?? l10n.orderDetailLoadError);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 44, color: muted),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: muted)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: Text(l10n.ordersTryAgain)),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: child,
      );

  Widget _headerCard(AppLocalizations l10n, api.Order order) => _card(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.reference,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.ordersPlacedOn(_formatDate(order.createdAt)),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            StatusChip(status: order.status),
          ],
        ),
      );

  /// Where the parcel is, and — while it is still on its way — the code the
  /// buyer reads out at the door.
  ///
  /// The code is the other half of the escrow promise: the driver cannot close
  /// the delivery without it, so it is the buyer's evidence that "delivered"
  /// means the goods actually arrived. It is set in a monospaced, widely
  /// letter-spaced style because it gets read aloud to a stranger, often in bad
  /// light through a gate.
  Widget _shipmentCard(AppLocalizations l10n, api.Shipment shipment) {
    final scheme = Theme.of(context).colorScheme;
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String body;

    if (shipment.isDelivered) {
      color = AppColors.success;
      icon = Icons.check_circle_outline;
      title = l10n.shipmentDeliveredTitle;
      body = l10n.shipmentDeliveredBody(_formatDate(shipment.deliveredAt));
    } else if (shipment.isFailed) {
      color = AppColors.danger;
      icon = Icons.error_outline;
      title = l10n.shipmentFailedTitle;
      body = shipment.failureReason?.isNotEmpty == true
          ? shipment.failureReason!
          : l10n.shipmentFailedBody;
    } else if (shipment.isOnTheRoad) {
      color = scheme.primary;
      icon = Icons.local_shipping_outlined;
      title = l10n.shipmentOnTheRoadTitle;
      body = l10n.shipmentOnTheRoadBody;
    } else {
      // Dispatched on paper but not yet picked up.
      color = scheme.onSurfaceVariant;
      icon = Icons.inventory_2_outlined;
      title = l10n.shipmentPreparingTitle;
      body = l10n.shipmentPreparingBody;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: scheme.onSurface)),
          if (shipment.hasUsableCode) ...[
            const SizedBox(height: 16),
            Text(
              l10n.shipmentCodeTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.45)),
              ),
              child: Text(
                shipment.proofCode!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.shipmentCodeBody,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  /// The escrow block — the reason a buyer trusts paying a stranger in-app.
  Widget _escrowCard(AppLocalizations l10n, api.Order order) {
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String body;

    final scheme = Theme.of(context).colorScheme;

    if (order.isEscrowHeld) {
      // Money is in, and protected — the same promise the checkout banner makes.
      color = AppColors.success;
      icon = Icons.lock_outline;
      title = l10n.orderEscrowHeldTitle;
      body = l10n.orderEscrowHeldBody(order.displayTotal);
    } else if (order.isEscrowReleased && order.confirmedAt == null) {
      // Released without the buyer ever confirming: this shop doesn't use
      // escrow, so the money settled the moment they paid. Telling them "you
      // confirmed delivery" would credit them with a step they never took, on
      // the one screen where they are trying to work out what protects them.
      color = scheme.onSurfaceVariant;
      icon = Icons.payments_outlined;
      title = l10n.orderPaidDirectTitle;
      body = l10n.orderPaidDirectBody;
    } else if (order.isEscrowReleased) {
      color = scheme.primary;
      icon = Icons.task_alt;
      title = l10n.orderEscrowReleasedTitle;
      body = l10n.orderEscrowReleasedBody;
    } else if (order.isEscrowRefunded) {
      color = scheme.onSurfaceVariant;
      icon = Icons.undo;
      title = l10n.orderEscrowRefundedTitle;
      body = l10n.orderEscrowRefundedBody;
    } else {
      // Nothing charged yet: an amber "waiting on you", never a green all-clear.
      color = AppColors.warning;
      icon = Icons.hourglass_empty;
      title = l10n.orderEscrowPendingTitle;
      body = l10n.orderEscrowPendingBody;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // A 6% wash vanishes on the dark ground; 12% reads on both.
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
          // Nobody's money sits in limbo forever — say when it moves on its own.
          if (order.isEscrowHeld && order.autoReleaseAt != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.orderEscrowAutoRelease(_formatDate(order.autoReleaseAt)),
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemsCard(AppLocalizations l10n, api.Order order) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.orderDetailItems,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final item in order.items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.titleSnapshot,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${l10n.orderDetailQuantity(item.quantity)} · ${item.displayUnitPrice}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(item.displayLineTotal,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );

  Widget _deliveryCard(AppLocalizations l10n, api.Order order) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.orderDetailDelivery,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(Icons.person_outline, order.deliveryName),
            _infoRow(Icons.phone_outlined, order.deliveryPhone),
            _infoRow(Icons.location_on_outlined, order.deliveryAddress),
            _infoRow(Icons.location_city_outlined, order.deliveryCity),
          ],
        ),
      );

  Widget _infoRow(IconData icon, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _noteCard(AppLocalizations l10n, api.Order order) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.orderDetailNote,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(order.note!, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ),
      );

  Widget _totalsCard(AppLocalizations l10n, api.Order order) => _card(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.orderDetailSubtotal,
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
                Text(order.displaySubtotal,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.orderDetailTotal,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                Text(
                  order.displayTotal,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      );

  /// Only ever one primary action: release the money, or pay/cancel before any
  /// has moved.
  Widget? _actions(AppLocalizations l10n, api.Order order) {
    final scheme = Theme.of(context).colorScheme;
    final buttons = <Widget>[];

    if (order.canConfirm) {
      buttons.add(
        ElevatedButton.icon(
          // Releasing the money is a success action, so it keeps the green even
          // where the brand CTA would otherwise be lime/black.
          onPressed: _busy ? null : () => _confirmDelivery(order),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          icon: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(l10n.orderConfirmDelivery,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }

    if (order.canCancel) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: _busy ? null : () => _pay(order),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            minimumSize: const Size(double.infinity, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          icon: const Icon(Icons.lock_outline),
          label: Text(l10n.orderPayNow,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _cancelOrder(order),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          icon: const Icon(Icons.close),
          label: Text(l10n.orderCancel),
        ),
      );
    }

    if (buttons.isEmpty) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Wallet + number picker used when paying an order that is still unpaid.
class _PaySheet extends StatefulWidget {
  final String initialPhone;

  const _PaySheet({required this.initialPhone});

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late final TextEditingController _phoneController =
      TextEditingController(text: widget.initialPhone);
  String _method = 'mtn_momo';
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.checkoutPaymentTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          RadioListTile<String>(
            value: 'mtn_momo',
            groupValue: _method,
            onChanged: (v) => setState(() => _method = v ?? _method),
            title: Text(l10n.checkoutMethodMtn),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            value: 'orange_money',
            groupValue: _method,
            onChanged: (v) => setState(() => _method = v ?? _method),
            title: Text(l10n.checkoutMethodOrange),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.checkoutMomoLabel,
              helperText: l10n.checkoutMomoHelper,
              helperMaxLines: 2,
              errorText: _error,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final phone = _phoneController.text.trim();
                if (phone.isEmpty) {
                  setState(() => _error = l10n.checkoutMomoRequired);
                  return;
                }
                Navigator.pop(context, (method: _method, phone: phone));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l10n.orderPayNow,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
