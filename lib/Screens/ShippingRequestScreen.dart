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
///
/// A pushed screen rather than a sheet: there are photos, a keyboard and two
/// nested modal pickers here, and a sheet holding a sheet is where that comes
/// apart.
///
/// Four steps — item, route, price, confirm — over one form and one draft.
/// The steps are how the same fields are dealt out, not a second model: every
/// field belongs to exactly one step (a test holds that), so "may I continue"
/// is [ShippingDraft.missingIn] and nothing else.
///
/// Item first rather than the mockup's location-first, deliberately: the form
/// hangs off the source chooser, a listing that arrives pre-picked already
/// answers the item, size depends on category, and "link or description" is
/// one requirement in the draft — so the description must sit with the item
/// or a request with no link could never leave the first step.
///
/// Until somebody has said whether this is a product from here or something
/// else, the first step shows exactly two cards and nothing else — a wall of
/// ten fields is how you lose somebody on the first screen of a feature they
/// have never used.
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

  ShippingStep _step = ShippingStep.item;

  /// How far they have been, so the header lets them tap back but not skip.
  ShippingStep _furthest = ShippingStep.item;

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
  );

  // The label, not the code. These columns are free text either way — the
  // "somewhere else" path has always written prose into them — and the desk
  // reads them raw in the queue, where "douala-akwa" and "cn" are worse than
  // useless once there are forty-six of them.
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
    // A code the catalogue no longer carries. The code itself is still a
    // truthful answer, and refusing to submit over it would not be.
    return code;
  }

  void _takeListing(Listing listing) {
    _listing = listing;
    _source = ShippingSource.mambanda;
    // The listing already answers these; leave them editable but filled.
    _categorySlug ??= listing.categorySlug;
    final city = (listing.city ?? '').trim();
    if (_fromCode.isEmpty && city.isNotEmpty) {
      // A city that is a place in the catalogue is a route we can price;
      // "somewhere else" with the city typed in is one the desk quotes.
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

  /// Scroll to the first thing still missing, rather than naming it in a
  /// snackbar and leaving them to hunt for it.
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

  // ── Steps ──────────────────────────────────────────────────────────────────

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
    final missing = _draft.missingIn(_step);
    if (missing.isNotEmpty) {
      _toast(context.l10n.shipFixFields, error: true);
      _revealFirstMissing();
      return;
    }
    if (_step == ShippingStep.confirm) {
      _submit();
      return;
    }
    _goTo(ShippingStep.values[_step.index + 1]);
  }

  void _back() {
    if (_step == ShippingStep.item) {
      Navigator.maybePop(context);
      return;
    }
    _goTo(ShippingStep.values[_step.index - 1]);
  }

  /// Whether the catalogue could even be asked. "Somewhere else" on either end
  /// or a size of "other" is the desk's to price, and asking would only round
  /// trip to be told so.
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
        // Keep their pick if it is still on offer; otherwise the cheapest.
        _tier = q.options.any((o) => o.tier == _tier)
            ? _tier
            : q.cheapest?.tier;
      });
    } catch (e) {
      debugPrint('[shipping] quote failed ($e)');
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

  /// A price is on the table and one option is chosen.
  bool get _isQuoted => _quote?.quotable == true && _selected != null;

  Future<void> _submit() async {
    if (_submitting) return;
    _formKey.currentState?.validate();
    if (!_draft.isReady) {
      _toast(context.l10n.shipFixFields, error: true);
      _revealFirstMissing();
      return;
    }

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

      final budget = _budget.text.trim();
      final result = await ShippingRepository.instance.create(
        source: _source == ShippingSource.mambanda ? 'mambanda' : 'external',
        listingId: _listing?.id,
        itemTitle: _listing?.title,
        productUrl: _url.text.trim(),
        description: _description.text.trim(),
        categorySlug: _categorySlug,
        sizeKey: _sizeCode.isEmpty ? ShippingDraft.customSize : _sizeCode,
        sizeCustom: _sizeCode == ShippingDraft.customSize || _sizeCode.isEmpty
            ? (_sizeCustom.text.trim().isEmpty
                  ? l10n.shipSizeNoPresets
                  : _sizeCustom.text.trim())
            : null,
        budgetCents: budget.isEmpty
            ? null
            : toMinorUnits(num.tryParse(budget) ?? 0, currency: 'XAF'),
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
      // The thread exists now; make sure the inbox knows before they can tap
      // into it. The shipments list refreshes on its own — no need to wait.
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
        // The request came back without its row: the thread still exists,
        // and landing in it is better than a dead end.
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
    final showsBar = !(_step == ShippingStep.item && _source == null);
    return PopScope(
      canPop: _step == ShippingStep.item,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
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
        bottomNavigationBar: !showsBar
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (_step != ShippingStep.item) ...[
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
      case ShippingStep.item:
        return [
          _chooser(),
          if (_source != null) ...[
            const SizedBox(height: 8),
            ..._itemSection(),
            const SizedBox(height: 14),
            // The link above is optional — it can be absolutely anything, and
            // most of it has no link. A description is the normal answer, so
            // the "one or the other" message lives here.
            TextFormField(
              key: _source == ShippingSource.external
                  ? _keys[ShippingField.item]
                  : null,
              controller: _description,
              maxLines: 4,
              maxLength: 2000,
              onChanged: (_) => setState(() {}),
              decoration: _field(
                l10n.shipDescriptionLabel,
                hint: l10n.shipDescriptionHint,
              ),
              validator: (_) =>
                  _source == ShippingSource.external &&
                      _draft.missing.contains(ShippingField.item)
                  ? l10n.shipItemRequired
                  : null,
            ),
            ..._sizeSection(),
          ],
        ];

      case ShippingStep.route:
        return [
          Text(
            l10n.shipRouteIntro,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _SectionTitle(l10n.shipPickupTitle),
          const SizedBox(height: 10),
          ..._fromPlaceFields(),
          const SizedBox(height: 24),
          _SectionTitle(l10n.shipDeliveryTitle),
          const SizedBox(height: 10),
          ..._toPlaceFields(),
        ];

      case ShippingStep.quote:
        final locale = Localizations.localeOf(context);
        if (_quoteLoading) {
          return [
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Center(
              child: Text(
                l10n.shipQuoteLoading,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ];
        }
        if (_quoteFailed) {
          return [
            const SizedBox(height: 24),
            Text(
              l10n.shipQuoteFailed,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _fetchQuote(force: true),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.shipRetry),
            ),
            const SizedBox(height: 20),
            const _ManualQuoteCard(),
          ];
        }
        final q = _quote;
        if (q == null || !q.quotable) return const [_ManualQuoteCard()];
        return [
          Text(
            l10n.shipQuoteTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.shipQuoteIntro(l10n.shipRoute(_fromLocation, _toLocation)),
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          for (final o in q.options) ...[
            _TierCard(
              option: o,
              locale: locale,
              currency: q.currency,
              selected: o.tier == _tier,
              onTap: () => setState(() => _tier = o.tier),
            ),
            const SizedBox(height: 10),
          ],
        ];

      case ShippingStep.confirm:
        final locale = Localizations.localeOf(context);
        final size = _options.sizes[_sizeCode];
        final sizeLabel = _sizeCode == ShippingDraft.customSize || size == null
            ? (_sizeCustom.text.trim().isEmpty
                  ? l10n.shipSizeOther
                  : _sizeCustom.text.trim())
            : size.labelFor(locale);
        final chosen = _selected;
        return [
          _SummaryCard(
            rows: [
              (
                l10n.shipSummaryItem,
                _listing?.title ??
                    (_description.text.trim().isNotEmpty
                        ? _description.text.trim()
                        : _url.text.trim()),
              ),
              (
                l10n.shipSummaryRoute,
                l10n.shipRoute(_fromLocation, _toLocation),
              ),
              (l10n.shipSummarySize, sizeLabel),
              if (chosen != null)
                (
                  l10n.shipSummaryTier,
                  '${chosen.labelFor(locale)} · ${etaText(l10n, chosen.etaDaysMin, chosen.etaDaysMax)}',
                ),
            ],
            price: chosen == null
                ? null
                : formatPrice(
                    chosen.priceCents,
                    currency: _quote?.currency ?? 'XAF',
                  ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.shipPickupTitle),
          const SizedBox(height: 10),
          ..._pickupContactFields(),
          const SizedBox(height: 24),
          _SectionTitle(l10n.shipDeliveryTitle),
          const SizedBox(height: 10),
          ..._deliveryContactFields(),
          const SizedBox(height: 24),
          _SectionTitle(l10n.shipDetailsTitle),
          const SizedBox(height: 10),
          TextFormField(
            controller: _note,
            maxLines: 3,
            decoration: _field(l10n.shipNoteLabel),
          ),
          // A budget beside a firm price is a contradiction; it only means
          // something when the desk is going to name the price.
          if (chosen == null) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _budget,
              keyboardType: TextInputType.number,
              decoration: _field(
                l10n.shipBudgetLabel,
                hint: l10n.shipBudgetHint,
              ),
            ),
          ],
        ];
    }
  }

  // ── The one decision the rest of the form hangs off ─────────────────────────

  Widget _chooser() {
    final l10n = context.l10n;
    if (_source == null) {
      return Column(
        key: _keys[ShippingField.source],
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shipPathQuestion,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _PathCard(
            icon: Icons.storefront_outlined,
            title: l10n.shipPathMarketTitle,
            body: l10n.shipPathMarketBody,
            // Choosing the path and choosing the product are one gesture.
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
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
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

  // ── What it is ─────────────────────────────────────────────────────────────

  List<Widget> _itemSection() {
    final l10n = context.l10n;
    // The Mambanda path skips this entirely: the listing already carries a
    // title, a description and photos.
    if (_source == ShippingSource.mambanda) {
      if (_listing != null) return const [SizedBox(height: 10)];
      return [
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: _keys[ShippingField.item],
          onPressed: _pickListing,
          icon: const Icon(Icons.search_rounded),
          label: Text(l10n.shipPickProduct),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 18),
      TextFormField(
        controller: _url,
        keyboardType: TextInputType.url,
        onChanged: (_) => setState(() {}),
        decoration: _field(l10n.shipLinkLabelOptional, hint: l10n.shipLinkHint),
      ),
      _photoRail(),
    ];
  }

  Widget _photoRail() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shipPhotosLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          l10n.shipPhotosHint,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
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
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
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

  // ── Category and size ──────────────────────────────────────────────────────

  List<Widget> _sizeSection() {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final sizes = _sizes;
    final selected = _categories
        .where((c) => c.slug == _categorySlug)
        .firstOrNull;

    return [
      const SizedBox(height: 18),
      // No separate label above these: a DropdownButtonFormField carries its
      // own, and on screen the two read as the question asked twice.
      Container(
        key: _keys[ShippingField.category],
        child: _SearchableDropdown(
          label: l10n.shipCategoryLabel,
          hint: l10n.shipChooseCategory,
          selected: selected?.slug ?? '',
          entries: [
            for (final c in _categories) (c.slug, c.displayLabel(locale)),
          ],
          onPick: (slug) => setState(() {
            _categorySlug = slug;
            // The sizes are per category, so a code chosen under the old one is
            // not necessarily on the new list.
            _sizeCode = '';
          }),
        ),
      ),
      const SizedBox(height: 18),
      Container(key: _keys[ShippingField.size], child: const SizedBox.shrink()),
      if (sizes.isEmpty)
        // No catalogue, or a category nothing was written for. Never a wall:
        // they describe it and we sort it out in the conversation.
        TextFormField(
          key: _keys[ShippingField.sizeCustom],
          controller: _sizeCustom,
          onChanged: (_) => setState(() {}),
          decoration: _field(
            l10n.shipSizeCustomLabel,
            hint: l10n.shipSizeNoPresets,
          ),
        )
      else ...[
        DropdownButtonFormField<String>(
          initialValue: _sizeCode.isEmpty ? null : _sizeCode,
          isExpanded: true,
          decoration: _field(l10n.shipSizeLabel),
          hint: Text(l10n.shipSizeChoose),
          items: [
            for (final size in sizes)
              DropdownMenuItem(
                value: size.code,
                child: Text(size.labelFor(locale)),
              ),
            DropdownMenuItem(
              value: ShippingDraft.customSize,
              child: Text(l10n.shipSizeOther),
            ),
          ],
          onChanged: (code) {
            if (code != null) setState(() => _sizeCode = code);
          },
        ),
        // The hint is the whole point of the presets: "medium box" means
        // nothing, "medium box — about a microwave" is a decision.
        if (_hintFor(_sizeCode, locale) != null) ...[
          const SizedBox(height: 6),
          Text(
            _hintFor(_sizeCode, locale)!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_sizeCode == ShippingDraft.customSize) ...[
          const SizedBox(height: 10),
          TextFormField(
            key: _keys[ShippingField.sizeCustom],
            controller: _sizeCustom,
            onChanged: (_) => setState(() {}),
            decoration: _field(
              l10n.shipSizeCustomLabel,
              hint: l10n.shipSizeCustomHint,
            ),
            validator: (_) => _draft.missing.contains(ShippingField.sizeCustom)
                ? l10n.shipSizeCustomRequired
                : null,
          ),
        ],
      ],
    ];
  }

  String? _hintFor(String code, Locale locale) {
    if (code.isEmpty) return null;
    return _options.sizes[code]?.hintFor(locale);
  }

  // ── Where we collect it, and where it goes ─────────────────────────────────

  List<Widget> _fromPlaceFields() {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    return [
      Container(
        key: _keys[ShippingField.from],
        child: _placeDropdown(
          label: l10n.shipFromLabel,
          places: _options.from,
          selected: _fromCode,
          locale: locale,
          onPick: (code) => setState(() => _fromCode = code),
        ),
      ),
      if (_fromCode == 'other') ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _fromOther,
          onChanged: (_) => setState(() {}),
          decoration: _field(l10n.shipOtherPlace),
        ),
      ],
    ];
  }

  List<Widget> _toPlaceFields() {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    return [
      Container(
        key: _keys[ShippingField.to],
        child: _placeDropdown(
          label: l10n.shipToLabel,
          places: _options.to,
          selected: _toCode,
          locale: locale,
          onPick: (code) => setState(() => _toCode = code),
        ),
      ),
      if (_toCode == 'other') ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _toOther,
          onChanged: (_) => setState(() {}),
          decoration: _field(l10n.shipOtherPlace),
        ),
      ],
    ];
  }

  List<Widget> _pickupContactFields() {
    final l10n = context.l10n;
    return [
      TextFormField(
        controller: _pickupAddress,
        decoration: _field(
          l10n.shipPickupAddressLabel,
          hint: l10n.shipPickupAddressHint,
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _pickupName,
        decoration: _field(
          l10n.shipPickupNameLabel,
          hint: l10n.shipPickupNameHint,
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _pickupPhone,
        keyboardType: TextInputType.phone,
        decoration: _field(l10n.shipPickupPhoneLabel),
      ),
    ];
  }

  List<Widget> _deliveryContactFields() {
    final l10n = context.l10n;
    return [
      TextFormField(
        controller: _address,
        decoration: _field(l10n.shipAddressLabel, hint: l10n.shipAddressHint),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _name,
        decoration: _field(l10n.shipNameLabel, hint: l10n.shipDeliveryNameHint),
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: _keys[ShippingField.phone],
        controller: _phone,
        keyboardType: TextInputType.phone,
        onChanged: (_) => setState(() {}),
        decoration: _field(l10n.shipPhoneLabel),
        validator: (_) => _draft.missing.contains(ShippingField.phone)
            ? l10n.shipPhoneRequired
            : null,
      ),
    ];
  }

  /// A place, as a dropdown.
  ///
  /// Chips were a wrap of fifteen destinations that pushed everything below
  /// them off the screen and looked like an answer already given. A dropdown
  /// is one line whether the list holds six entries or sixty.
  Widget _placeDropdown({
    required String label,
    required List<ShippingPlace> places,
    required String selected,
    required Locale locale,
    required void Function(String code) onPick,
  }) {
    if (places.isEmpty) return const SizedBox.shrink();
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
    counterText: '',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

/// Four dots and their names. Done ones are filled, the current one is lit,
/// and only a step already reached can be tapped — back, never a skip.
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
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final labels = {
      ShippingStep.item: l10n.shipStepItem,
      ShippingStep.route: l10n.shipStepRoute,
      ShippingStep.quote: l10n.shipStepQuote,
      ShippingStep.confirm: l10n.shipStepConfirm,
    };
    return Row(
      children: [
        for (final step in ShippingStep.values) ...[
          if (step != ShippingStep.item)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: step.index <= current.index
                    ? tokens.accentFill
                    : scheme.outlineVariant,
              ),
            ),
          GestureDetector(
            onTap: step.index <= furthest.index && step != current
                ? () => onTap(step)
                : null,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.index <= current.index
                        ? tokens.accentFill
                        : scheme.surfaceContainerHighest,
                    border: step == current
                        ? Border.all(color: tokens.accentInk, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: step.index < current.index
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: tokens.onAccentFill,
                        )
                      : Text(
                          '${step.index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: step.index <= current.index
                                ? tokens.onAccentFill
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[step]!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: step == current
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: step == current
                        ? tokens.accentInk
                        : scheme.onSurfaceVariant,
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

/// One way to have it delivered.
class _TierCard extends StatelessWidget {
  const _TierCard({
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
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? tokens.accentInk : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.labelFor(locale),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      etaText(l10n, option.etaDaysMin, option.etaDaysMax),
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPrice(option.priceCents, currency: currency),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: tokens.accentInk,
                    ),
                  ),
                  Text(
                    l10n.shipPayOnDelivery,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? tokens.accentInk : scheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the price step shows when the catalogue cannot price the route.
class _ManualQuoteCard extends StatelessWidget {
  const _ManualQuoteCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 28,
            color: context.tokens.accentInk,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shipQuoteManualTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.shipQuoteManualBody,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The request, read back before it is sent.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rows, this.price});

  final List<(String, String)> rows;

  /// Null on the manual path, where the desk names the price later.
  final String? price;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shipSummaryTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          for (final (label, value) in rows)
            if (value.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          const Divider(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  l10n.shipSummaryPrice,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: price == null
                    ? Text(
                        l10n.shipSummaryPriceManual,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            price!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: tokens.accentInk,
                            ),
                          ),
                          Text(
                            l10n.shipCodBannerBody,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
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
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 28, color: context.tokens.accentInk),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
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
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );
}

/// A dropdown you can type into.
///
/// Once a list is thirty entries long, picking from it by scrolling is worse
/// than typing three letters — and both places and the category list are past
/// that. Material's [DropdownMenu] does the filtering itself, so this is a
/// wrapper for the styling and for the one behaviour it does not give free:
/// keeping the visible text in step when the chosen value is changed from
/// outside, which happens when a listing prefills the form.
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

  /// The chosen code, or empty for nothing chosen.
  final String selected;

  /// (code, label) in the order they should appear.
  final List<(String, String)> entries;

  final void Function(String code) onPick;

  @override
  State<_SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<_SearchableDropdown> {
  late final TextEditingController _text = TextEditingController(
    text: _labelFor(widget.selected),
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  /// Leaving the field with a half-typed search puts the chosen label back,
  /// so the box never reads "pho" for something that is still "Phones".
  void _onFocus() {
    if (_focus.hasFocus) return;
    final label = _labelFor(widget.selected);
    if (label.isNotEmpty && _text.text != label) _text.text = label;
  }

  /// A field that already holds a value starts empty when tapped, so typing
  /// replaces rather than appends: "TV & audio" + "phone" is "TV & audiophone",
  /// which matches nothing, shows no menu, and lets the next tap land on
  /// whatever sits underneath. Clearing rather than selecting-all on purpose —
  /// a programmatic selection range on an unfocused field pulled focus back
  /// to it on the next rebuild, which sent keystrokes meant for another box
  /// into this one.
  void _onPointerDown(PointerDownEvent _) {
    if (!_focus.hasFocus && _text.text.isNotEmpty) _text.clear();
  }

  String _labelFor(String code) {
    for (final (value, label) in widget.entries) {
      if (value == code) return label;
    }
    return '';
  }

  @override
  void didUpdateWidget(covariant _SearchableDropdown old) {
    super.didUpdateWidget(old);
    // The field is editable, so DropdownMenu will not correct it on its own.
    // Without this, prefilling from a listing left the old text on screen.
    if (widget.selected != old.selected ||
        widget.entries.length != old.entries.length) {
      final label = _labelFor(widget.selected);
      if (label.isNotEmpty && label != _text.text) _text.text = label;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      child: DropdownMenu<String>(
        controller: _text,
        focusNode: _focus,
        initialSelection: widget.selected.isEmpty ? null : widget.selected,
        enableFilter: true,
        requestFocusOnTap: true,
        // Fill the column like every other field on this form does.
        expandedInsets: EdgeInsets.zero,
        menuHeight: 320,
        label: Text(widget.label),
        hintText: widget.hint,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dropdownMenuEntries: [
          for (final (value, label) in widget.entries)
            DropdownMenuEntry(value: value, label: label),
        ],
        onSelected: (code) {
          if (code != null) widget.onPick(code);
        },
      ),
    );
  }
}
