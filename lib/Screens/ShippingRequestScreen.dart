import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../Components/listing_picker.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../Service/ChatRoomScreen.dart';
import 'ShipmentConfirmedScreen.dart';
import '../api/auth_service.dart';
import '../api/repositories.dart';
import '../api/shipping_draft.dart';
import '../api/shipping_model.dart';
import '../api/shipping_repository.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// "Ship this for me."
class ShippingRequestScreen extends StatefulWidget {
  const ShippingRequestScreen({super.key, this.initialListing});

  /// Pre-picked product, for arriving from somewhere that already has one.
  final Listing? initialListing;

  @override
  State<ShippingRequestScreen> createState() => _ShippingRequestScreenState();
}

class _ShippingRequestScreenState extends State<ShippingRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  final _url = TextEditingController();
  final _description = TextEditingController();
  final _sizeCustom = TextEditingController();
  final _fromOther = TextEditingController();
  final _toOther = TextEditingController();
  final _budget = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  final _pickupAddress = TextEditingController();
  final _pickupName = TextEditingController();
  final _pickupPhone = TextEditingController();

  // One key per field the form can scroll to, in the order they appear.
  final _keys = <ShippingField, GlobalKey>{
    for (final f in ShippingField.values) f: GlobalKey(),
  };

  ShippingSource? _source;
  Listing? _listing;
  String? _categorySlug;
  String _sizeCode = '';
  String _fromCode = '';
  String _toCode = '';
  final List<XFile> _photos = [];

  List<Category> _categories = const [];
  bool _submitting = false;

  ShippingStep _step = ShippingStep.route;

  /// How far they have been, so the header lets them tap back but not skip.
  ShippingStep _furthest = ShippingStep.route;

  ShippingQuote? _quote;
  bool _quoteLoading = false;
  bool _quoteFailed = false;

  /// `from|to|size` the current quote answers, so re-entering the step with
  /// nothing changed does not ask again.
  String? _quoteKey;
  String? _tier;

  @override
  void initState() {
    super.initState();
    if (widget.initialListing != null) _takeListing(widget.initialListing!);

    final profile = AuthService.instance.me.value?.profile;
    _name.text = profile?.displayName ?? '';
    _phone.text = profile?.phone ?? '';

    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [
      _url,
      _description,
      _sizeCustom,
      _fromOther,
      _toOther,
      _budget,
      _name,
      _phone,
      _address,
      _note,
      _pickupAddress,
      _pickupName,
      _pickupPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    await ShippingRepository.instance.loadOptions();
    try {
      final cats = await ListingsRepository.instance.categories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {
      // The category picker is the only thing that needs these, and it has its
      // own empty state. A shipping request is not worth failing over a list.
    }
    if (mounted) setState(() {});
  }

  ShippingOptions get _options => ShippingRepository.instance.options.value;

  /// The sizes for the chosen category, resolved leaf → parent → default.
  List<ShippingSize> get _sizes {
    final slug = _categorySlug;
    final parent = slug == null
        ? null
        : _categories.where((c) => c.slug == slug).firstOrNull?.parentSlug;
    return _options.sizesFor(slug, parentSlug: parent);
  }

  ShippingDraft get _draft => ShippingDraft(
    source: _source,
    listing: _listing,
    productUrl: _url.text,
    description: _description.text,
    categorySlug: _categorySlug ?? '',
    sizeCode: _sizeCode,
    sizeCustom: _sizeCustom.text,
    categoryHasPresets: _sizes.isNotEmpty,
    fromLocation: _fromLocation,
    toLocation: _toLocation,
    contactPhone: _phone.text,
    estimatedValue: _budget.text,
  );

  String get _fromLocation => _fromCode == 'other'
      ? _fromOther.text.trim()
      : _placeLabel(_options.from, _fromCode);
  String get _toLocation => _toCode == 'other'
      ? _toOther.text.trim()
      : _placeLabel(_options.to, _toCode);

  String _placeLabel(List<ShippingPlace> places, String code) {
    if (code.isEmpty) return '';
    for (final place in places) {
      if (place.code == code) return place.storedLabel;
    }
    return code;
  }

  void _takeListing(Listing listing) {
    _listing = listing;
    _source = ShippingSource.mambanda;
    _categorySlug ??= listing.categorySlug;
    final city = (listing.city ?? '').trim();
    if (_fromCode.isEmpty && city.isNotEmpty) {
      final match = _options.from
          .where(
            (p) => p.label.values.any(
              (l) => l.trim().toLowerCase() == city.toLowerCase(),
            ),
          )
          .firstOrNull;
      if (match != null) {
        _fromCode = match.code;
      } else {
        _fromCode = 'other';
        _fromOther.text = city;
      }
    }
  }

  Future<void> _pickListing() async {
    final chosen = await showListingPicker(context);
    if (chosen == null || !mounted) return;
    setState(() {
      _sizeCode = '';
      _takeListing(chosen);
    });
  }

  Future<void> _addPhotos() async {
    if (_photos.length >= 6) {
      _toast(context.l10n.shipPhotoLimit);
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.l10n.createTakePhotoWithCamera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.createChooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    if (source == ImageSource.camera) {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (shot != null && mounted) setState(() => _photos.add(shot));
      return;
    }
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() => _photos.addAll(picked.take(6 - _photos.length)));
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  void _revealFirstMissing() {
    final first = _draft.missingIn(_step).firstOrNull;
    if (first == null) return;
    final ctx = _keys[first]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.2,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _goTo(ShippingStep step) {
    setState(() {
      _step = step;
      if (step.index > _furthest.index) _furthest = step;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (step == ShippingStep.quote) _fetchQuote();
  }

  void _next() {
    _formKey.currentState?.validate();
    // For testing purposes, validation is commented out except for critical DB fields.
    if (_step == ShippingStep.route && _categorySlug == null) {
      _toast('Please select a category below', error: true);
      return;
    }

    /*
    final missing = _draft.missingIn(_step);
    if (missing.isNotEmpty) {
      _toast(context.l10n.shipFixFields, error: true);
      _revealFirstMissing();
      return;
    }
    */
    if (_step == ShippingStep.confirm) {
      _submit();
      return;
    }
    _goTo(ShippingStep.values[_step.index + 1]);
  }

  void _back() {
    if (_step == ShippingStep.route) {
      Navigator.maybePop(context);
      return;
    }
    _goTo(ShippingStep.values[_step.index - 1]);
  }

  bool get _canQuote =>
      _fromCode.isNotEmpty &&
      _fromCode != 'other' &&
      _toCode.isNotEmpty &&
      _toCode != 'other' &&
      _sizeCode.isNotEmpty &&
      _sizeCode != ShippingDraft.customSize;

  Future<void> _fetchQuote({bool force = false}) async {
    if (!_canQuote) {
      setState(() {
        _quote = ShippingQuote.manual;
        _quoteKey = null;
        _tier = null;
      });
      return;
    }
    final key = '$_fromCode|$_toCode|$_sizeCode';
    if (!force && key == _quoteKey && _quote != null) return;
    setState(() {
      _quoteLoading = true;
      _quoteFailed = false;
    });
    try {
      final q = await ShippingRepository.instance.quote(
        fromPlace: _fromCode,
        toPlace: _toCode,
        sizeKey: _sizeCode,
      );
      if (!mounted) return;
      setState(() {
        _quote = q;
        _quoteKey = key;
        _quoteLoading = false;
        _tier = q.options.any((o) => o.tier == _tier)
            ? _tier
            : q.cheapest?.tier;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quoteLoading = false;
        _quoteFailed = true;
        _quote = null;
        _quoteKey = null;
        _tier = null;
      });
    }
  }

  ShippingQuoteOption? get _selected =>
      _quote?.options.where((o) => o.tier == _tier).firstOrNull;

  bool get _isQuoted => _quote?.quotable == true && _selected != null;

  Future<void> _submit() async {
    if (_submitting) return;
    _formKey.currentState?.validate();
    // For testing purposes, validation is commented out.
    /*
    if (!_draft.isReady) {
      _toast(context.l10n.shipFixFields, error: true);
      _revealFirstMissing();
      return;
    }
    */

    setState(() => _submitting = true);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode == 'fr'
        ? 'fr'
        : 'en';

    try {
      final paths = <String>[];
      for (final photo in _photos) {
        paths.add(await ListingsRepository.instance.uploadChatFile(photo));
      }

      final result = await ShippingRepository.instance.create(
        source: _source == ShippingSource.mambanda ? 'mambanda' : 'external',
        listingId: _listing?.id,
        itemTitle: _listing?.title,
        productUrl: _url.text.trim(),
        description: _description.text.trim(),
        categorySlug: _categorySlug ?? 'verschenken',
        sizeKey: _sizeCode.isEmpty ? ShippingDraft.customSize : _sizeCode,
        sizeCustom: _sizeCode == ShippingDraft.customSize || _sizeCode.isEmpty
            ? (_sizeCustom.text.trim().isEmpty
                  ? l10n.shipSizeNoPresets
                  : _sizeCustom.text.trim())
            : null,
        budgetCents: _budget.text.trim().isEmpty
            ? null
            : toMinorUnits(num.tryParse(_budget.text.trim()) ?? 0),
        fromLocation: _fromLocation,
        toLocation: _toLocation,
        fromPlace: _fromCode == 'other' ? null : _fromCode,
        toPlace: _toCode == 'other' ? null : _toCode,
        tier: _isQuoted ? _tier : null,
        contactName: _name.text.trim(),
        contactPhone: _phone.text.trim(),
        deliveryAddress: _address.text.trim(),
        pickupAddress: _pickupAddress.text.trim(),
        pickupContactName: _pickupName.text.trim(),
        pickupPhone: _pickupPhone.text.trim(),
        note: _note.text.trim(),
        photoPaths: paths,
        locale: locale,
      );

      if (!mounted) return;
      await ChatRepository.instance.refresh();
      unawaited(ShippingRepository.instance.refreshMine());
      if (!mounted) return;
      final request = result.request;
      final thread = result.conversation;
      if (request != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ShipmentConfirmedScreen(request: request, conversation: thread),
          ),
        );
      } else if (thread != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(conversation: thread),
          ),
        );
        _toast(l10n.shipCreated);
      } else {
        Navigator.pop(context);
        _toast(l10n.shipCreated);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(switch (e.code) {
        'shipping_unavailable' => l10n.shipUnavailable,
        'rate_limited' => l10n.shipTooMany,
        'listing_unavailable' => l10n.shipListingGone,
        _ => e.message,
      }, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(l10n.shipFailed, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: _step == ShippingStep.route,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            l10n.shipTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _StepHeader(current: _step, furthest: _furthest, onTap: _goTo),
              const SizedBox(height: 18),
              ..._stepBody(),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_step != ShippingStep.route) ...[
                  OutlinedButton(
                    onPressed: _submitting ? null : _back,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(l10n.shipBack),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _next,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _step != ShippingStep.confirm
                                ? l10n.shipContinue
                                : _isQuoted
                                    ? l10n.shipConfirmRequest
                                    : l10n.shipSubmit,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _stepBody() {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    switch (_step) {
      case ShippingStep.route:
        return [
          const Text(
            'Where are you shipping from and to?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _SectionTitle('From'),
          const SizedBox(height: 10),
          ..._fromPlaceFields(),
          const SizedBox(height: 24),
          _SectionTitle('To'),
          const SizedBox(height: 10),
          ..._toPlaceFields(),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {}, // Future: Geolocation
            icon: const Icon(Icons.gps_fixed, size: 18),
            label: const Text('Use my current location'),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            'What are you shipping?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _categoryIconsGrid(),
        ];

      case ShippingStep.item:
        return [
          const Text(
            'What\'s being shipped?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _chooser(),
          if (_source != null) ...[
            const SizedBox(height: 24),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: _field('Item Name / Description', hint: 'e.g. Smartphone'),
            ),
            const SizedBox(height: 24),
            _photoRail(),
            const SizedBox(height: 24),
            _SectionTitle('Estimated value (optional)'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _budget, // Using budget controller for value
              keyboardType: TextInputType.number,
              decoration: _field('Value (FCFA)', hint: 'e.g. 150,000'),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Additional note (optional)'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              maxLines: 3,
              decoration: _field('Note', hint: 'e.g. Handle with care, fragile...'),
            ),
          ],
        ];

      case ShippingStep.quote:
        final locale = Localizations.localeOf(context);
        if (_quoteLoading) {
          return [
            const SizedBox(height: 60),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Finding the best delivery\noptions...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'We\'re checking trusted couriers\nnear you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ];
        }

        final q = _quote;
        return [
          const Text(
            'Delivery Quote',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(_fromLocation, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 8),
                Icon(Icons.location_on, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(_toLocation, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (q == null || !q.quotable)
            const _ManualQuoteCardDesign()
          else ...[
            Text(
              '${q.options.length} couriers found 🟢',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (final o in q.options) ...[
              _TierCardDesign(
                option: o,
                locale: locale,
                currency: q.currency,
                selected: o.tier == _tier,
                onTap: () => setState(() => _tier = o.tier),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ];

      case ShippingStep.confirm:
        final chosen = _selected;
        return [
          const Text(
            'Review & Pay',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _AgentSummaryCard(
            from: _fromLocation,
            to: _toLocation,
            item: _listing?.title ?? _description.text,
            price: chosen != null ? formatPrice(chosen.priceCents) : null,
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Recipient'),
          const SizedBox(height: 12),
          _ContactSummaryCard(
            name: _name.text,
            phone: _phone.text,
            address: _address.text,
            onEdit: () {
              // Scroll to fields or show a dialog to edit
            },
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Payment method'),
          const SizedBox(height: 12),
          _PaymentMethodCard(onTap: () {}),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            decoration: _field('Recipient Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: _field('Recipient Phone'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            decoration: _field('Delivery Address'),
          ),
          const SizedBox(height: 24),
          const Text('Pickup Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pickupAddress,
            decoration: _field('Pickup Address'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pickupName,
            decoration: _field('Contact Person'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pickupPhone,
            keyboardType: TextInputType.phone,
            decoration: _field('Contact Phone'),
          ),
        ];
    }
  }

  Widget _categoryIconsGrid() {
    final cats = [
      ('elektronik', Icons.electrical_services, 'Electronics'),
      ('mode', Icons.checkroom, 'Fashion'),
      ('moebel', Icons.chair, 'Furniture'),
      ('verschenken', Icons.grid_view, 'Other'),
    ];

    return Row(
      children: cats.map((c) {
        final isSelected = _categorySlug == c.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _categorySlug = c.$1),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.lime : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(c.$2, color: isSelected ? Colors.black : null),
                ),
                const SizedBox(height: 8),
                Text(c.$3, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _chooser() {
    final l10n = context.l10n;
    if (_source == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PathCard(
            icon: Icons.storefront_outlined,
            title: l10n.shipPathMarketTitle,
            body: l10n.shipPathMarketBody,
            onTap: _pickListing,
          ),
          const SizedBox(height: 10),
          _PathCard(
            icon: Icons.link_rounded,
            title: l10n.shipPathOtherTitle,
            body: l10n.shipPathOtherBody,
            onTap: () => setState(() => _source = ShippingSource.external),
          ),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _source == ShippingSource.mambanda
                ? Icons.storefront_outlined
                : Icons.link_rounded,
            color: context.tokens.accentInk,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _listing?.title ??
                      (_source == ShippingSource.mambanda
                          ? l10n.shipPathMarketTitle
                          : l10n.shipPathOtherTitle),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (_listing != null)
                  Text(
                    _listing!.displayPrice,
                    style: TextStyle(
                      color: context.tokens.accentInk,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _source = null;
              _listing = null;
              _sizeCode = '';
            }),
            child: Text(l10n.shipChange),
          ),
        ],
      ),
    );
  }

  Widget _photoRail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add photos (up to 6)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: _addPhotos,
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined),
                ),
              ),
              for (var i = 0; i < _photos.length; i++)
                Stack(
                  children: [
                    Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(
                        File(_photos[i].path),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _fromPlaceFields() {
    final locale = Localizations.localeOf(context);
    return [
      _placeDropdown(
        label: 'Select City',
        places: _options.from,
        selected: _fromCode,
        locale: locale,
        onPick: (code) => setState(() => _fromCode = code),
      ),
      if (_fromCode == 'other') ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _fromOther,
          onChanged: (_) => setState(() {}),
          decoration: _field('Type your city'),
        ),
      ],
    ];
  }

  List<Widget> _toPlaceFields() {
    final locale = Localizations.localeOf(context);
    return [
      _placeDropdown(
        label: 'Select City',
        places: _options.to,
        selected: _toCode,
        locale: locale,
        onPick: (code) => setState(() => _toCode = code),
      ),
      if (_toCode == 'other') ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _toOther,
          onChanged: (_) => setState(() {}),
          decoration: _field('Type your city'),
        ),
      ],
    ];
  }

  Widget _placeDropdown({
    required String label,
    required List<ShippingPlace> places,
    required String selected,
    required Locale locale,
    required void Function(String code) onPick,
  }) {
    return _SearchableDropdown(
      label: label,
      selected: selected,
      entries: [
        for (final place in places) (place.code, place.labelFor(locale)),
      ],
      onPick: onPick,
    );
  }

  InputDecoration _field(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.current,
    required this.furthest,
    required this.onTap,
  });

  final ShippingStep current;
  final ShippingStep furthest;
  final void Function(ShippingStep) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final labels = {
      ShippingStep.route: 'Location',
      ShippingStep.item: 'Item',
      ShippingStep.quote: 'Quote',
      ShippingStep.confirm: 'Confirm',
    };
    return Row(
      children: [
        for (final step in ShippingStep.values) ...[
          if (step != ShippingStep.route)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: step.index <= current.index ? tokens.accentFill : scheme.outlineVariant,
              ),
            ),
          GestureDetector(
            onTap: step.index <= furthest.index && step != current ? () => onTap(step) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.index <= current.index ? tokens.accentFill : scheme.surfaceVariant,
                    border: step == current ? Border.all(color: tokens.accentInk, width: 2) : null,
                  ),
                  alignment: Alignment.center,
                  child: step.index < current.index
                      ? Icon(Icons.check, size: 14, color: tokens.onAccentFill)
                      : Text(
                          '${step.index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: step.index <= current.index ? tokens.onAccentFill : scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[step]!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: step == current ? FontWeight.bold : FontWeight.normal,
                    color: step == current ? tokens.accentInk : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceVariant.withOpacity(0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 24, color: context.tokens.accentInk),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(body, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
}

class _SearchableDropdown extends StatefulWidget {
  const _SearchableDropdown({
    required this.label,
    required this.selected,
    required this.entries,
    required this.onPick,
    this.hint,
  });

  final String label;
  final String? hint;
  final String selected;
  final List<(String, String)> entries;
  final void Function(String code) onPick;

  @override
  State<_SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<_SearchableDropdown> {
  late final TextEditingController _text = TextEditingController(text: _labelFor(widget.selected));
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        final label = _labelFor(widget.selected);
        if (label.isNotEmpty && _text.text != label) _text.text = label;
      }
    });
  }

  String _labelFor(String code) {
    for (final (value, label) in widget.entries) {
      if (value == code) return label;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      controller: _text,
      focusNode: _focus,
      initialSelection: widget.selected.isEmpty ? null : widget.selected,
      enableFilter: true,
      expandedInsets: EdgeInsets.zero,
      label: Text(widget.label),
      dropdownMenuEntries: [
        for (final (value, label) in widget.entries) DropdownMenuEntry(value: value, label: label),
      ],
      onSelected: (code) {
        if (code != null) widget.onPick(code);
      },
    );
  }
}

class _TierCardDesign extends StatelessWidget {
  const _TierCardDesign({
    required this.option,
    required this.locale,
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final ShippingQuoteOption option;
  final Locale locale;
  final String currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFastest = option.tier == 'express' || option.tier == 'fastest';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? scheme.primary : Colors.green.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            if (isFastest)
              const Icon(Icons.bolt, color: Colors.green)
            else if (option.tier == 'economy')
              const Icon(Icons.inventory_2, color: Colors.blue)
            else
              const Icon(Icons.star_border, color: Colors.orange),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isFastest)
                    const Text('FASTEST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.green)),
                  Text(option.labelFor(locale), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${option.etaDaysMin}-${option.etaDaysMax} days', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPrice(option.priceCents), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Mabanda Express', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 12),
            Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? scheme.primary : scheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

class _AgentSummaryCard extends StatelessWidget {
  final String from;
  final String to;
  final String item;
  final String? price;

  const _AgentSummaryCard({required this.from, required this.to, required this.item, this.price});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your shipment', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('$from → $to', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              if (price != null)
                Text(price!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const Divider(height: 32),
          _row('Delivery fee', price ?? '—'),
          const SizedBox(height: 8),
          _row('Service fee', 'FCFA 500'),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(price ?? '—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: scheme.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ],
  );
}

class _ContactSummaryCard extends StatelessWidget {
  final String name;
  final String phone;
  final String address;
  final VoidCallback onEdit;

  const _ContactSummaryCard({required this.name, required this.phone, required this.address, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.black12,
            child: Icon(Icons.person, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(phone, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                Text(address, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PaymentMethodCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Colors.orange),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mobile Money', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('MTN / Orange', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('Change')),
        ],
      ),
    );
  }
}

class _ManualQuoteCardDesign extends StatelessWidget {
  const _ManualQuoteCardDesign();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, size: 28, color: context.tokens.accentInk),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Manual Quote Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Our agent will contact you in chat with the best price for this route.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
