import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
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
    final l10n = context.l10n;
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
    } catch (_) {
      if (mounted) _showErrorSnackBar(l10n.createCouldNotLoadCategories);
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
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
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: l10n.createSelectCategory,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: _categories.isEmpty ? l10n.createLoading : null,
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(
                          value: c.slug,
                          // displayLabel, not label: browse has always used the
                          // translated name, so listing something was the one
                          // place a seller met the raw German seed data.
                          child: Text(c.displayLabel(Localizations.localeOf(context))),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
                validator: (val) =>
                    val == null ? l10n.createPleaseChooseCategory : null,
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
              const SizedBox(height: 12),

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