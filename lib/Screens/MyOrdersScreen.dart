import 'package:flutter/material.dart';

import '../Components/order_status_chip.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'OrderDetailScreen.dart';

/// The buyer's purchases. Cursor-paged the same way the chat history is, so a
/// long history never loads in one go.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final List<api.Order> _orders = [];
  String? _nextBefore;
  bool _loading = true;
  bool _loadingMore = false;

  // Set from a load that ran without a BuildContext safe to localize; `_message`
  // turns these into text at build time. API errors are stored verbatim.
  static const String _kSignInError = '__orders_sign_in__';
  static const String _kLoadError = '__orders_load__';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (AuthService.instance.session == null) {
      setState(() {
        _loading = false;
        _error = _kSignInError;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await OrdersRepository.instance.list(role: 'buyer');
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(page.items);
        _nextBefore = page.nextBefore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isUnauthorized ? _kSignInError : e.message;
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

  Future<void> _loadMore() async {
    final before = _nextBefore;
    if (before == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page =
          await OrdersRepository.instance.list(role: 'buyer', before: before);
      if (!mounted) return;
      setState(() {
        _orders.addAll(page.items);
        _nextBefore = page.nextBefore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _message(AppLocalizations l10n) => _error == _kSignInError
      ? l10n.ordersSignInRequired
      : _error == _kLoadError
          ? l10n.ordersLoadError
          : (_error ?? l10n.ordersLoadError);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ordersTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, size: 44, color: muted),
                          const SizedBox(height: 12),
                          Text(_message(l10n),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted)),
                          const SizedBox(height: 16),
                          OutlinedButton(
                              onPressed: _load,
                              child: Text(l10n.ordersTryAgain)),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _orders.isEmpty
                        // Always scrollable so pull-to-refresh still works on
                        // a screen with nothing on it.
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Icon(Icons.receipt_long_outlined,
                                  size: 56, color: muted),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  l10n.ordersEmpty,
                                  style: TextStyle(color: muted),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _orders.length +
                                (_nextBefore == null ? 0 : 1),
                            itemBuilder: (context, index) {
                              if (index >= _orders.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Center(
                                    child: _loadingMore
                                        ? const CircularProgressIndicator()
                                        : OutlinedButton(
                                            onPressed: _loadMore,
                                            child: Text(l10n.ordersLoadMore),
                                          ),
                                  ),
                                );
                              }
                              return _orderTile(l10n, _orders[index]);
                            },
                          ),
                  ),
      ),
    );
  }

  Widget _orderTile(AppLocalizations l10n, api.Order order) {
    final ml = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final title = order.items.isEmpty
        ? order.reference
        : order.items.first.titleSnapshot;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: order.id),
            ),
          );
          // Confirming delivery or cancelling changes the row, so re-read.
          await _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${order.reference} · ${l10n.ordersItemCount(order.itemCount)}',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              if (order.createdAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.ordersPlacedOn(
                      ml.formatMediumDate(order.createdAt!.toLocal())),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  // Escrow state, so the buyer can see at a glance which orders
                  // still need their confirmation.
                  if (order.isEscrowHeld)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.orderEscrowHeldTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  Text(
                    order.displayTotal,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
