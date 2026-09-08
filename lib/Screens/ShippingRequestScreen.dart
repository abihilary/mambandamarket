import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../Components/listing_picker.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../Service/ChatRoomScreen.dart';
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
/// The shape of the thing is one decision followed by a form. Until somebody
/// has said whether this is a product from here or something else, the screen
/// shows exactly two cards and nothing else — a wall of ten fields is how you
/// lose somebody on the first screen of a feature they have never used.
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
      _url, _description, _sizeCustom, _fromOther, _toOther,
      _budget, _name, _phone, _address, _note,
      _pickupAddress, _pickupName, _pickupPhone,
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

  String get _fromLocation =>
      _fromCode == 'other' ? _fromOther.text.trim() : _fromCode;
  String get _toLocation => _toCode == 'other' ? _toOther.text.trim() : _toCode;

  void _takeListing(Listing listing) {
    _listing = listing;
    _source = ShippingSource.mambanda;
    // The listing already answers these; leave them editable but filled.
    _categorySlug ??= listing.categorySlug;
    if (_fromCode.isEmpty && (listing.city ?? '').isNotEmpty) {
      _fromCode = 'other';
      _fromOther.text = listing.city!;
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
          source: ImageSource.camera, imageQuality: 85, maxWidth: 1200);
      if (shot != null && mounted) setState(() => _photos.add(shot));
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1200);
    if (picked.isEmpty || !mounted) return;
    setState(() => _photos.addAll(picked.take(6 - _photos.length)));
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : null,
    ));
  }

  /// Scroll to the first thing still missing, rather than naming it in a
  /// snackbar and leaving them to hunt for it.
  void _revealFirstMissing() {
    final first = _draft.missing.firstOrNull;
    if (first == null) return;
    final ctx = _keys[first]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        alignment: 0.2, duration: const Duration(milliseconds: 300));
  }

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
    final locale = Localizations.localeOf(context).languageCode == 'fr' ? 'fr' : 'en';

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
            ? (_sizeCustom.text.trim().isEmpty ? l10n.shipSizeNoPresets : _sizeCustom.text.trim())
            : null,
        budgetCents: budget.isEmpty ? null : toMinorUnits(num.tryParse(budget) ?? 0, currency: 'XAF'),
        fromLocation: _fromLocation,
        toLocation: _toLocation,
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
      // Land them in the conversation: the whole point of this being a thread
      // rather than a form is that a conversation starts.
      final thread = result.conversation;
      if (thread != null) {
        await ChatRepository.instance.refresh();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ChatRoomScreen(conversation: thread)),
        );
      } else {
        Navigator.pop(context);
      }
      _toast(l10n.shipCreated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(
        switch (e.code) {
          'shipping_unavailable' => l10n.shipUnavailable,
          'rate_limited' => l10n.shipTooMany,
          'listing_unavailable' => l10n.shipListingGone,
          _ => e.message,
        },
        error: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(l10n.shipFailed, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shipTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(l10n.shipIntro,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 18),
            _chooser(),
            if (_source != null) ...[
              const SizedBox(height: 8),
              ..._itemSection(),
              ..._sizeSection(),
              ..._pickupSection(),
              ..._deliverySection(),
              ..._detailsSection(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _source == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.shipSubmit,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
    );
  }

  // ── The one decision the rest of the form hangs off ─────────────────────────

  Widget _chooser() {
    final l10n = context.l10n;
    if (_source == null) {
      return Column(
        key: _keys[ShippingField.source],
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.shipPathQuestion,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      key: _keys[ShippingField.item],
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            _source == ShippingSource.mambanda ? Icons.storefront_outlined : Icons.link_rounded,
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
                  Text(_listing!.displayPrice,
                      style: TextStyle(
                          color: context.tokens.accentInk,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
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
          onPressed: _pickListing,
          icon: const Icon(Icons.search_rounded),
          label: Text(l10n.shipPickProduct),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
      ];
    }

    return [
      const SizedBox(height: 18),
      TextFormField(
        key: _keys[ShippingField.item],
        controller: _url,
        keyboardType: TextInputType.url,
        onChanged: (_) => setState(() {}),
        decoration: _field(l10n.shipLinkLabel, hint: l10n.shipLinkHint),
        // A link or a description will do, and the description lives further
        // down now — so the message says so rather than naming this box.
        validator: (_) =>
            _draft.missing.contains(ShippingField.item) ? l10n.shipItemRequired : null,
      ),
      _photoRail(),
    ];
  }

  Widget _photoRail() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.shipPhotosLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(l10n.shipPhotosHint,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(File(_photos[i].path), fit: BoxFit.cover),
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

  // ── Category and size ──────────────────────────────────────────────────────

  List<Widget> _sizeSection() {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final sizes = _sizes;
    final selected = _categories.where((c) => c.slug == _categorySlug).firstOrNull;

    return [
      const SizedBox(height: 18),
      // No separate label above these: a DropdownButtonFormField carries its
      // own, and on screen the two read as the question asked twice.
      Container(
        key: _keys[ShippingField.category],
        child: DropdownButtonFormField<String>(
        initialValue: selected?.slug,
        isExpanded: true,
        decoration: _field(l10n.shipCategoryLabel),
        hint: Text(l10n.shipChooseCategory),
        items: [
          for (final c in _categories)
            DropdownMenuItem(value: c.slug, child: Text(c.displayLabel(locale))),
        ],
        onChanged: _categories.isEmpty
            ? null
            : (slug) {
                if (slug == null) return;
                setState(() {
                  _categorySlug = slug;
                  // The sizes are per category, so a code chosen under the old
                  // one is not necessarily on the new list.
                  _sizeCode = '';
                });
              },
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
          decoration: _field(l10n.shipSizeCustomLabel, hint: l10n.shipSizeNoPresets),
        )
      else ...[
        DropdownButtonFormField<String>(
          initialValue: _sizeCode.isEmpty ? null : _sizeCode,
          isExpanded: true,
          decoration: _field(l10n.shipSizeLabel),
          hint: Text(l10n.shipSizeChoose),
          items: [
            for (final size in sizes)
              DropdownMenuItem(value: size.code, child: Text(size.labelFor(locale))),
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
          Text(_hintFor(_sizeCode, locale)!,
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        if (_sizeCode == ShippingDraft.customSize) ...[
          const SizedBox(height: 10),
          TextFormField(
            key: _keys[ShippingField.sizeCustom],
            controller: _sizeCustom,
            onChanged: (_) => setState(() {}),
            decoration: _field(l10n.shipSizeCustomLabel, hint: l10n.shipSizeCustomHint),
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

  // ── Where we collect it ────────────────────────────────────────────────────

  List<Widget> _pickupSection() {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    return [
      const SizedBox(height: 24),
      _SectionTitle(l10n.shipPickupTitle),
      const SizedBox(height: 10),
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
      const SizedBox(height: 12),
      TextFormField(
        controller: _pickupAddress,
        decoration: _field(l10n.shipPickupAddressLabel, hint: l10n.shipPickupAddressHint),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _pickupName,
        decoration: _field(l10n.shipPickupNameLabel, hint: l10n.shipPickupNameHint),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _pickupPhone,
        keyboardType: TextInputType.phone,
        decoration: _field(l10n.shipPickupPhoneLabel),
      ),
    ];
  }

  // ── Where it goes ──────────────────────────────────────────────────────────

  List<Widget> _deliverySection() {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    return [
      const SizedBox(height: 24),
      _SectionTitle(l10n.shipDeliveryTitle),
      const SizedBox(height: 10),
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
      const SizedBox(height: 12),
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
        validator: (_) =>
            _draft.missing.contains(ShippingField.phone) ? l10n.shipPhoneRequired : null,
      ),
    ];
  }

  // ── Anything else ──────────────────────────────────────────────────────────

  List<Widget> _detailsSection() {
    final l10n = context.l10n;
    return [
      const SizedBox(height: 24),
      _SectionTitle(l10n.shipDetailsTitle),
      const SizedBox(height: 10),
      TextFormField(
        controller: _description,
        maxLines: 4,
        maxLength: 2000,
        onChanged: (_) => setState(() {}),
        decoration: _field(l10n.shipDescriptionLabel, hint: l10n.shipDescriptionHint),
      ),
      const SizedBox(height: 4),
      TextFormField(
        controller: _budget,
        keyboardType: TextInputType.number,
        decoration: _field(l10n.shipBudgetLabel, hint: l10n.shipBudgetHint),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _note,
        maxLines: 3,
        decoration: _field(l10n.shipNoteLabel),
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
    final codes = places.map((p) => p.code).toSet();
    return DropdownButtonFormField<String>(
      initialValue: codes.contains(selected) ? selected : null,
      isExpanded: true,
      decoration: _field(label),
      items: [
        for (final place in places)
          DropdownMenuItem(value: place.code, child: Text(place.labelFor(locale))),
      ],
      onChanged: (code) {
        if (code != null) onPick(code);
      },
    );
  }

  InputDecoration _field(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
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
                    Text(title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(body,
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
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
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
}

