import 'package:flutter/material.dart';

import '../Components/order_status_chip.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';

/// Label for a ledger movement. Unknown kinds fall back to a neutral
/// "Adjustment" rather than leaking a raw database enum at the merchant.
String _entryLabel(AppLocalizations l10n, api.WalletEntry entry) {
  final described = entry.description;
  if (described != null && described.isNotEmpty) return described;
  return switch (entry.kind) {
    'escrow_hold' => l10n.walletKindEscrowHold,
    'escrow_release' => l10n.walletKindEscrowRelease,
    'commission' => l10n.walletKindCommission,
    'payout' => l10n.walletKindPayout,
    'refund' => l10n.walletKindRefund,
    'sale' => l10n.walletKindSale,
    _ => l10n.walletKindOther,
  };
}

String _payoutMethodLabel(AppLocalizations l10n, String method) =>
    switch (method) {
      'mtn_momo' => l10n.payoutMethodMtn,
      'orange_money' => l10n.payoutMethodOrange,
      'bank' => l10n.payoutMethodBank,
      _ => method,
    };

/// Home for a verified company: incoming orders, the wallet, and payouts.
///
/// The wallet is the delicate part. A company's escrow-held money is *not*
/// theirs yet — it belongs to buyers until they confirm delivery — so the two
/// figures are rendered as visually distinct cards and only the available
/// balance is ever offered for withdrawal.
class CompanyDashboardScreen extends StatefulWidget {
  const CompanyDashboardScreen({super.key});

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<api.Order> _orders = [];
  String? _nextBefore;
  bool _ordersLoading = true;
  bool _ordersLoadingMore = false;
  String? _ordersError;

  api.WalletSummary? _wallet;
  final List<api.WalletEntry> _entries = [];
  bool _walletLoading = true;
  String? _walletError;

  final List<api.Payout> _payouts = [];
  bool _payoutsLoading = true;
  String? _payoutsError;

  bool _busy = false;

  // Loads start from initState, where localizing isn't safe; these sentinels
  // are turned into text at build time. API messages are stored verbatim.
  static const String _kSignInError = '__company_dash_sign_in__';
  static const String _kLoadError = '__company_dash_load__';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() =>
      Future.wait([_loadOrders(), _loadWallet(), _loadPayouts()]);

  Future<void> _loadOrders() async {
    if (AuthService.instance.session == null) {
      setState(() {
        _ordersLoading = false;
        _ordersError = _kSignInError;
      });
      return;
    }
    setState(() {
      _ordersLoading = true;
      _ordersError = null;
    });
    try {
      final page = await OrdersRepository.instance.list(role: 'company');
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(page.items);
        _nextBefore = page.nextBefore;
        _ordersLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _ordersError = e.isUnauthorized ? _kSignInError : e.message;
        _ordersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ordersError = _kLoadError;
        _ordersLoading = false;
      });
    }
  }

  Future<void> _loadMoreOrders() async {
    final before = _nextBefore;
    if (before == null || _ordersLoadingMore) return;
    setState(() => _ordersLoadingMore = true);
    try {
      final page =
          await OrdersRepository.instance.list(role: 'company', before: before);
      if (!mounted) return;
      setState(() {
        _orders.addAll(page.items);
        _nextBefore = page.nextBefore;
        _ordersLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _ordersLoadingMore = false);
    }
  }

  Future<void> _loadWallet() async {
    setState(() {
      _walletLoading = true;
      _walletError = null;
    });
    try {
      final results = await Future.wait([
        WalletRepository.instance.summary(),
        WalletRepository.instance.entries(),
      ]);
      if (!mounted) return;
      final entries =
          results[1] as ({List<api.WalletEntry> items, String? nextBefore});
      setState(() {
        _wallet = results[0] as api.WalletSummary;
        _entries
          ..clear()
          ..addAll(entries.items);
        _walletLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _walletError = e.isUnauthorized ? _kSignInError : e.message;
        _walletLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _walletError = _kLoadError;
        _walletLoading = false;
      });
    }
  }

  Future<void> _loadPayouts() async {
    setState(() {
      _payoutsLoading = true;
      _payoutsError = null;
    });
    try {
      final items = await WalletRepository.instance.payouts();
      if (!mounted) return;
      setState(() {
        _payouts
          ..clear()
          ..addAll(items);
        _payoutsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _payoutsError = e.isUnauthorized ? _kSignInError : e.message;
        _payoutsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _payoutsError = _kLoadError;
        _payoutsLoading = false;
      });
    }
  }

  Future<void> _markFulfilled(api.Order order) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.companyDashFulfilTitle),
        content: Text(l10n.companyDashFulfilBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.companyDashFulfilCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.companyDashFulfilConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await OrdersRepository.instance.fulfil(order.id);
      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.companyDashFulfilledSuccess),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.orderActionFailed),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPayout() async {
    final l10n = context.l10n;
    final wallet = _wallet;
    if (wallet == null) return;

    final request = await showModalBottomSheet<_PayoutRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PayoutSheet(wallet: wallet),
    );
    if (request == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await WalletRepository.instance.requestPayout(
        amountCents: request.amountCents,
        method: request.method,
        destination: request.destination,
        destinationName: request.destinationName,
      );
      await Future.wait([_loadWallet(), _loadPayouts()]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.payoutRequested),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.payoutError),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.companyDashboard,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: l10n.sellerDashHomeTooltip,
            icon: const Icon(Icons.home_outlined),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, '/home', (route) => false),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: theme.primaryColor,
          indicatorWeight: 3,
          tabs: [
            Tab(text: l10n.companyDashOrdersTab),
            Tab(text: l10n.companyDashWalletTab),
            Tab(text: l10n.companyDashPayoutsTab),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _ordersTab(l10n),
            _walletTab(l10n),
            _payoutsTab(l10n),
          ],
        ),
      ),
    );
  }

  // --- SHARED STATES ---

  Widget _errorState(String message, Future<void> Function() retry, String retryLabel) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 44, color: Colors.grey),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: retry, child: Text(retryLabel)),
            ],
          ),
        ),
      );

  String _resolve(AppLocalizations l10n, String error, String fallback) =>
      error == _kSignInError
          ? l10n.companyDashSignInRequired
          : error == _kLoadError
              ? fallback
              : error;

  // --- ORDERS ---

  Widget _ordersTab(AppLocalizations l10n) {
    if (_ordersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ordersError != null) {
      return _errorState(
        _resolve(l10n, _ordersError!, l10n.companyDashOrdersLoadError),
        _loadOrders,
        l10n.ordersTryAgain,
      );
    }
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadOrders,
        // Always scrollable so pull-to-refresh survives an empty list.
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(l10n.companyDashNoOrders,
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length + (_nextBefore == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (index >= _orders.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: _ordersLoadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: _loadMoreOrders,
                        child: Text(l10n.ordersLoadMore),
                      ),
              ),
            );
          }
          return _orderCard(l10n, _orders[index]);
        },
      ),
    );
  }

  Widget _orderCard(AppLocalizations l10n, api.Order order) {
    final ml = MaterialLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.reference,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${l10n.orderDetailQuantity(item.quantity)} · ${item.titleSnapshot}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          const SizedBox(height: 4),
          if (order.deliveryName != null && order.deliveryName!.isNotEmpty)
            Text(
              l10n.companyDashDeliverTo(order.deliveryName!),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          if (order.deliveryAddress != null &&
              order.deliveryAddress!.isNotEmpty)
            Text(
              '${order.deliveryAddress}${order.deliveryCity == null ? '' : ', ${order.deliveryCity}'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          if (order.createdAt != null)
            Text(
              l10n.ordersPlacedOn(ml.formatMediumDate(order.createdAt!.toLocal())),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Money the company hasn't earned yet reads as held, never as
              // revenue in hand.
              if (order.isEscrowHeld)
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 14, color: Colors.amber.shade800),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          l10n.walletEscrowTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800,
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
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.indigo),
              ),
            ],
          ),
          if (order.canFulfil) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _markFulfilled(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text(l10n.companyDashMarkFulfilled),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- WALLET ---

  Widget _walletTab(AppLocalizations l10n) {
    if (_walletLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_walletError != null) {
      return _errorState(
        _resolve(l10n, _walletError!, l10n.walletLoadError),
        _loadWallet,
        l10n.ordersTryAgain,
      );
    }
    final wallet = _wallet ?? const api.WalletSummary();

    return RefreshIndicator(
      onRefresh: _loadWallet,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _balanceCard(
            title: l10n.walletAvailableTitle,
            hint: l10n.walletAvailableHint,
            amount: wallet.displayBalance,
            color: Colors.green.shade700,
            icon: Icons.account_balance_wallet_outlined,
            filled: true,
          ),
          const SizedBox(height: 12),
          _balanceCard(
            title: l10n.walletEscrowTitle,
            hint: l10n.walletEscrowHint,
            amount: wallet.displayEscrowHeld,
            color: Colors.amber.shade800,
            icon: Icons.lock_outline,
            filled: false,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (_busy || wallet.balanceCents <= 0) ? null : _requestPayout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.payments_outlined),
              label: Text(l10n.payoutRequestCta,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.walletLedgerTitle,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(l10n.walletNoEntries,
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            )
          else
            for (final entry in _entries) _entryTile(l10n, entry),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The available balance is filled and green; escrow is outlined and amber
  /// with a lock, so the two can never be mistaken for one another.
  Widget _balanceCard({
    required String title,
    required String hint,
    required String amount,
    required Color color,
    required IconData icon,
    required bool filled,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: filled ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? color.withOpacity(0.35) : color.withOpacity(0.5),
            width: filled ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: filled ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: filled ? Colors.black87 : color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(hint,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _entryTile(AppLocalizations l10n, api.WalletEntry entry) {
    final ml = MaterialLocalizations.of(context);
    final color = entry.isCredit ? Colors.green.shade700 : Colors.red.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_entryLabel(l10n, entry),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (entry.createdAt != null)
                      ml.formatMediumDate(entry.createdAt!.toLocal()),
                    if (entry.orderId != null && entry.orderId!.isNotEmpty)
                      l10n.walletOrderRef(_shortRef(entry.orderId!)),
                  ].join(' · '),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            entry.displayAmount,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  /// Same short form the buyer sees on their order, so support can match them.
  String _shortRef(String id) {
    final compact = id.replaceAll('-', '').toUpperCase();
    return '#${compact.length <= 8 ? compact : compact.substring(0, 8)}';
  }

  // --- PAYOUTS ---

  Widget _payoutsTab(AppLocalizations l10n) {
    if (_payoutsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_payoutsError != null) {
      return _errorState(
        _resolve(l10n, _payoutsError!, l10n.payoutsLoadError),
        _loadPayouts,
        l10n.ordersTryAgain,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPayouts,
      child: _payouts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Text(l10n.payoutsEmpty,
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _payouts.length,
              itemBuilder: (context, index) =>
                  _payoutTile(l10n, _payouts[index]),
            ),
    );
  }

  Widget _payoutTile(AppLocalizations l10n, api.Payout payout) {
    final ml = MaterialLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payout.displayAmount,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${_payoutMethodLabel(l10n, payout.method)} · ${payout.destination}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (payout.createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.payoutRequestedOn(
                        ml.formatMediumDate(payout.createdAt!.toLocal())),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          StatusChip(status: payout.status, isPayout: true),
        ],
      ),
    );
  }
}

/// What the payout sheet hands back once the merchant has filled it in.
class _PayoutRequest {
  final int amountCents;
  final String method;
  final String destination;
  final String? destinationName;

  const _PayoutRequest({
    required this.amountCents,
    required this.method,
    required this.destination,
    this.destinationName,
  });
}

class _PayoutSheet extends StatefulWidget {
  final api.WalletSummary wallet;

  const _PayoutSheet({required this.wallet});

  @override
  State<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<_PayoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _destinationController = TextEditingController();
  final _destinationNameController = TextEditingController();
  String _method = 'mtn_momo';

  @override
  void dispose() {
    _amountController.dispose();
    _destinationController.dispose();
    _destinationNameController.dispose();
    super.dispose();
  }

  /// FCFA has no minor unit, so what the merchant types *is* the minor amount.
  /// Never scale it by 100 — that would ask for 100x the money.
  int? _parseAmount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s.,]'), '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wallet = widget.wallet;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.payoutRequestTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                l10n.payoutAvailableNote(wallet.displayBalance),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.payoutAmountLabel,
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.payoutAmountRequired;
                  }
                  final amount = _parseAmount(v);
                  if (amount == null || amount <= 0) {
                    return l10n.payoutAmountInvalid;
                  }
                  // The server re-checks; this is here so the merchant finds
                  // out before a round-trip.
                  if (amount > wallet.balanceCents) {
                    return l10n.payoutAmountTooHigh(wallet.displayBalance);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(l10n.payoutMethodLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in {
                    'mtn_momo': l10n.payoutMethodMtn,
                    'orange_money': l10n.payoutMethodOrange,
                    'bank': l10n.payoutMethodBank,
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _method == entry.key,
                      onSelected: (_) => setState(() => _method = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _destinationController,
                decoration: InputDecoration(
                  labelText: l10n.payoutDestinationLabel,
                  prefixIcon: const Icon(Icons.account_balance_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.payoutDestinationRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destinationNameController,
                decoration: InputDecoration(
                  labelText: l10n.payoutDestinationNameLabel,
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    final amount = _parseAmount(_amountController.text);
                    if (amount == null) return;
                    Navigator.pop(
                      context,
                      _PayoutRequest(
                        amountCents: amount,
                        method: _method,
                        destination: _destinationController.text.trim(),
                        destinationName: _destinationNameController.text.trim(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.payoutSubmit,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
