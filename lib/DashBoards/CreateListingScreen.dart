import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';

class CreateListingScreen extends StatefulWidget {
  final Map<String, dynamic>? initialListing;

  const CreateListingScreen({super.key, this.initialListing});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  /// Category **slug** (the API's identifier), not the display label.
  String? _selectedCategory;
  String _selectedCondition = 'New';
  bool _hasGuarantee = false;
  bool _isSubmitting = false;

  /// Loaded from the database so the picker always matches the server.
  List<api.Category> _categories = [];

  final ImagePicker _picker = ImagePicker();
  final List<String> _existingImages = []; // Stores existing network/file image URLs or paths
  final List<XFile> _newImageFiles = [];   // Stores newly picked images from camera/gallery

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.initialListing != null) {
      final listing = widget.initialListing!;
      _titleController.text = listing['title']?.toString() ?? '';
      _priceController.text = listing['price']?.toString() ?? '';
      _quantityController.text = (listing['quantity'] ?? 1).toString();
      _selectedCategory = listing['category_slug']?.toString();
      _selectedCondition = listing['condition'] ?? 'New';
      _hasGuarantee = listing['hasGuarantee'] ?? false;

      if (listing['images'] != null) {
        _existingImages.addAll(List<String>.from(listing['images']));
      }
    } else {
      _quantityController.text = '1';
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
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.indigo),
                title: Text(l10n.createTakePhotoWithCamera),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.indigo),
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
    setState(() {
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
    try {
      // Images go straight to Supabase Storage via short-lived signed URLs —
      // they never stream through the API.
      final uploaded = <String>[..._existingImages];
      for (final file in _newImageFiles) {
        uploaded.add(
          await ListingsRepository.instance.uploadImage(File(file.path)),
        );
      }

      // Money is sent as integer minor units; never as a float. FCFA has no
      // minor unit, so the conversion is currency-aware — scaling by 100 here
      // published every listing at 100x its price.
      final priceCents = api.toMinorUnits(
        double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0,
      );
      final quantity = int.tryParse(_quantityController.text) ?? 1;

      final listing = await ListingsRepository.instance.create(
        title: _titleController.text.trim(),
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
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, listing);
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
      if (mounted) _showErrorSnackBar(l10n.createCouldNotPublish);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildImagePreview(String path, VoidCallback onRemove) {
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
                  : FileImage(File(path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 16,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
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
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_outlined, color: Colors.indigo),
                              const SizedBox(height: 4),
                              Text(l10n.createAddMedia,
                                  style: const TextStyle(fontSize: 12, color: Colors.indigo)),
                            ],
                          ),
                        ),
                      );
                    }

                    final itemIndex = index - 1;
                    if (itemIndex < _existingImages.length) {
                      return _buildImagePreview(
                        _existingImages[itemIndex],
                            () => _removeExistingImage(itemIndex),
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
                          child: Text(c.label),
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
                items: ['New', 'Like New', 'Used', 'Refurbished'].map((cond) {
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
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
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