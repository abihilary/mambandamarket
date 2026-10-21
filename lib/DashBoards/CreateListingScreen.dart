import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/models.dart' as api;
import '../api/listing_attributes.dart';
import '../api/location_service.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../Components/category_icons.dart';
import '../Components/category_picker.dart';
import '../Components/local_image.dart';
import '../Components/safe_bottom.dart';

class CreateListingScreen extends StatefulWidget {
  final Map<String, dynamic>? initialListing;

  const CreateListingScreen({super.key, this.initialListing});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

/// A photo already on the listing.
///
/// The id is what the delete endpoint needs, and it only comes from
/// GET /listings/:id/images — the dashboards hand over display URLs and
/// nothing else. Without an id a photo can be shown but not removed, so the
/// remove button is hidden rather than pretending the removal worked.
class _ExistingImage {
  final String? id;
  final String url;

  const _ExistingImage({required this.url, this.id});
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final FocusNode _locationFocus = FocusNode();

  /// The coordinate behind the location box, if the seller offered one.
  ///
  /// Deliberately separate from the text: the box stays what a human wrote and
  /// what buyers read, and this rides along silently. Writing a lat/lng into
  /// the box would replace "Bonaberi, Douala" with a pair of numbers nobody
  /// asked for and nobody can read.
  Coordinate? _capturedPoint;
  bool _capturingPoint = false;

  /// Suggestions behind the location box.
  ///
  /// The field stays free text — the column is a plain string and a seller in
  /// a village this list has never heard of must still be able to type it.
  /// These exist so the common cases agree with each other: left alone, the
  /// same neighbourhood arrives as "akwa", "Akwa Douala" and "AKWA-DLA", and
  /// nothing downstream can group those.
  static const List<String> _locationSuggestions = [
    'Akwa, Douala', 'Bonanjo, Douala', 'Bonapriso, Douala', 'Bonabéri, Douala',
    'Deïdo, Douala', 'Bali, Douala', 'New Bell, Douala', 'Makepe, Douala',
    'Bonamoussadi, Douala', 'Logbessou, Douala', 'Ndogbong, Douala',
    'Logpom, Douala', 'Kotto, Douala', 'Cité des Palmiers, Douala',
    'Yassa, Douala', 'PK8, Douala', 'Ngodi, Douala', 'Bepanda, Douala',
    'Douala', 'Yaoundé', 'Bafoussam', 'Bamenda', 'Garoua', 'Maroua',
    'Ngaoundéré', 'Bertoua', 'Buea', 'Limbe', 'Kribi', 'Ebolowa', 'Kumba',
    'Edéa', 'Dschang', 'Foumban', 'Nkongsamba', 'Sangmélima', 'Bafang',
    'Mbouda', 'Tiko', 'Loum',
  ];

  /// The only conditions the API accepts, and the only ones the dropdown
  /// offers. Anything else — including the empty string the seller hub sends
  /// for a listing with no condition — asserts inside the dropdown, so it is
  /// filtered through here on the way in.
  static const List<String> _conditions = [
    'New',
    'Like New',
    'Used',
    'Refurbished',
  ];

  /// Category **slug** (the API's identifier), not the display label.
  String? _selectedCategory;

  /// product | service | job. Chosen first, because it decides which of the
  /// fields below are even asked for — a job has no quantity, no condition,
  /// no stock and nothing to deliver.
  String _kind = 'product';

  /// Set once the seller picks the kind themselves, so that choosing a
  /// category afterwards cannot quietly overrule them. Without this, a
  /// plumber who marks a listing a Service and then picks "Repairs" has it
  /// flipped back under them by the category default.
  bool _kindChosenByUser = false;

  /// True while [_selectedCategory] is one the form filled in from the kind
  /// rather than one the seller picked, so the field can say so and invite a
  /// narrower choice.
  bool _categoryAutoPicked = false;

  /// Lets a kind switch refresh the category field's own state, so an error
  /// left from a failed save does not sit under a category just filled in.
  final _categoryFieldKey = GlobalKey<FormFieldState<String>>();

  /// The product category in use before the seller switched to Service or
  /// Job, so switching back returns it instead of leaving them on "Services".
  String? _lastProductCategory;

  /// How [_priceController] should be read. See migration 0048.
  String _priceMode = 'fixed';

  /// Modes that carry no amount at all — the price box is hidden and 0 is
  /// stored, because the column is still NOT NULL.
  static const Set<String> _amountlessModes = {
    'negotiable',
    'on_request',
    'free',
  };

  bool get _wantsAmount => !_amountlessModes.contains(_priceMode);
  bool get _isProduct => _kind == 'product';

  String _selectedCondition = 'New';
  bool _hasGuarantee = false;

  /// The category's details as answered so far (sizes, subjects…). Chips and
  /// switches write here; text and number fields keep their own controllers
  /// and are read on save. Answers for fields the new category does not ask
  /// for are simply not sent.
  final Map<String, dynamic> _attributes = {};
  final Map<String, TextEditingController> _attrControllers = {};

  /// Set by a save attempt, so missing required chips show as missing only
  /// once the seller has tried, not while they are still filling in.
  bool _attrTried = false;

  List<AttrField> get _attrFields =>
      api.attributeFieldsFor(_categories, _selectedCategory);

  TextEditingController _attrCtl(String key) =>
      _attrControllers.putIfAbsent(key, () {
        final v = _attributes[key];
        return TextEditingController(text: v == null ? '' : v.toString());
      });
  bool _isSubmitting = false;

  /// Loaded from the database so the picker always matches the server.
  List<api.Category> _categories = [];

  final ImagePicker _picker = ImagePicker();
  final List<_ExistingImage> _existingImages = []; // already on the listing
  final List<XFile> _newImageFiles = [];           // just picked, not uploaded yet
  final List<String> _removedImageIds = [];        // deleted on save, not before

  /// The listing being edited, or null when publishing a new one. Everything
  /// that behaves differently between the two reads this rather than checking
  /// `widget.initialListing` again and drifting.
  String? get _editingId {
    final id = widget.initialListing?['id'];
    return (id == null || id.toString().isEmpty) ? null : id.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.initialListing != null) {
      final listing = widget.initialListing!;
      _titleController.text = listing['title']?.toString() ?? '';
      _descriptionController.text = listing['description']?.toString() ?? '';
      _quantityController.text = (listing['quantity'] ?? 1).toString();
      // The dashboards hand over the price in minor units; there has never
      // been a 'price' key in that map, so this box opened empty and saving
      // rewrote the price to whatever was typed to get past the validator.
      _priceController.text = _priceFieldFor(listing);
      // The seller hub sends the slug as 'category'; the store dashboard sends
      // both. Reading only one of them silently reset the category on save.
      _selectedCategory =
          (listing['category_slug'] ?? listing['category'])?.toString();
      final condition = listing['condition']?.toString();
      _selectedCondition =
          _conditions.contains(condition) ? condition! : 'New';
      _kind = (listing['kind'] ?? listing['kind_slug'])?.toString() ?? 'product';
      // An existing listing's kind is the seller's own earlier decision, so
      // re-picking the category while editing must not overwrite it.
      _kindChosenByUser = true;
      _priceMode = listing['priceMode']?.toString() ??
          listing['price_mode']?.toString() ??
          'fixed';
      _hasGuarantee = listing['hasGuarantee'] ?? false;
      // Both spellings, for the same reason the category reads two keys: the
      // seller hub and the store dashboard build this map differently.
      _locationController.text = (listing['city'] ?? listing['location'] ?? '')
          .toString();
      // The dashboards build this map by hand and do not carry the details,
      // so they are read from the listing itself — saving without them would
      // send an empty set and fail a category's required fields.
      final attrs = listing['attributes'];
      if (attrs is Map) {
        _attributes.addAll(attrs.cast<String, dynamic>());
      } else {
        _loadExistingAttributes();
      }

      // Show what the caller already has so the row is not empty while the
      // real records — the ones carrying ids — are fetched.
      final images = listing['images'];
      if (images is List) {
        _existingImages
            .addAll(images.map((u) => _ExistingImage(url: u.toString())));
      }
      _loadExistingImages();
    } else {
      _quantityController.text = '1';
    }
  }

  /// The price as a human would type it, from whatever the caller passed.
  String _priceFieldFor(Map<String, dynamic> listing) {
    final cents = listing['priceCents'] ?? listing['price_cents'];
    if (cents is! int) return listing['price']?.toString() ?? '';
    final currency = (listing['currency'] ?? 'XAF').toString();
    final amount = api.fromMinorUnits(cents, currency: currency);
    // 145000, not 145000.0 — the box is a text field and that ends up in
    // front of the seller.
    return amount == amount.roundToDouble()
        ? amount.round().toString()
        : amount.toString();
  }

  Future<void> _loadExistingAttributes() async {
    final id = _editingId;
    if (id == null) return;
    try {
      final listing = await ListingsRepository.instance.detail(id);
      if (!mounted) return;
      setState(() {
        _attributes
          ..clear()
          ..addAll(listing.attributes);
        for (final e in _attrControllers.entries) {
          final v = _attributes[e.key];
          e.value.text = v == null ? '' : v.toString();
        }
      });
    } catch (_) {
      // Left empty; the seller can fill them in again, and the server says
      // which are required if they do not.
    }
  }

  /// What the details section holds, in the shape the server checks.
  Map<String, dynamic> _collectAttributes() {
    final out = <String, dynamic>{};
    for (final f in _attrFields) {
      switch (f.type) {
        case 'multi':
          final v = _attributes[f.key];
          if (v is List && v.isNotEmpty) out[f.key] = List<String>.from(v);
        case 'single':
          final v = _attributes[f.key];
          if (v is String && v.isNotEmpty) out[f.key] = v;
        case 'bool':
          if (_attributes[f.key] == true) out[f.key] = true;
        case 'number':
          final n = num.tryParse(
            _attrCtl(f.key).text.trim().replaceAll(',', '.'),
          );
          if (n != null) out[f.key] = n;
        case 'text':
          final t = _attrCtl(f.key).text.trim();
          if (t.isNotEmpty) out[f.key] = t;
      }
    }
    return out;
  }

  /// Fetch the listing's photos so removals have an id to act on.
  Future<void> _loadExistingImages() async {
    final id = _editingId;
    if (id == null) return;
    try {
      final images = await ListingsRepository.instance.images(id);
      if (!mounted) return;
      setState(() {
        _existingImages
          ..clear()
          ..addAll(images.map((i) => _ExistingImage(id: i.id, url: i.url)));
      });
    } catch (_) {
      // The photos stay on screen and stay on the listing; only changing them
      // is off the table, which is what the message says.
      if (mounted) _showErrorSnackBar(context.l10n.createCouldNotLoadImages);
    }
  }

  Future<void> _loadCategories() async {
    // Deliberately not `final l10n = context.l10n` up here.
    //
    // This runs from initState, and context.l10n resolves through
    // dependOnInheritedWidgetOfExactType, which is illegal before initState
    // has returned. It threw on the very first line — outside the try — so
    // the fetch never ran, _categories stayed empty, and the field sat on
    // "Loading…" forever without even showing the error snackbar, because the
    // throw happened before the block that shows it.
    //
    // It is an assert, so only debug builds ever hit it: release, including
    // everything on Play, loaded categories fine. That is precisely why it
    // survived — the one place it breaks is somebody testing a debug build,
    // and the symptom looks like a slow network rather than a crash.
    //
    // Reading it inside the catch is safe: that is after an await, so the
    // element is mounted and the lookup is legal.
    try {
      final cats = await ListingsRepository.instance.categories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        // Keep any pre-selected slug that still exists; otherwise default.
        if (!cats.any((c) => c.slug == _selectedCategory)) {
          // A seller who chose Service or Job before the list arrived gets
          // that group, not the first product category in the list.
          final home = _homeCategoryFor(_kind);
          _selectedCategory = home ?? (cats.isNotEmpty ? cats.first.slug : null);
          _categoryAutoPicked = home != null;
        }
      });
    } catch (e, stack) {
      // The reason used to be discarded here, which is why a category list
      // that would not load was indistinguishable from one still loading:
      // the field said "Loading…" forever and nothing anywhere said why.
      // The reason used to be discarded, which is what made a list that would
      // not load indistinguishable from one still loading.
      debugPrint('[categories] load failed: $e');
      debugPrintStack(stackTrace: stack, label: '[categories]');
      if (mounted) {
        _showErrorSnackBar(context.l10n.createCouldNotLoadCategories);
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    final l10n = context.l10n;
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (photo != null) {
        setState(() {
          _newImageFiles.add(photo);
        });
      }
    } catch (e) {
      _showErrorSnackBar(l10n.createFailedToCapturePhoto(e.toString()));
    }
  }

  Future<void> _pickImagesFromGallery() async {
    final l10n = context.l10n;
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (images.isNotEmpty) {
        setState(() {
          _newImageFiles.addAll(images);
        });
      }
    } catch (e) {
      _showErrorSnackBar(l10n.createFailedToPickImages(e.toString()));
    }
  }

  void _showImagePickerModal() {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        final accent = Theme.of(ctx).colorScheme.primary;
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: accent),
                title: Text(l10n.createTakePhotoWithCamera),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: accent),
                title: Text(l10n.createChooseFromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImagesFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeExistingImage(int index) {
    final image = _existingImages[index];
    setState(() {
      // Deleted on save, not now: backing out of the screen must leave the
      // listing exactly as it was.
      if (image.id != null) _removedImageIds.add(image.id!);
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImageFiles.removeAt(index);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  /// Prompt the user to upgrade when their plan's active-listing quota is full.
  void _showLimitDialog(String message) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.createListingLimitReached),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.createNotNow),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/subscription');
            },
            child: Text(l10n.createUpgradePlan),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    if (_selectedCategory == null) {
      _showErrorSnackBar(l10n.createPleaseChooseACategory);
      return;
    }
    // A photo is the whole listing for a product and nobody will tap a card
    // without one. A job advert is text, and demanding a picture of a vacancy
    // is how you get stock photos of handshakes — so it is asked for, not
    // required, once this stops being an object.
    if (_isProduct && _existingImages.isEmpty && _newImageFiles.isEmpty) {
      _showErrorSnackBar(l10n.createSelectAtLeastOneImage);
      return;
    }
    // Text and number details are checked by their own validators above;
    // chips and switches have no validator, so the required ones are here.
    final attributes = _collectAttributes();
    final locale = Localizations.localeOf(context);
    final missing = _attrFields
        .where((f) => f.required && !AttrField.answered(attributes[f.key]))
        .map((f) => f.label(locale))
        .toList();
    if (missing.isNotEmpty) {
      setState(() => _attrTried = true);
      _showErrorSnackBar(l10n.createDetailsMissing(missing.join(', ')));
      return;
    }

    setState(() => _isSubmitting = true);
    final editingId = _editingId;
    try {
      // Money is sent as integer minor units; never as a float. FCFA has no
      // minor unit, so the conversion is currency-aware — scaling by 100 here
      // published every listing at 100x its price.
      // Amount-less modes store 0; the column is still NOT NULL and the mode
      // is what gets rendered. Reading the box anyway would carry a number the
      // seller typed before switching mode into a listing that says
      // "Negotiable" — which is exactly what the DB constraint forbids.
      final priceCents = _wantsAmount
          ? api.toMinorUnits(
              double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0,
            )
          : 0;
      final quantity = _isProduct ? (int.tryParse(_quantityController.text) ?? 1) : 1;
      final description = _descriptionController.text.trim();

      if (editingId != null) {
        // Editing said "Edit Item" and "Save Changes" at the top and bottom of
        // the screen, and then posted a second listing. The screen has always
        // known which one it was; only this call did not.
        // Whatever the last call below reports is the listing's final
        // state, if Mambanda had asked for changes to it.
        ListingsRepository.instance.lastReview = null;
        await ListingsRepository.instance.update(editingId, {
          'title': _titleController.text.trim(),
          'description': description,
          'price_cents': priceCents,
          'quantity': quantity,
          'category_slug': _selectedCategory!,
          'kind': _kind,
          'price_mode': _priceMode,
          // Null for anything that is not an object. The server normalises
          // this too, but sending the right shape keeps the two in step.
          'condition': _isProduct ? _selectedCondition : null,
          'has_guarantee': _isProduct && _hasGuarantee,
          // Sent even when blank: the API reads "" as "cleared" and stores
          // null, which is how a seller removes a location they no longer
          // want on the listing. Omitting the key would leave the old one.
          'city': _locationController.text.trim(),
          // Only when the seller captured one on this visit. Omitted otherwise
          // so editing the price does not silently drop a coordinate the
          // listing already had — the edit form has no way to read the
          // existing one back, so absence here must mean "leave it alone".
          if (_capturedPoint != null)
            'location': [_capturedPoint!.lng, _capturedPoint!.lat],
          'attributes': attributes,
        });

        // Photos are their own endpoints — PATCH /listings/:id does not carry
        // them. Removals first, so a seller swapping every photo on a listing
        // at the 12-image cap does not hit it on the way through.
        for (final imageId in _removedImageIds) {
          await ListingsRepository.instance.removeImage(editingId, imageId);
        }
        if (_newImageFiles.isNotEmpty) {
          final added = <String>[];
          for (final file in _newImageFiles) {
            added.add(await ListingsRepository.instance.uploadImage(file));
          }
          await ListingsRepository.instance.addImages(editingId, added);
        }

        if (!mounted) return;
        final review = ListingsRepository.instance.lastReview;
        ListingsRepository.instance.lastReview = null;
        if (review != null && review['state'] == 'changes_requested') {
          // Saved, but what Mambanda asked about is still there: say exactly
          // what, in the seller's language, before they leave the form.
          final lang = Localizations.localeOf(context).languageCode;
          final remaining = (review['remaining'] as Map?)?[lang == 'fr' ? 'fr' : 'en'];
          final points = remaining is List ? remaining.map((e) => e.toString()).toList() : const <String>[];
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.listingReviewStill),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final p in points) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('•  $p'))],
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).okButtonLabel))],
            ),
          );
          // Everything is saved — photos included — so leave the form rather
          // than invite a second save that would upload the photos again.
          // The listing's card in the seller hub keeps the points to fix.
          if (!mounted) return;
          Navigator.pop(context, <String, dynamic>{'id': editingId});
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(review != null && review['state'] == 'resubmitted'
                ? l10n.listingReviewLive
                : l10n.createListingUpdated),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, <String, dynamic>{'id': editingId});
        return;
      }

      // Images go straight to Supabase Storage via short-lived signed URLs —
      // they never stream through the API.
      final uploaded = <String>[];
      for (final file in _newImageFiles) {
        uploaded.add(
          await ListingsRepository.instance.uploadImage(file),
        );
      }

      final listing = await ListingsRepository.instance.create(
        title: _titleController.text.trim(),
        description: description,
        priceCents: priceCents,
        quantity: quantity,
        categorySlug: _selectedCategory!,
        kind: _kind,
        priceMode: _priceMode,
        condition: _isProduct ? _selectedCondition : null,
        hasGuarantee: _isProduct && _hasGuarantee,
        city: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        lat: _capturedPoint?.lat,
        lng: _capturedPoint?.lng,
        imagePaths: uploaded,
        attributes: attributes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.createListingPublished),
          backgroundColor: AppColors.success,
        ),
      );
      // A Map, because the store dashboard pushes this route typed as one and
      // popping an api.Listing into it fails the cast on the way back.
      Navigator.pop(context, <String, dynamic>{'id': listing.id});
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isListingLimit) {
        _showLimitDialog(e.message);
      } else if (e.isUnauthorized) {
        _showErrorSnackBar(l10n.createSignInToPublish);
      } else {
        _showErrorSnackBar(e.message);
      }
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar(editingId != null
            ? l10n.createCouldNotSaveChanges
            : l10n.createCouldNotPublish);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildImagePreview(String path, VoidCallback? onRemove) {
    final bool isNetwork = path.startsWith('http://') || path.startsWith('https://');

    return Stack(
      children: [
        Container(
          width: 100,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: isNetwork
                  ? NetworkImage(path) as ImageProvider
                  : localImageProvider(path),
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 16,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.danger,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  /// Attach the seller's approximate position to this listing.
  ///
  /// Never blocks publishing: every refusal ends in a message and a form that
  /// is exactly as usable as it was before the button was pressed.
  Future<void> _captureLocation() async {
    setState(() => _capturingPoint = true);
    final outcome = await LocationService.instance.refresh();
    if (!mounted) return;
    final l10n = context.l10n;
    setState(() {
      _capturingPoint = false;
      if (outcome == LocationOutcome.ok) {
        _capturedPoint = LocationService.instance.cached;
      }
    });
    if (outcome == LocationOutcome.ok) return;
    final message = switch (outcome) {
      LocationOutcome.servicesOff => l10n.locationServicesOff,
      LocationOutcome.deniedForever => l10n.locationDeniedForever,
      LocationOutcome.denied => l10n.locationDenied,
      _ => l10n.locationUnavailable,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _locationFocus.dispose();
    for (final c in _attrControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  api.Category? _categoryBySlug(String? slug) {
    if (slug == null) return null;
    for (final c in _categories) {
      if (c.slug == slug) return c;
    }
    return null;
  }

  /// The chosen category as the seller should read it: "Food & drink › Drinks".
  ///
  /// The group is part of the answer, not decoration. Leaf names repeat across
  /// the tree — "Services" sits under three different roots and "Scissors"
  /// names both a hairdresser and a tailor — so a leaf on its own does not say
  /// what was actually picked.
  String _categoryFieldText(BuildContext context) {
    final selected = _categoryBySlug(_selectedCategory);
    if (selected == null) {
      // A slug with no matching category means the list has not arrived yet;
      // showing the raw slug beats showing "Select category" over a choice the
      // seller already made and is about to save.
      return _selectedCategory ??
          (_categories.isEmpty
              ? context.l10n.createLoading
              : context.l10n.createSelectCategory);
    }
    final locale = Localizations.localeOf(context);
    final parent = _categoryBySlug(selected.parentSlug);
    return parent == null
        ? selected.displayLabel(locale)
        : '${parent.displayLabel(locale)} › ${selected.displayLabel(locale)}';
  }

  Future<void> _pickCategory() async {
    if (_categories.isEmpty) return;
    final picked = await showCategoryPicker(
      context,
      categories: _categories,
      selectedSlug: _selectedCategory,
    );
    // null means dismissed, which is not the same as cleared.
    if (picked == null || !mounted) return;
    setState(() {
      _selectedCategory = picked;
      _categoryAutoPicked = false;
    });

    // Jobs and services are categories the server already knows the shape of,
    // so picking one offers the matching kind — but never overrides a seller
    // who has already answered the question themselves.
    if (_kindChosenByUser) return;
    String? suggested;
    for (final c in _categories) {
      if (c.slug == picked) {
        suggested = c.defaultKind;
        break;
      }
    }
    if (suggested != null) _setKind(suggested, byUser: false);
  }

  /// The kind a category normally holds: its own default, else its group's,
  /// else product. Leaves under Services and Jobs carry their own today, but
  /// a leaf added later without one should still follow its group.
  String _kindOfCategory(String? slug) {
    final c = _categoryBySlug(slug);
    if (c == null) return 'product';
    return c.defaultKind ?? _categoryBySlug(c.parentSlug)?.defaultKind ?? 'product';
  }

  /// Where a listing of [kind] starts when its current category does not fit.
  ///
  /// For services and jobs, the top-level group the server marks with that
  /// kind ("Services", "Jobs") — read from `default_kind` rather than a slug
  /// list here, so it keeps working if the tree is reorganised. For products,
  /// whatever the seller had before they switched away, if anything.
  String? _homeCategoryFor(String kind) {
    if (kind == 'product') return _lastProductCategory;
    for (final c in _categories) {
      if (c.isRoot && c.defaultKind == kind) return c.slug;
    }
    return null;
  }

  /// Keep the category in step with a kind the seller just chose.
  ///
  /// A category that already fits is left alone — "Food › Catering" is a
  /// perfectly good home for a service. Only a mismatch moves it, and the
  /// product category being left behind is remembered for the way back.
  void _alignCategoryWithKind(String kind) {
    if (_categories.isEmpty) return;
    final current = _kindOfCategory(_selectedCategory);
    if (_selectedCategory != null && current == kind) return;
    if (_selectedCategory != null && current == 'product') {
      _lastProductCategory = _selectedCategory;
    }
    final home = _homeCategoryFor(kind);
    _selectedCategory = home;
    // Restoring the seller's own earlier product choice is not a guess.
    _categoryAutoPicked = home != null && kind != 'product';
  }

  /// Which pricing modes make sense for a given kind.
  ///
  /// A job is not sold by the day and is never "free", so offering those would
  /// only invite nonsense listings. A product can be given away — that is what
  /// the `verschenken` category has always been for — but is not billed hourly.
  static List<String> _priceModesFor(String kind) {
    switch (kind) {
      case 'service':
        return const [
          'fixed', 'from', 'hourly', 'daily', 'negotiable', 'on_request', 'free',
        ];
      case 'job':
        return const ['fixed', 'from', 'hourly', 'daily', 'negotiable', 'on_request'];
      default:
        return const ['fixed', 'from', 'negotiable', 'on_request', 'free'];
    }
  }

  String _priceModeLabel(String mode) {
    final l10n = context.l10n;
    switch (mode) {
      case 'from':
        return l10n.priceModeFromLabel;
      case 'hourly':
        return l10n.priceModeHourly;
      case 'daily':
        return l10n.priceModeDaily;
      case 'negotiable':
        return l10n.priceNegotiable;
      case 'on_request':
        return l10n.priceOnRequest;
      case 'free':
        return l10n.priceFree;
      default:
        return l10n.priceModeFixed;
    }
  }

  String _kindLabel(String kind) {
    final l10n = context.l10n;
    switch (kind) {
      case 'service':
        return l10n.listingKindService;
      case 'job':
        return l10n.listingKindJob;
      default:
        return l10n.listingKindProduct;
    }
  }

  String _kindHint(String kind) {
    final l10n = context.l10n;
    switch (kind) {
      case 'service':
        return l10n.createKindServiceHint;
      case 'job':
        return l10n.createKindJobHint;
      default:
        return l10n.createKindProductHint;
    }
  }

  /// Switch kind, keeping the rest of the form coherent.
  ///
  /// The mode list differs per kind, so a service priced "per hour" that
  /// becomes a product would otherwise hold a mode its own dropdown no longer
  /// offers — which asserts inside DropdownButtonFormField rather than failing
  /// quietly.
  void _setKind(String kind, {required bool byUser}) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      if (byUser) {
        _kindChosenByUser = true;
        _alignCategoryWithKind(kind);
      }
      if (!_priceModesFor(kind).contains(_priceMode)) _priceMode = 'fixed';
    });
    if (byUser) _categoryFieldKey.currentState?.didChange(_selectedCategory);
  }

  /// Localized display label for a condition. The stable value ([cond]) is
  /// still what gets sent to the API; only what the user sees is translated.
  String _conditionLabel(String cond) {
    final l10n = context.l10n;
    switch (cond) {
      case 'Like New':
        return l10n.createConditionLikeNew;
      case 'Used':
        return l10n.createConditionUsed;
      case 'Refurbished':
        return l10n.createConditionRefurbished;
      case 'New':
      default:
        return l10n.createConditionNew;
    }
  }

  /// The category's details: sizes for clothes and shoes, what a service
  /// covers. Nothing at all for a category without a template.
  List<Widget> _detailsSection() {
    final fields = _attrFields;
    if (fields.isEmpty) return const [];
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    return [
      Text(
        l10n.createDetailsTitle,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        l10n.createDetailsHelp,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      for (final f in fields) ...[
        _attrInput(f, locale),
        const SizedBox(height: 16),
      ],
    ];
  }

  Widget _attrInput(AttrField f, Locale locale) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final label = f.required ? '${f.label(locale)} *' : f.label(locale);
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));

    Widget chipsBlock(List<Widget> chips) {
      final missing =
          _attrTried && f.required && !AttrField.answered(_attributes[f.key]);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
          if (missing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.createDetailsRequired,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      );
    }

    switch (f.type) {
      case 'multi':
        final picked = (_attributes[f.key] is List)
            ? List<String>.from(_attributes[f.key] as List)
            : <String>[];
        return chipsBlock([
          for (final o in f.options)
            FilterChip(
              label: Text(o.label(locale)),
              selected: picked.contains(o.value),
              onSelected: (on) => setState(() {
                if (on) {
                  picked.add(o.value);
                } else {
                  picked.remove(o.value);
                }
                _attributes[f.key] = picked;
              }),
            ),
        ]);
      case 'single':
        return chipsBlock([
          for (final o in f.options)
            ChoiceChip(
              label: Text(o.label(locale)),
              selected: _attributes[f.key] == o.value,
              onSelected: (on) =>
                  setState(() => _attributes[f.key] = on ? o.value : null),
            ),
        ]);
      case 'bool':
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: _attributes[f.key] == true,
          onChanged: (v) => setState(() => _attributes[f.key] = v),
        );
      case 'number':
        return TextFormField(
          controller: _attrCtl(f.key),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            hintText: f.hint(locale),
            border: border,
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty)
              return f.required ? l10n.createDetailsRequired : null;
            final n = num.tryParse(t.replaceAll(',', '.'));
            if (n == null ||
                (f.min != null && n < f.min!) ||
                (f.max != null && n > f.max!)) {
              return l10n.createDetailsNumber;
            }
            return null;
          },
        );
      default:
        return TextFormField(
          controller: _attrCtl(f.key),
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: label,
            hintText: f.hint(locale),
            border: border,
            counterText: '',
          ),
          validator: (v) => f.required && (v ?? '').trim().isEmpty
              ? l10n.createDetailsRequired
              : null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEditing = widget.initialListing != null;
    final totalImagesCount = _existingImages.length + _newImageFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.createEditItem : l10n.createAddNewItem),
      ),
      body: SingleChildScrollView(
        // The submit button is the last thing in the scroll: keep it above
        // the system navigation bar.
        padding: EdgeInsets.fromLTRB(16, 16, 16, safeBottom(context, 16)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.createPhotos,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              // Still asked for, just not demanded: a photo is the whole card
              // for a product, while a job advert is text and forcing a
              // picture of a vacancy only produces stock photography.
              if (!_isProduct) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.createPhotosOptional,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: totalImagesCount + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return GestureDetector(
                        onTap: _showImagePickerModal,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: scheme.primary),
                              const SizedBox(height: 4),
                              Text(l10n.createAddMedia,
                                  style: TextStyle(
                                      fontSize: 12, color: scheme.primary)),
                            ],
                          ),
                        ),
                      );
                    }

                    final itemIndex = index - 1;
                    if (itemIndex < _existingImages.length) {
                      final existing = _existingImages[itemIndex];
                      return _buildImagePreview(
                        existing.url,
                        existing.id == null
                            ? null
                            : () => _removeExistingImage(itemIndex),
                      );
                    } else {
                      final newFileIndex = itemIndex - _existingImages.length;
                      return _buildImagePreview(
                        _newImageFiles[newFileIndex].path,
                            () => _removeNewImage(newFileIndex),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),

              // WHAT KIND OF THING IS THIS
              //
              // First, because it decides which of the fields below are even
              // shown. Segmented rather than a dropdown: there are exactly
              // three and the choice changes the rest of the form, so it
              // should be visible rather than folded away.
              Text(
                l10n.createKindLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  for (final k in const ['product', 'service', 'job'])
                    ButtonSegment(value: k, label: Text(_kindLabel(k))),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (sel) =>
                    _setKind(sel.first, byUser: true),
              ),
              const SizedBox(height: 6),
              Text(
                _kindHint(_kind),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              // CATEGORY SELECTOR
              //
              // A sheet rather than a dropdown. The category list is a
              // two-level tree of roughly ninety entries now; a dropdown is a
              // single unsearchable column, so finding "Groceries" meant
              // scrolling past everything the marketplace sells.
              FormField<String>(
                key: _categoryFieldKey,
                initialValue: _selectedCategory,
                validator: (_) => _selectedCategory == null
                    ? l10n.createPleaseChooseCategory
                    : null,
                builder: (field) {
                  final chosen = _selectedCategory != null;
                  return InkWell(
                    onTap: _categories.isEmpty
                        ? null
                        : () async {
                            await _pickCategory();
                            // Clears the error the moment a choice is made,
                            // instead of leaving it under a filled-in field
                            // until the next save attempt.
                            field.didChange(_selectedCategory);
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      isEmpty: false,
                      decoration: InputDecoration(
                        labelText: l10n.createSelectCategory,
                        errorText: field.errorText,
                        helperText: _categoryAutoPicked
                            ? l10n.createCategoryAutoPicked
                            : null,
                        helperMaxLines: 2,
                        suffixIcon: const Icon(Icons.expand_more),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          if (chosen) ...[
                            Icon(
                              categoryIcon(
                                _categoryBySlug(_selectedCategory) ??
                                    api.Category(
                                        slug: _selectedCategory!,
                                        label: _selectedCategory!),
                              ),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              _categoryFieldText(context),
                              overflow: TextOverflow.ellipsis,
                              style: chosen
                                  ? null
                                  : TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // DETAILS — whatever the chosen category asks for.
              ..._detailsSection(),

              // TITLE FIELD
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.createListingTitle,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) =>
                val == null || val.isEmpty ? l10n.createPleaseEnterTitle : null,
              ),
              const SizedBox(height: 16),

              // DESCRIPTION FIELD
              //
              // The detail screen has always had a place for this and fell back
              // to "no description" for every listing, because there was
              // nowhere in the app to write one.
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                maxLength: 8000,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.createDescription,
                  hintText: l10n.createDescriptionHint,
                  helperText: l10n.createDescriptionOptional,
                  alignLabelWithHint: true,
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // PRICING
              //
              // The mode comes first because it decides whether an amount is
              // asked for at all. "Negotiable" and "On request" store 0 —
              // `price_cents` is still NOT NULL — and are rendered from the
              // mode, so there is nothing to type and no stale number left
              // sitting behind the word.
              DropdownButtonFormField<String>(
                value: _priceMode,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.createPriceModeLabel,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  for (final mode in _priceModesFor(_kind))
                    DropdownMenuItem(
                        value: mode, child: Text(_priceModeLabel(mode))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _priceMode = val);
                },
              ),
              if (_wantsAmount) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: _isProduct ? 2 : 1,
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: l10n.createPriceLabel,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          // Only demanded for the modes that carry a number;
                          // the field is not even built for the others.
                          if (val == null || val.isEmpty) {
                            return l10n.createEnterPrice;
                          }
                          final n = double.tryParse(val.replaceAll(',', '.'));
                          // Parsed the same way submission parses it. The old
                          // validator used double.tryParse on the raw text, so
                          // "1,5" failed here and would have parsed on save.
                          if (n == null) return l10n.createInvalidPrice;
                          // A negative used to pass this and get rejected by
                          // the server as a generic API failure.
                          if (n < 0) return l10n.createInvalidPrice;
                          return null;
                        },
                      ),
                    ),
                    // Quantity is a product idea. You do not have three of a
                    // plumbing visit, and 0048 constrains non-products to one.
                    if (_isProduct) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.createQuantity,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return l10n.createEnterQuantity;
                            }
                            final qty = int.tryParse(val);
                            if (qty == null || qty < 1) {
                              return l10n.createMinQuantity;
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // CONDITION SELECTOR — products only. The four values are
              // New/Like New/Used/Refurbished, which describe an object.
              if (_isProduct) ...[
                DropdownButtonFormField<String>(
                  value: _selectedCondition,
                  decoration: InputDecoration(
                    labelText: l10n.createCondition,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _conditions.map((cond) {
                    return DropdownMenuItem(
                        value: cond, child: Text(_conditionLabel(cond)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCondition = val);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // LOCATION
              //
              // Free text, with suggestions rather than a fixed list. The
              // column is a plain string and always has been; anything that
              // forced a choice from a dropdown would exclude every seller
              // outside the towns somebody thought to type into this file.
              LayoutBuilder(
                builder: (context, constraints) => RawAutocomplete<String>(
                  textEditingController: _locationController,
                  focusNode: _locationFocus,
                  optionsBuilder: (value) {
                    final q = foldForSearch(value.text.trim());
                    if (q.isEmpty) return const Iterable<String>.empty();
                    return _locationSuggestions
                        .where((s) => foldForSearch(s).contains(q))
                        .take(6);
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) =>
                          TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => onFieldSubmitted(),
                    decoration: InputDecoration(
                      labelText: l10n.createListingLocation,
                      hintText: l10n.createListingLocationHint,
                      // "collect the item" is about handing over an object.
                      helperText: _isProduct
                          ? l10n.createListingLocationHelp
                          : l10n.createLocationHelperService,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    // Optional, so no required-check. The cap matches the
                    // API's, which would otherwise reject the whole save with
                    // a validation error naming a field the form never
                    // flagged.
                    validator: (val) => (val != null && val.trim().length > 120)
                        ? l10n.createListingLocationTooLong
                        : null,
                  ),
                  optionsViewBuilder: (context, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, i) {
                            final option = options.elementAt(i);
                            return ListTile(
                              dense: true,
                              leading:
                                  const Icon(Icons.location_on_outlined, size: 18),
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // The coordinate behind the words. Optional, and additive: it
              // never touches the text above, and skipping it costs the seller
              // nothing except appearing in "near me" without a distance.
              Row(
                children: [
                  if (_capturedPoint == null)
                    TextButton.icon(
                      onPressed: _capturingPoint ? null : _captureLocation,
                      icon: _capturingPoint
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(l10n.createUseMyLocation),
                    )
                  else ...[
                    const Icon(Icons.check_circle,
                        size: 18, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.createLocationCaptured,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _capturedPoint = null),
                      child: Text(l10n.createLocationRemove),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              // GUARANTEE CHECKBOX — products only. A warranty is a promise
              // about an object; a job advert cannot carry one.
              if (_isProduct) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.createIncludesGuarantee),
                  value: _hasGuarantee,
                  onChanged: (val) =>
                      setState(() => _hasGuarantee = val ?? false),
                ),
              ],
              const SizedBox(height: 24),

              // SUBMIT BUTTON
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: scheme.onPrimary),
                      )
                    : Text(isEditing ? l10n.createSaveChanges : l10n.createPublishItem,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}