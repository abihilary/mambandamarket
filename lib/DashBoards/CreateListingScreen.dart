import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/models.dart' as api;
import '../api/location_service.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../Components/category_icons.dart';
import '../Components/category_picker.dart';
import '../Components/local_image.dart';

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
  String _selectedCondition = 'New';
  bool _hasGuarantee = false;
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
      _hasGuarantee = listing['hasGuarantee'] ?? false;
      // Both spellings, for the same reason the category reads two keys: the
      // seller hub and the store dashboard build this map differently.
      _locationController.text =
          (listing['city'] ?? listing['location'] ?? '').toString();

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
          _selectedCategory = cats.isNotEmpty ? cats.first.slug : null;
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
    if (_existingImages.isEmpty && _newImageFiles.isEmpty) {
      _showErrorSnackBar(l10n.createSelectAtLeastOneImage);
      return;
    }

    setState(() => _isSubmitting = true);
    final editingId = _editingId;
    try {
      // Money is sent as integer minor units; never as a float. FCFA has no
      // minor unit, so the conversion is currency-aware — scaling by 100 here
      // published every listing at 100x its price.
      final priceCents = api.toMinorUnits(
        double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0,
      );
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final description = _descriptionController.text.trim();

      if (editingId != null) {
        // Editing said "Edit Item" and "Save Changes" at the top and bottom of
        // the screen, and then posted a second listing. The screen has always
        // known which one it was; only this call did not.
        await ListingsRepository.instance.update(editingId, {
          'title': _titleController.text.trim(),
          'description': description,
          'price_cents': priceCents,
          'quantity': quantity,
          'category_slug': _selectedCategory!,
          'condition': _selectedCondition,
          'has_guarantee': _hasGuarantee,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.createListingUpdated),
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
        condition: _selectedCondition,
        hasGuarantee: _hasGuarantee,
        city: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        lat: _capturedPoint?.lat,
        lng: _capturedPoint?.lng,
        imagePaths: uploaded,
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
    setState(() => _selectedCategory = picked);
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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.createProductImages,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

              // CATEGORY SELECTOR
              //
              // A sheet rather than a dropdown. The category list is a
              // two-level tree of roughly ninety entries now; a dropdown is a
              // single unsearchable column, so finding "Groceries" meant
              // scrolling past everything the marketplace sells.
              FormField<String>(
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

              // PRICE & QUANTITY ROW
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.createPriceLabel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return l10n.createEnterPrice;
                        if (double.tryParse(val) == null) return l10n.createInvalidPrice;
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.createQuantity,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return l10n.createEnterQuantity;
                        final qty = int.tryParse(val);
                        if (qty == null || qty < 1) return l10n.createMinQuantity;
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // CONDITION SELECTOR
              DropdownButtonFormField<String>(
                value: _selectedCondition,
                decoration: InputDecoration(
                  labelText: l10n.createCondition,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _conditions.map((cond) {
                  return DropdownMenuItem(value: cond, child: Text(_conditionLabel(cond)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCondition = val);
                },
              ),
              const SizedBox(height: 16),

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
                      helperText: l10n.createListingLocationHelp,
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

              // GUARANTEE CHECKBOX
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.createIncludesGuarantee),
                value: _hasGuarantee,
                onChanged: (val) => setState(() => _hasGuarantee = val ?? false),
              ),
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