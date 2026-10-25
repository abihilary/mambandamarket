import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../api/api_client.dart';
import '../api/models.dart' as api;
import '../api/listing_attributes.dart';
import '../api/listing_guide.dart';
import '../api/listing_presentation.dart';
import '../api/location_service.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../Components/category_icons.dart';
import '../Components/category_picker.dart';
import '../Components/local_image.dart';
import '../Components/safe_bottom.dart';
import '../theme/breakpoints.dart';

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
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();

  /// The photo row, so a fresh pick can be scrolled into view: the next empty
  /// tile sits after the photos, off screen once there are a few.
  final ScrollController _photoScroll = ScrollController();

  /// The server's cap on photos per listing.
  static const int _maxPhotos = 12;

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
    'Bastos, Yaoundé', 'Biyem-Assi, Yaoundé', 'Odza, Yaoundé',
    'Essos, Yaoundé', 'Mvan, Yaoundé', 'Ngoa-Ekellé, Yaoundé',
    'Mvog-Mbi, Yaoundé', 'Emana, Yaoundé', 'Nlongkak, Yaoundé',
    'Mendong, Yaoundé', 'Etoudi, Yaoundé', 'Omnisport, Yaoundé',
    'Molyko, Buea', 'Great Soppo, Buea', 'Mile 17, Buea',
    'Up Station, Bamenda', 'Nkwen, Bamenda',
    'Douala', 'Yaoundé', 'Bafoussam', 'Bamenda', 'Garoua', 'Maroua',
    'Ngaoundéré', 'Bertoua', 'Buea', 'Limbe', 'Kribi', 'Ebolowa', 'Kumba',
    'Edéa', 'Dschang', 'Foumban', 'Nkongsamba', 'Sangmélima', 'Bafang',
    'Mbouda', 'Tiko', 'Loum',
  ];

  /// The only conditions the API accepts, and the only ones the chips offer.
  /// Anything else — including the empty string the seller hub sends for a
  /// listing with no condition — is filtered out on the way in and read as
  /// "not chosen yet".
  static const List<String> _conditions = [
    'New',
    'Like New',
    'Used',
    'Refurbished',
  ];

  /// Category **slug** (the API's identifier), not the display label.
  String? _selectedCategory;

  /// product | service | job. It decides which of the fields below are even
  /// asked for — a job has no quantity, no condition, no stock and nothing to
  /// deliver. Normally it follows the category's `default_kind`; the seller
  /// can still set it from the line under the category.
  String _kind = 'product';

  /// Whether the kind control is open. Folded to one quiet line by default:
  /// the category already says what the listing is in nearly every case.
  bool _showKind = false;

  /// Set once the seller picks the kind themselves, so that choosing a
  /// category afterwards cannot quietly overrule them. Without this, a
  /// plumber who marks a listing a Service and then picks "Repairs" has it
  /// flipped back under them by the category default.
  bool _kindChosenByUser = false;

  /// Whether [_kind] and [_priceMode] are the edited listing's own. The seller
  /// hub and the store dashboard hand over neither, so until the listing is
  /// read they are only the defaults, and saving those turned a tutor's "on
  /// request" service into a fixed-price product. One still unknown at save
  /// time is left out of it, and the server keeps the stored value.
  bool _kindKnown = true;
  bool _modeKnown = true;

  /// The read of the edited listing while it is on its way. A save waits for
  /// it rather than writing defaults over what it is about to say.
  Future<void>? _detailFetch;

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
    'on_request',
    'free',
  };

  bool get _wantsAmount => !_amountlessModes.contains(_priceMode);

  /// Negotiable shows the price box but does not insist on it: "50.000 FCFA,
  /// negotiable" is how most sellers put it, and a bare "Negotiable" is still
  /// allowed (0062). Left empty, 0 is stored and the listing reads
  /// "Negotiable".
  bool get _amountOptional => _priceMode == 'negotiable';
  bool get _isProduct => _kind == 'product';

  /// No default. Until 1.0.46 this started on 'New', and 45 of the first 53
  /// products went out as "New" because nobody changed it — which made the
  /// word mean nothing. Now the seller picks; editing starts from what is
  /// stored, and a listing stored without one has to pick too.
  String? _selectedCondition;
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

  /// What the listing being edited had when the form opened: its category
  /// and its details. Together they decide whether required details may be
  /// insisted on (see [_enforceRequired]).
  String? _originalCategory;
  Map<String, dynamic> _originalAttributes = const {};

  /// Set once the edited listing's stored details are known, so the "new
  /// details" banner does not flash over a listing whose answers are still
  /// on their way.
  bool _attributesLoaded = false;

  /// One key per detail, so a failed save can scroll to the first one that
  /// stopped it. Keyed by field key; the condition has its own.
  final Map<String, GlobalKey> _fieldKeys = {};
  final GlobalKey _conditionKey = GlobalKey();
  GlobalKey _fieldKey(String key) => _fieldKeys.putIfAbsent(key, GlobalKey.new);

  /// The "More details (optional)" fold, opened from code when a save fails
  /// inside it or an edited listing already has answers in it.
  final ExpansibleController _moreDetails = ExpansibleController();
  bool _moreAutoOpened = false;

  /// Description prompts already tapped on this visit, so each adds its
  /// starter once.
  final Set<String> _usedPrompts = {};

  List<AttrField> get _attrFields =>
      api.attributeFieldsFor(_categories, _selectedCategory);

  ListingGuide get _guide => api.guideFor(_categories, _selectedCategory);

  bool get _categoryChanged =>
      _editingId != null && _selectedCategory != _originalCategory;

  /// Whether required details block the save.
  ///
  /// Always for a new listing. For an edit, only when the seller moves it to
  /// another category or it already had details: a listing filed before its
  /// category had a template must stay editable — refusing a price change
  /// until a phone's storage is filled in would be the form punishing the
  /// seller for our new template. The banner asks instead, and anything they
  /// do fill in is still checked. The server applies the same rule (§4.3).
  bool get _enforceRequired =>
      _editingId == null || _categoryChanged || _originalAttributes.isNotEmpty;

  TextEditingController _attrCtl(AttrField f) =>
      _attrControllers.putIfAbsent(
        f.key,
        () => TextEditingController(text: _attrText(f, _attributes[f.key])),
      );

  /// A stored answer as the box should show it: grouped numbers with their
  /// dots ("145.000"), since the formatter only runs on what is typed.
  String _attrText(AttrField? f, dynamic v) {
    if (v == null) return '';
    if (f != null && f.type == 'number' && f.grouped && v is num) {
      return NumberFormat.decimalPattern('de_DE').format(v);
    }
    return v.toString();
  }

  /// A number box read back the way it was written: thousands dots dropped
  /// where the field groups them, and a decimal comma accepted everywhere.
  num? _parseNumber(AttrField f, String text) {
    var t = text.trim().replaceAll(' ', '').replaceAll('\u00A0', '');
    if (f.grouped) t = t.replaceAll('.', '');
    return num.tryParse(t.replaceAll(',', '.'));
  }

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
      _originalCategory = _selectedCategory;
      final condition = listing['condition']?.toString();
      _selectedCondition = _conditions.contains(condition) ? condition : null;
      _kind = (listing['kind'] ?? listing['kind_slug'])?.toString() ?? 'product';
      _kindKnown = (listing['kind'] ?? listing['kind_slug']) != null;
      // An existing listing's kind is the seller's own earlier decision, so
      // re-picking the category while editing must not overwrite it.
      _kindChosenByUser = true;
      _priceMode = listing['priceMode']?.toString() ??
          listing['price_mode']?.toString() ??
          'fixed';
      _modeKnown = (listing['priceMode'] ?? listing['price_mode']) != null;
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
        _originalAttributes = Map.of(_attributes);
        _attributesLoaded = true;
      }
      // Nor the kind and price mode; the same read supplies them.
      if (attrs is! Map || !_kindKnown || !_modeKnown) {
        _detailFetch = _loadExistingAttributes();
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
    // A negotiable listing at 0 has no price; an empty box says so, "0" would
    // read as giving it away.
    final mode = listing['priceMode'] ?? listing['price_mode'];
    if (cents == 0 && mode == 'negotiable') return '';
    final currency = (listing['currency'] ?? 'XAF').toString();
    final amount = api.fromMinorUnits(cents, currency: currency);
    // Written the way the box writes it: "145.000" in FCFA; elsewhere 12.5,
    // not 145000.0 — the box is a text field and that ends up in front of
    // the seller.
    if (_noMinorUnit(currency)) {
      return NumberFormat.decimalPattern('de_DE').format(amount);
    }
    return amount == amount.roundToDouble()
        ? amount.round().toString()
        : amount.toString();
  }

  /// The listing's currency: the caller's when editing, else the API's default.
  String get _currency =>
      (widget.initialListing?['currency'] ?? 'XAF').toString();

  static bool _noMinorUnit(String currency) =>
      api.toMinorUnits(1, currency: currency) == 1;

  /// FCFA has no cents, so its prices are whole numbers written with
  /// thousands dots ("300.000"), as on every card. The box groups them while
  /// typing and reads the dots back as thousands.
  bool get _wholeUnits => _noMinorUnit(_currency);

  /// The price box read back the way it is shown. In whole units "350.000"
  /// is 350 000: read with the dot as a decimal point it saved 350 FCFA, and
  /// the low-price check did not even ask. Elsewhere either mark is the
  /// decimal point, as before.
  double? _parsePrice(String text) {
    var t = text.trim().replaceAll(' ', '').replaceAll(' ', '');
    if (_wholeUnits) t = t.replaceAll('.', '');
    return double.tryParse(t.replaceAll(',', '.'));
  }

  /// Read the edited listing for what the caller's map left out: its details
  /// and, from the dashboards, its kind and price mode. Anything the seller
  /// already changed on screen meanwhile is kept.
  Future<void> _loadExistingAttributes() async {
    final id = _editingId;
    if (id == null) return;
    final given = widget.initialListing!;
    try {
      final listing = await ListingsRepository.instance.detail(id);
      if (!mounted) return;
      setState(() {
        if (given['attributes'] is! Map) {
          _attributes
            ..clear()
            ..addAll(listing.attributes);
          _originalAttributes = Map.of(listing.attributes);
          _attributesLoaded = true;
          final fields = {for (final f in _attrFields) f.key: f};
          for (final e in _attrControllers.entries) {
            e.value.text = _attrText(fields[e.key], _attributes[e.key]);
          }
        }
        if (!_kindKnown) {
          _kind = listing.kind;
          _kindKnown = true;
        }
        if (!_modeKnown) {
          // The box was filled before the mode was known, so a negotiable
          // listing at 0 opened on "0". Refilled unless the seller typed.
          if (_priceController.text == _priceFieldFor(given)) {
            _priceController.text =
                _priceFieldFor({...given, 'priceMode': listing.priceMode});
          }
          _priceMode = listing.priceMode;
          _modeBeforeNarrowing = null;
          _modeKnown = true;
        }
        // The dashboards send "" for a listing stored without one.
        if (!_conditions.contains(given['condition']?.toString()) &&
            _conditions.contains(listing.condition)) {
          _selectedCondition ??= listing.condition;
        }
        if (given['hasGuarantee'] == null) _hasGuarantee = listing.hasGuarantee;
        _syncPriceMode();
      });
    } catch (_) {
      // Left empty; the seller can fill them in again, and the server says
      // which are required if they do not. A kind or mode still unknown stays
      // out of the save, so the stored one is kept.
    } finally {
      _detailFetch = null;
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
          final n = _parseNumber(f, _attrCtl(f).text);
          if (n != null) out[f.key] = n;
        case 'text':
          final t = _attrCtl(f).text.trim();
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
        // Keep any pre-selected slug that still exists. Otherwise nothing:
        // this used to fall back to the first category in the list, which is
        // the Electronics group, and that silent default is part of why a
        // car ended up filed under Électronique. The category is now the
        // form's first question, and the seller answers it.
        if (!cats.any((c) => c.slug == _selectedCategory)) {
          // A seller who chose Service or Job before the list arrived gets
          // that group.
          _selectedCategory = _homeCategoryFor(_kind);
        }
        // The category's guide may narrow the price modes ("À donner" is
        // free only), which it could not before the list arrived.
        _syncPriceMode();
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

  int get _photoCount => _existingImages.length + _newImageFiles.length;

  /// Add what was picked, up to the server's cap. Past it, the rest is left
  /// out and the seller is told why, rather than the save failing later on a
  /// thirteenth upload.
  void _addPhotos(List<XFile> files) {
    if (files.isEmpty || !mounted) return;
    final room = _maxPhotos - _photoCount;
    if (room > 0) {
      setState(() => _newImageFiles.addAll(files.take(room)));
      // The next empty tile is after the photos; bring it into view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_photoScroll.hasClients) return;
        _photoScroll.animateTo(
          _photoScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
    if (files.length > room) _showPhotoCap();
  }

  void _showPhotoCap() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.createPhotoMax(_maxPhotos))),
    );
  }

  Future<void> _pickImageFromCamera() async {
    final l10n = context.l10n;
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (photo != null) _addPhotos([photo]);
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

      _addPhotos(images);
    } catch (e) {
      _showErrorSnackBar(l10n.createFailedToPickImages(e.toString()));
    }
  }

  void _showImagePickerModal() {
    final l10n = context.l10n;
    if (_photoCount >= _maxPhotos) {
      _showPhotoCap();
      return;
    }
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

  /// Whether [f] is what stops the save: a required answer missing (when
  /// required answers are insisted on), or a number that is not one or is out
  /// of the template's range.
  bool _detailProblem(AttrField f, Map<String, dynamic> answers) {
    if (_enforceRequired && f.required && !AttrField.answered(answers[f.key])) {
      return true;
    }
    if (f.type != 'number') return false;
    final t = _attrCtl(f).text.trim();
    if (t.isEmpty) return false;
    final n = _parseNumber(f, t);
    return n == null ||
        (f.min != null && n < f.min!) ||
        (f.max != null && n > f.max!);
  }

  /// Bring the first detail that stopped the save into view, opening the
  /// fold first when it is in there. Required fields are never folded, but an
  /// out-of-range number can be.
  void _revealFirstProblem(Map<String, dynamic> answers, bool conditionMissing) {
    GlobalKey? target;
    var folded = false;
    if (conditionMissing) {
      target = _conditionKey;
    } else {
      final split = _foldFields(displayFields(_attrFields));
      for (final f in [...split.shown, ...split.folded]) {
        if (_detailProblem(f, answers)) {
          target = _fieldKey(f.key);
          folded = split.folded.contains(f);
          break;
        }
      }
    }
    if (target == null) return;
    void reveal() {
      final c = target!.currentContext;
      if (c == null || !c.mounted) return;
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }

    if (folded && !_moreDetails.isExpanded) {
      _moreDetails.expand();
      // After the fold has opened, or the field is still zero height.
      Future.delayed(const Duration(milliseconds: 300), reveal);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
    }
  }

  /// "13 FCFA for this item — is that right?" Under 100 FCFA is nearly always
  /// a slip — dropped zeros or a stray key — and one live listing went out
  /// at 13 FCFA. It asks; it never refuses.
  Future<bool> _confirmLowPrice(String price) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.createPriceCheck(price)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.createPriceCheckFix),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.createPriceCheckYes),
          ),
        ],
      ),
    );
    if (ok == true) return true;
    if (mounted) _priceFocus.requestFocus();
    return false;
  }

  Future<void> _submitForm() async {
    final l10n = context.l10n;
    if (_isSubmitting) return;
    // Opened from a dashboard, the form learns the listing's kind, price mode
    // and details from a read that may still be on its way. Saving before it
    // lands would write the defaults over them, so wait, spinner showing.
    final pending = _detailFetch;
    if (pending != null) {
      setState(() => _isSubmitting = true);
      await pending;
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
    final guide = _guide;
    // Every problem shows on the first failed attempt, not one per tap.
    setState(() {
      _attrTried = true;
      _syncPriceMode();
    });
    final formOk = _formKey.currentState!.validate();
    final attributes = _collectAttributes();
    // Condition is an object's, and means nothing on a plot of land or a
    // flat to rent, where the category's guide switches it off.
    final asksCondition = _isProduct && guide.condition;
    final conditionMissing = asksCondition && _selectedCondition == null;
    if (!formOk) {
      _revealFirstProblem(attributes, conditionMissing);
      return;
    }

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
    if (conditionMissing) {
      _revealFirstProblem(attributes, true);
      _showErrorSnackBar(l10n.createConditionPick);
      return;
    }
    // Text and number details are checked by their own validators above;
    // chips and switches have no validator, so the required ones are here —
    // and only when insisting is fair (see _enforceRequired). Otherwise the
    // banner over the details asks, and the save goes through.
    final locale = Localizations.localeOf(context);
    final missing = !_enforceRequired
        ? const <String>[]
        : _attrFields
            .where((f) => f.required && !AttrField.answered(attributes[f.key]))
            .map((f) => f.label(locale))
            .toList();
    if (missing.isNotEmpty) {
      _revealFirstProblem(attributes, false);
      _showErrorSnackBar(l10n.createDetailsMissing(missing.join(', ')));
      return;
    }

    if (_isProduct && _wantsAmount) {
      final amount = _parsePrice(_priceController.text) ?? 0;
      // An empty negotiable box is "Negotiable", not a price of nothing.
      final bare = amount == 0 && _amountOptional;
      if (!bare && amount < 100) {
        final ok = await _confirmLowPrice(api.formatPrice(
            api.toMinorUnits(amount, currency: _currency),
            currency: _currency));
        if (!ok || !mounted) return;
      }
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
      // In the listing's own currency, the one the box was filled from: a
      // euro price read back as FCFA lost its cents and shrank 100x.
      final priceCents = _wantsAmount
          ? api.toMinorUnits(
              _parsePrice(_priceController.text) ?? 0,
              currency: _currency,
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
          // Left out while unknown (the listing could not be read): the
          // server then keeps the stored ones instead of taking defaults.
          if (_kindKnown) 'kind': _kind,
          if (_modeKnown) 'price_mode': _priceMode,
          // Null for anything that is not an object, or where the category
          // says condition means nothing (land). The server normalises this
          // too, but sending the right shape keeps the two in step.
          'condition': asksCondition ? _selectedCondition : null,
          'has_guarantee': _isProduct && guide.warranty && _hasGuarantee,
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
        condition: asksCondition ? _selectedCondition : null,
        hasGuarantee: _isProduct && guide.warranty && _hasGuarantee,
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

  Widget _buildImagePreview(
    String path,
    VoidCallback? onRemove, {
    bool cover = false,
  }) {
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
            child: Tappable(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.danger,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        // The first photo is the one every card and preview shows.
        if (cover)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.l10n.createCoverBadge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// An empty tile named after the next photo the category's shot list asks
  /// for ("Battery health screen"). It opens the picker like the plain one.
  /// Nothing is ever ticked: a photo count says nothing about which shot was
  /// taken.
  Widget _ghostTile(String label) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Tappable(
      onTap: _showImagePickerModal,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: Theme.of(context).colorScheme.outline,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 20, color: muted),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: muted, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addPhotoTile() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tappable(
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
            Icon(Icons.add_a_photo_outlined, color: scheme.primary),
            const SizedBox(height: 4),
            Text(context.l10n.createAddMedia,
                style: TextStyle(fontSize: 12, color: scheme.primary)),
          ],
        ),
      ),
    );
  }

  /// Photos: a counter against the cap, the cover marked, then up to two
  /// tiles naming the next shots on the category's list, the list itself
  /// folded away, and an advisory minimum that never blocks.
  List<Widget> _photosSection(ListingGuide guide) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final n = _photoCount;
    final tips = guide.photoTips;
    final ghosts = n >= _maxPhotos
        ? const <GuideTip>[]
        : tips.skip(n).take(math.min(2, _maxPhotos - n)).toList();
    // The plain tile only when the shot list has run out (or there is none):
    // a named tile already does its job.
    final showAdd = n < _maxPhotos && ghosts.isEmpty;
    final minimum = guide.photoMin;

    return [
      Row(
        children: [
          Expanded(
            child: Text(l10n.createPhotos,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Text(
            l10n.createPhotoCount(n, _maxPhotos),
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      ),
      // Still asked for, just not demanded: a photo is the whole card for a
      // product, while a job advert is text and forcing a picture of a
      // vacancy only produces stock photography.
      if (!_isProduct) ...[
        const SizedBox(height: 2),
        Text(
          l10n.createPhotosOptional,
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
      const SizedBox(height: 8),
      SizedBox(
        height: 100,
        child: ListView.builder(
          controller: _photoScroll,
          scrollDirection: Axis.horizontal,
          itemCount: n + ghosts.length + (showAdd ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < _existingImages.length) {
              final existing = _existingImages[index];
              return _buildImagePreview(
                existing.url,
                existing.id == null ? null : () => _removeExistingImage(index),
                cover: index == 0,
              );
            }
            if (index < n) {
              final newFileIndex = index - _existingImages.length;
              return _buildImagePreview(
                _newImageFiles[newFileIndex].path,
                () => _removeNewImage(newFileIndex),
                cover: index == 0,
              );
            }
            final ghost = index - n;
            if (ghost < ghosts.length) {
              return _ghostTile(ghosts[ghost].text(locale));
            }
            return _addPhotoTile();
          },
        ),
      ),
      const SizedBox(height: 6),
      Text(l10n.createCoverHint, style: TextStyle(fontSize: 12, color: muted)),
      if (minimum != null && n < minimum)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            l10n.createPhotoMin(minimum),
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
      if (tips.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          shape: const Border(),
          collapsedShape: const Border(),
          controlAffinity: ListTileControlAffinity.leading,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.centerLeft,
          childrenPadding: const EdgeInsets.only(left: 40, bottom: 8),
          title: Text(
            l10n.createPhotoTipsTitle(tips.length),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          children: [
            for (var i = 0; i < tips.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${i + 1}. ${tips[i].text(locale)}',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ),
          ],
        ),
    ];
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
      LocationOutcome.deniedForever => kIsWeb ? l10n.locationDeniedWeb : l10n.locationDeniedForever,
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
    _priceFocus.dispose();
    _descriptionFocus.dispose();
    _photoScroll.dispose();
    _moreDetails.dispose();
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
    // forListing: inside a group the leaves come first and the group itself
    // is the last row, so the first tap lands on something with a template.
    final picked = await showCategoryPicker(
      context,
      categories: _categories,
      selectedSlug: _selectedCategory,
      forListing: true,
    );
    // null means dismissed, which is not the same as cleared.
    if (picked == null || !mounted) return;
    setState(() {
      _selectedCategory = picked;
      _syncPriceMode();
    });

    // Jobs and services are categories the server already knows the shape of,
    // so picking one offers the matching kind — but never overrides a seller
    // who has already answered the question themselves.
    //
    // Back to product too: with the kind folded away under the category, a
    // seller who tapped "Repairs" by mistake and then "Phones" would otherwise
    // be left listing a phone as a service, with no condition asked.
    if (_kindChosenByUser) return;
    _setKind(_kindOfCategory(picked), byUser: false);
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
    _selectedCategory = _homeCategoryFor(kind);
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

  /// The modes offered here: the kind's, narrowed by the category's guide
  /// ("À donner" leaves only Free). A guide that leaves nothing the kind
  /// allows is ignored rather than leaving the seller no way to price.
  List<String> get _priceModes {
    final byKind = _priceModesFor(_kind);
    final only = _guide.priceModes;
    if (only == null) return byKind;
    final both = [for (final m in byKind) if (only.contains(m)) m];
    return both.isEmpty ? byKind : both;
  }

  /// The mode the seller had before a category narrowed the list, so moving
  /// on from "À donner" to Cars gives it back instead of leaving a car
  /// listed as free.
  String? _modeBeforeNarrowing;

  /// Keep [_priceMode] one the chips offer after the kind or category moved.
  /// Call inside setState.
  void _syncPriceMode() {
    final modes = _priceModes;
    final narrowed = _guide.priceModes != null;
    final held = _modeBeforeNarrowing;
    if (!narrowed && held != null) {
      _modeBeforeNarrowing = null;
      if (modes.contains(held)) {
        _priceMode = held;
        return;
      }
    }
    if (modes.contains(_priceMode)) return;
    if (narrowed) _modeBeforeNarrowing ??= _priceMode;
    _priceMode = modes.contains('fixed') ? 'fixed' : modes.first;
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
  /// becomes a product would otherwise hold a mode its own chips no longer
  /// offer, and save a price nothing on screen shows.
  void _setKind(String kind, {required bool byUser}) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      if (byUser) {
        _kindChosenByUser = true;
        _kindKnown = true;
        _alignCategoryWithKind(kind);
      }
      _syncPriceMode();
    });
    if (byUser) _categoryFieldKey.currentState?.didChange(_selectedCategory);
  }

  /// Which fields show and which fold under "More details (optional)".
  ///
  /// Short templates show everything. Past eight fields — a car asks for
  /// nineteen — what shows is what is required, what makes the card, and the
  /// first six; the rest, checklists included, fold. Required fields are
  /// never folded, so a save is never stopped by something out of sight.
  ({List<AttrField> shown, List<AttrField> folded}) _foldFields(
    List<AttrField> fields,
  ) {
    if (fields.length <= 8) return (shown: fields, folded: const <AttrField>[]);
    final firstSix = fields.take(6).toSet();
    bool up(AttrField f) => f.required || f.card != null || firstSix.contains(f);
    return (
      shown: [for (final f in fields) if (up(f)) f],
      folded: [for (final f in fields) if (!up(f)) f],
    );
  }

  /// The category's details, condition first: what the item is, in the
  /// category's own terms — storage for a phone, the advance for a flat,
  /// subjects for a tutor. Nothing at all for a category without a template
  /// where condition does not apply either.
  List<Widget> _detailsSection(ListingGuide guide, Map<String, dynamic> answers) {
    final fields = displayFields(_attrFields);
    final asksCondition = _isProduct && guide.condition;
    if (fields.isEmpty && !asksCondition) return const [];
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final note = guide.note(locale);

    // Progress counts what buyers filter and compare on: required fields,
    // recommended ones and those that make the card. Condition counts when
    // it is asked, since it is required here too.
    final counted = [
      for (final f in fields)
        if (f.required || f.recommended || f.card != null) f,
    ];
    final total = counted.length + (asksCondition ? 1 : 0);
    final done =
        counted.where((f) => AttrField.answered(answers[f.key])).length +
            (asksCondition && _selectedCondition != null ? 1 : 0);

    final split = _foldFields(fields);
    // Editing a listing that already has answers in the fold: open it once,
    // so they are not hidden behind "optional". After the frame, because the
    // tile is only being built now.
    if (!_moreAutoOpened &&
        split.folded.any((f) => AttrField.answered(_originalAttributes[f.key]))) {
      _moreAutoOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moreDetails.expand();
      });
    }

    // A listing filed before its category had a template: say what is new
    // and why it is worth a minute, without blocking the save.
    final category = _categoryBySlug(_selectedCategory);
    final showBanner = _editingId != null &&
        _attributesLoaded &&
        !_enforceRequired &&
        fields.isNotEmpty &&
        category != null;

    List<Widget> inputs(List<AttrField> list) {
      final out = <Widget>[];
      String? section;
      for (final f in list) {
        // A sub-head once over each run of fields sharing one ("Papers").
        final s = f.section(locale);
        if (s != null && s != section) {
          out.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              s,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ));
        }
        section = s;
        out
          ..add(KeyedSubtree(key: _fieldKey(f.key), child: _attrInput(f, locale)))
          ..add(const SizedBox(height: 16));
      }
      return out;
    }

    return [
      Text(
        l10n.createDetailsTitle,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      if (note != null) ...[
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline, size: 16, color: muted),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 2),
      // The count when the template gives something to count; the general
      // line otherwise (the Electronics group asks only brand, model and
      // colour, none of which is required or on the card).
      if (counted.isNotEmpty)
        Text(
          l10n.createDetailsProgress(done, total),
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        )
      else if (fields.isNotEmpty)
        Text(
          l10n.createDetailsHelp,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      if (showBanner) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.tokens.groupSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 18, color: context.tokens.accentInk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.createEditNewDetails(category.displayLabel(locale)),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (asksCondition) ...[
        KeyedSubtree(key: _conditionKey, child: _conditionInput()),
        const SizedBox(height: 16),
      ],
      ...inputs(split.shown),
      if (split.folded.isNotEmpty) ...[
        ExpansionTile(
          controller: _moreDetails,
          // Kept built while folded, so a number typed out of range in there
          // still fails validation instead of being silently dropped.
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.centerLeft,
          childrenPadding: const EdgeInsets.only(top: 4),
          title: Text(
            l10n.createDetailsMore(split.folded.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          children: inputs(split.folded),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  /// Four chips and no default (see [_selectedCondition]).
  Widget _conditionInput() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final missing = _attrTried && _selectedCondition == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.createCondition} *',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _conditions)
              ChoiceChip(
                label: Text(conditionLabel(l10n, c) ?? c),
                selected: _selectedCondition == c,
                onSelected: (on) =>
                    setState(() => _selectedCondition = on ? c : null),
              ),
          ],
        ),
        if (missing)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.createConditionPick,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  /// "Brand *", or "Sizes · recommended" with the second half muted.
  Widget _fieldLabel(AttrField f, Locale locale, {TextStyle? style}) {
    return Text.rich(
      TextSpan(
        text: f.label(locale),
        style: style,
        children: [
          if (f.required) const TextSpan(text: ' *'),
          if (!f.required && f.recommended)
            TextSpan(
              text: ' · ${context.l10n.createDetailsRecommended}',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  /// A single with more options than fit as chips (twelve phone brands,
  /// seventeen car makes): a field showing the choice, opening a searchable
  /// list.
  Widget _optionPickerField(AttrField f, Locale locale) {
    final l10n = context.l10n;
    final value = _attributes[f.key];
    final chosen =
        value is String && value.isNotEmpty ? f.optionLabel(value, locale) : null;
    final missing = _attrTried && _enforceRequired && f.required && chosen == null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _OptionSheet(
            field: f,
            locale: locale,
            selected: chosen == null ? null : value as String,
          ),
        );
        // null is dismissed; '' is the chosen row tapped again, to clear it.
        if (picked == null || !mounted) return;
        setState(() => _attributes[f.key] = picked.isEmpty ? null : picked);
      },
      child: InputDecorator(
        isEmpty: chosen == null,
        decoration: InputDecoration(
          label: _fieldLabel(f, locale),
          helperText: f.hint(locale),
          helperMaxLines: 2,
          errorText: missing ? l10n.createDetailsRequired : null,
          suffixIcon: const Icon(Icons.expand_more),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(chosen ?? '', overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _attrInput(AttrField f, Locale locale) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));

    Widget chipsBlock(List<Widget> chips) {
      final missing = _attrTried &&
          _enforceRequired &&
          f.required &&
          !AttrField.answered(_attributes[f.key]);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A checklist reads as a sub-head over its ticks ("In the box").
          _fieldLabel(
            f,
            locale,
            style: f.isChecklist
                ? const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)
                : theme.textTheme.bodyMedium?.copyWith(
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
      case 'single' when f.options.length > 8:
        return _optionPickerField(f, locale);
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
          title: _fieldLabel(f, locale),
          value: _attributes[f.key] == true,
          onChanged: (v) => setState(() => _attributes[f.key] = v),
        );
      case 'number':
        return TextFormField(
          controller: _attrCtl(f),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Dots while typing where the template groups ("145.000"); they
          // are stripped again by _parseNumber.
          inputFormatters: f.grouped ? [_GroupedNumberFormatter()] : null,
          // The progress line and the title suggestion read these.
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            label: _fieldLabel(f, locale),
            hintText: f.hint(locale),
            suffixText: f.unit(locale),
            border: border,
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) {
              return f.required && _enforceRequired
                  ? l10n.createDetailsRequired
                  : null;
            }
            final n = _parseNumber(f, t);
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
          controller: _attrCtl(f),
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            label: _fieldLabel(f, locale),
            hintText: f.hint(locale),
            border: border,
            counterText: '',
          ),
          validator: (v) =>
              f.required && _enforceRequired && (v ?? '').trim().isEmpty
                  ? l10n.createDetailsRequired
                  : null,
        );
    }
  }

  /// Swap in the suggested title, keeping the seller's own one a tap away.
  /// Never automatic: the suggestion only ever replaces text on this tap.
  void _useSuggestedTitle(String title) {
    final l10n = context.l10n;
    final before = _titleController.value;
    setState(() {
      _titleController.value = TextEditingValue(
        text: title,
        selection: TextSelection.collapsed(offset: title.length),
      );
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.createTitleUsed),
          action: SnackBarAction(
            label: l10n.createUndo,
            onPressed: () {
              if (mounted) setState(() => _titleController.value = before);
            },
          ),
        ),
      );
  }

  /// Append a prompt's starter ("Reason for selling: ") on a line of its own
  /// and leave the cursor after it, ready for the answer. Each prompt is
  /// offered once per visit.
  void _addPrompt(GuidePrompt p, Locale locale) {
    final current = _descriptionController.text;
    final starter = p.starter(locale);
    final text = current.isEmpty
        ? starter
        : current.endsWith('\n')
        ? '$current$starter'
        : '$current\n$starter';
    setState(() {
      _usedPrompts.add(p.en);
      _descriptionController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
    _descriptionFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final locale = Localizations.localeOf(context);
    final isEditing = widget.initialListing != null;

    // Read once per build: every section below follows the same guide and
    // the same answers.
    final guide = _guide;
    final answers = _collectAttributes();
    // As plain text: the formatter's no-break spaces ("145.000 km") have no
    // business in a title the seller goes on editing and buyers search.
    final suggestion =
        suggestTitle(answers, _attrFields, locale, yes: l10n.detailsYes)
            ?.replaceAll('\u00A0', ' ');
    final showSuggestion = suggestion != null &&
        foldForSearch(suggestion).trim() !=
            foldForSearch(_titleController.text).trim();
    final prompts = [
      for (final p in guide.describePrompts)
        if (!_usedPrompts.contains(p.en)) p,
    ];
    final priceLabel = guide.priceLabel(locale);
    final per = guide.pricePer(locale);
    // Only where the amount is the price itself: "per hour" already says
    // what it is per, and the card follows the same rule.
    final perSuffix =
        per != null && const {'fixed', 'from', 'negotiable'}.contains(_priceMode)
            ? '/ $per'
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.createEditItem : l10n.createAddNewItem),
      ),
      body: ContentFrame(
        maxWidth: Breakpoints.form,
        child: SingleChildScrollView(
        // The submit button is the last thing in the scroll: keep it above
        // the system navigation bar.
        padding: EdgeInsets.fromLTRB(16, 16, 16, safeBottom(context, 16)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WHAT IS IT
              //
              // First, because the category decides nearly everything below
              // it: which details are asked, the shot list, the price label,
              // and whether condition or a warranty mean anything at all.
              Text(l10n.createWhatTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),

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
                        errorText: field.errorText,
                        suffixIcon: Icon(
                          chosen ? Icons.edit_outlined : Icons.expand_more,
                        ),
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

              // WHAT KIND OF THING IS THIS
              //
              // Follows the category ("Repairs" is a service) and is folded
              // to one line that says which it took. Tapping it opens the
              // three-way control, for the listing the category gets wrong.
              InkWell(
                onTap: () => setState(() => _showKind = !_showKind),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.createKindLine(_kindLabel(_kind)),
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                      Icon(
                        _showKind ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: muted,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showKind) ...[
                const SizedBox(height: 4),
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
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
              const SizedBox(height: 20),

              // PHOTOS
              ..._photosSection(guide),
              const SizedBox(height: 20),

              // DETAILS — condition, then whatever the chosen category asks.
              ..._detailsSection(guide, answers),

              // TITLE FIELD
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                // The counter and the suggestion below read it.
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.createListingTitle,
                  hintText: guide.titleExample(locale),
                  // Soft: about what a card shows in two lines. The server
                  // still takes 200, so nothing is cut.
                  counterText: '${_titleController.text.length}/70',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) =>
                val == null || val.isEmpty ? l10n.createPleaseEnterTitle : null,
              ),
              // Built from the details, offered, and applied only on tap —
              // never over what the seller typed.
              if (showSuggestion)
                Row(
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 16, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.createTitleSuggestion(suggestion),
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _useSuggestedTitle(suggestion),
                      child: Text(l10n.createTitleUse),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // DESCRIPTION FIELD
              //
              // The detail screen has always had a place for this and fell back
              // to "no description" for every listing, because there was
              // nowhere in the app to write one. The prompts are what buyers
              // of this category ask in chat; each tap starts a line.
              if (prompts.isNotEmpty) ...[
                Text(
                  l10n.createDescPrompts,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final p in prompts)
                      ActionChip(
                        label: Text('+ ${p.label(locale)}'),
                        onPressed: () => _addPrompt(p, locale),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              TextFormField(
                controller: _descriptionController,
                focusNode: _descriptionFocus,
                minLines: 3,
                maxLines: 6,
                maxLength: 8000,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.createDescription,
                  hintText: guide.descriptionHint(locale) ??
                      l10n.createDescriptionHint,
                  hintMaxLines: 3,
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
              // sitting behind the word. Chips, not a dropdown: there are at
              // most seven, and the category may narrow them to one.
              Text(
                l10n.createPriceModeLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in _priceModes)
                    ChoiceChip(
                      label: Text(_priceModeLabel(mode)),
                      selected: _priceMode == mode,
                      onSelected: (_) => setState(() {
                        _priceMode = mode;
                        _modeKnown = true;
                        // The seller's own choice now; nothing to give back.
                        _modeBeforeNarrowing = null;
                      }),
                    ),
                ],
              ),
              if (_wantsAmount || _isProduct) ...[
                const SizedBox(height: 16),
                Row(
                  // Top, not centre: the negotiable hint under the price makes
                  // that box taller, and centring dropped Quantity out of line.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_wantsAmount)
                      Expanded(
                        flex: _isProduct ? 2 : 1,
                        child: TextFormField(
                          controller: _priceController,
                          focusNode: _priceFocus,
                          keyboardType: _wholeUnits
                              ? TextInputType.number
                              : const TextInputType.numberWithOptions(decimal: true),
                          // "300.000" as it is typed, the way the card will
                          // show it, so what is on screen is what is saved.
                          inputFormatters: _wholeUnits
                              ? [_GroupedNumberFormatter(decimal: false)]
                              : null,
                          decoration: InputDecoration(
                            // "Rent (FCFA)", "Salary (FCFA)" where the
                            // category names its price.
                            labelText: priceLabel != null
                                ? l10n.createPriceLabelCustom(priceLabel)
                                : _amountOptional
                                ? l10n.createPriceOptionalLabel
                                : l10n.createPriceLabel,
                            suffixText: perSuffix,
                            helperText: _amountOptional
                                ? l10n.createPriceNegotiableHelper
                                : null,
                            helperMaxLines: 3,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            // Only demanded for the modes that carry a number;
                            // the field is not even built for the others, and
                            // negotiable may leave it empty.
                            if (val == null || val.trim().isEmpty) {
                              return _amountOptional ? null : l10n.createEnterPrice;
                            }
                            final n = _parsePrice(val);
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
                      )
                    else
                      const Spacer(flex: 2),
                    // Quantity is a product idea. You do not have three of a
                    // plumbing visit, and 0048 constrains non-products to one.
                    // Asked even for a free or on-request product, which used
                    // to hide it along with the price.
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

              // LOCATION
              //
              // Free text, with suggestions rather than a fixed list. The
              // column is a plain string and always has been; anything that
              // forced a choice from a dropdown would exclude every seller
              // outside the towns somebody thought to type into this file.
              // "Neighbourhood, town" because both are what a buyer needs:
              // "Akwa" alone does not say Douala to someone in Buea.
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
                      labelText: l10n.createLocationLabel,
                      hintText: l10n.createLocationExample,
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
                    // Flexible: "Utiliser ma position actuelle" at a large
                    // text size is wider than a 360 dp phone.
                    Flexible(
                      child: TextButton.icon(
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
                      ),
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
              // about an object; a job advert cannot carry one, and neither
              // can a flat to rent (the category's guide switches it off).
              if (_isProduct && guide.warranty) ...[
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
      ),
    );
  }
}

/// Thousands dots while typing ("145000" → "145.000"), the way prices and
/// mileages are written here. Digits and, unless [decimal] is off, one
/// decimal comma survive; the dots are display only and come off on save.
class _GroupedNumberFormatter extends TextInputFormatter {
  static final _notDigit = RegExp(r'[^0-9]');

  /// Off for an FCFA price, which has no cents: a comma typed from habit
  /// ("350,000") is dropped and the box shows 350.000, the amount that will
  /// be saved, instead of keeping 350 behind a decimal comma.
  final bool decimal;

  _GroupedNumberFormatter({this.decimal = true});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only the cursor moved: leave it where the seller put it.
    if (newValue.text == oldValue.text) return newValue;
    var raw = newValue.text;
    var cursor = newValue.selection.end.clamp(0, raw.length);
    // Backspace on a dot would only have the dot put straight back; take the
    // digit before it, which is what the seller meant.
    final old = oldValue.text;
    if (cursor > 0 &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.end == cursor + 1 &&
        old.length == raw.length + 1 &&
        old[cursor] == '.' &&
        raw == old.substring(0, cursor) + old.substring(cursor + 1)) {
      raw = raw.substring(0, cursor - 1) + raw.substring(cursor);
      cursor -= 1;
    }

    final comma = decimal ? raw.indexOf(',') : -1;
    final whole = (comma == -1 ? raw : raw.substring(0, comma))
        .replaceAll(_notDigit, '');
    final fraction =
        comma == -1 ? null : raw.substring(comma + 1).replaceAll(_notDigit, '');
    final grouped = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) grouped.write('.');
      grouped.write(whole[i]);
    }
    final text = fraction == null ? '$grouped' : '$grouped,$fraction';

    // Put the cursor back after the same digits (and comma) it followed.
    final kept = raw
        .substring(0, cursor)
        .replaceAll(decimal ? RegExp(r'[^0-9,]') : _notDigit, '')
        .length;
    var offset = 0;
    for (var seen = 0; offset < text.length && seen < kept; offset++) {
      if (text[offset] != '.') seen++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// The dashed outline of an empty photo tile.
class _DashedRRectPainter extends CustomPainter {
  final Color color;

  const _DashedRRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.6),
        const Radius.circular(12),
      ));
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 5, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color;
}

/// A searchable list of one field's options, for singles too long for chips.
/// Pops the chosen value, '' when the current choice is tapped again (to
/// clear it), or null when dismissed.
class _OptionSheet extends StatefulWidget {
  final AttrField field;
  final Locale locale;
  final String? selected;

  const _OptionSheet({
    required this.field,
    required this.locale,
    this.selected,
  });

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final f = widget.field;
    final q = foldForSearch(_query.trim());
    // Accent-free, both ways: "tec" finds Tecno and "electrique" finds
    // "Électrique".
    final options = [
      for (final o in f.options)
        if (q.isEmpty || foldForSearch(o.label(widget.locale)).contains(q)) o,
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    f.label(widget.locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: MaterialLocalizations.of(context).searchFieldLabel,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: options.isEmpty
                ? ListView(
                    controller: scrollController,
                    children: [
                      const SizedBox(height: 48),
                      Center(child: Text(context.l10n.shipPickerNoMatch)),
                    ],
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final o = options[i];
                      final selected = o.value == widget.selected;
                      return ListTile(
                        title: Text(o.label(widget.locale)),
                        selected: selected,
                        trailing: selected ? const Icon(Icons.check) : null,
                        onTap: () =>
                            Navigator.pop(context, selected ? '' : o.value),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
