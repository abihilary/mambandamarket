import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  String _selectedCategory = 'Auto & Rad';
  String _selectedCondition = 'New';
  bool _hasGuarantee = false;

  final List<String> _categories = [
    'For You',
    'RealEstate',
    'Haus & Garten',
    'Auto & Rad',
    'Mode',
    'Elektronik',
    'Familie',
    'Sport',
  ];

  final ImagePicker _picker = ImagePicker();
  final List<String> _existingImages = []; // Stores existing network/file image URLs or paths
  final List<XFile> _newImageFiles = [];   // Stores newly picked images from camera/gallery

  @override
  void initState() {
    super.initState();
    if (widget.initialListing != null) {
      final listing = widget.initialListing!;
      _titleController.text = listing['title']?.toString() ?? '';
      _priceController.text = listing['price']?.toString() ?? '';
      _quantityController.text = (listing['quantity'] ?? 1).toString();
      _selectedCategory = _categories.contains(listing['category'])
          ? listing['category']
          : _categories.first;
      _selectedCondition = listing['condition'] ?? 'New';
      _hasGuarantee = listing['hasGuarantee'] ?? false;

      if (listing['images'] != null) {
        _existingImages.addAll(List<String>.from(listing['images']));
      }
    } else {
      _quantityController.text = '1';
    }
  }

  Future<void> _pickImageFromCamera() async {
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
      _showErrorSnackBar('Failed to capture photo: $e');
    }
  }

  Future<void> _pickImagesFromGallery() async {
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
      _showErrorSnackBar('Failed to pick images: $e');
    }
  }

  void _showImagePickerModal() {
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
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.indigo),
                title: const Text('Choose from Gallery'),
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

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final allImagePaths = [
        ..._existingImages,
        ..._newImageFiles.map((file) => file.path),
      ];

      if (allImagePaths.isEmpty) {
        _showErrorSnackBar('Please select at least one image.');
        return;
      }

      final parsedQuantity = int.tryParse(_quantityController.text) ?? 1;

      final updatedItem = {
        'id': widget.initialListing?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _titleController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'quantity': parsedQuantity,
        'category': _selectedCategory,
        'condition': _selectedCondition,
        'hasGuarantee': _hasGuarantee,
        'views': widget.initialListing?['views'] ?? 0,
        'inStock': parsedQuantity > 0,
        'images': allImagePaths,
      };

      Navigator.pop(context, updatedItem);
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialListing != null;
    final totalImagesCount = _existingImages.length + _newImageFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Item' : 'Add New Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Product Images',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: Colors.indigo),
                              SizedBox(height: 4),
                              Text('Add Media',
                                  style: TextStyle(fontSize: 12, color: Colors.indigo)),
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
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Select Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(value: category, child: Text(category));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),

              // TITLE FIELD
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Listing Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) =>
                val == null || val.isEmpty ? 'Please enter a title' : null,
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
                        labelText: 'Price (€)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter price';
                        if (double.tryParse(val) == null) return 'Invalid price';
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
                        labelText: 'Quantity',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter quantity';
                        final qty = int.tryParse(val);
                        if (qty == null || qty < 1) return 'Min 1';
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
                  labelText: 'Condition',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['New', 'Like New', 'Used', 'Refurbished'].map((cond) {
                  return DropdownMenuItem(value: cond, child: Text(cond));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCondition = val);
                },
              ),
              const SizedBox(height: 12),

              // GUARANTEE CHECKBOX
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Includes Guarantee / Warranty'),
                value: _hasGuarantee,
                onChanged: (val) => setState(() => _hasGuarantee = val ?? false),
              ),
              const SizedBox(height: 24),

              // SUBMIT BUTTON
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isEditing ? 'Save Changes' : 'Publish Item',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}