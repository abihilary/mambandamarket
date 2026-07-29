import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/config.dart';
import '../api/repositories.dart';

class BusinessOnboardingScreen extends StatefulWidget {
  const BusinessOnboardingScreen({super.key});

  @override
  State<BusinessOnboardingScreen> createState() => _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState extends State<BusinessOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _shopLocationController = TextEditingController();
  final _shopDescriptionController = TextEditingController();
  final _phoneController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  // Local state for picked images
  XFile? _bannerImage;
  XFile? _avatarImage;

  // Helper method to present source picker modal (Camera or Gallery)
  Future<XFile?> _showImageSourceSheet(BuildContext context, String title) async {
    return await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.indigo),
                title: const Text('Take Photo with Camera'),
                onTap: () async {
                  final image = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                    maxWidth: 1200,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.indigo),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  final image = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                    maxWidth: 1200,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, image);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Pick Banner Image
  Future<void> _pickBannerImage() async {
    try {
      final image = await _showImageSourceSheet(context, 'Select Store Banner');
      if (image != null) {
        setState(() {
          _bannerImage = image;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to select banner image: $e');
    }
  }

  // Pick Avatar / Logo Image
  Future<void> _pickAvatarImage() async {
    try {
      final image = await _showImageSourceSheet(context, 'Select Store Logo');
      if (image != null) {
        setState(() {
          _avatarImage = image;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to select avatar image: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _isSaving = false;

  /// Uploads a picked image and returns its public URL, or null if there was
  /// nothing to upload. Banner and logo live in the store-assets bucket.
  Future<String?> _uploadAsset(XFile? file) async {
    if (file == null) return null;
    final path = await ListingsRepository.instance
        .uploadImage(File(file.path), bucket: 'store-assets');
    return AppConfig.storagePublicUrl('store-assets', path);
  }

  Future<void> _saveStoreProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final repo = StoresRepository.instance;
      // Creating twice would 409, so update when a storefront already exists.
      final existing = await repo.mine();

      final bannerUrl = await _uploadAsset(_bannerImage);
      final logoUrl = await _uploadAsset(_avatarImage);

      if (existing == null) {
        await repo.create(
          shopName: _shopNameController.text.trim(),
          description: _shopDescriptionController.text.trim(),
          supportPhone: _phoneController.text.trim(),
          bannerUrl: bannerUrl,
          logoUrl: logoUrl,
        );
      } else {
        await repo.update(existing.id, {
          'shop_name': _shopNameController.text.trim(),
          'description': _shopDescriptionController.text.trim(),
          'support_phone': _phoneController.text.trim(),
          if (bannerUrl != null) 'banner_url': bannerUrl,
          if (logoUrl != null) 'logo_url': logoUrl,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Storefront saved.'), backgroundColor: Colors.green),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushNamedAndRemoveUntil(
            context, '/business-dashboard', (route) => false);
      }
    } on ApiException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (_) {
      _showErrorSnackBar('Could not save your storefront. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopLocationController.dispose();
    _shopDescriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Profile Setup'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- BANNER & AVATAR PICKER HEADER ---
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Store Banner Container
                GestureDetector(
                  onTap: _pickBannerImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      image: _bannerImage != null
                          ? DecorationImage(
                        image: FileImage(File(_bannerImage!.path)),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: _bannerImage == null
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo, color: Colors.indigo, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            'Upload Store Banner',
                            style: TextStyle(
                              color: Colors.indigo.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                        : Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Change Banner',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Store Avatar / Logo Picker
                Positioned(
                  bottom: -35,
                  child: GestureDetector(
                    onTap: _pickAvatarImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: Colors.indigo.shade50,
                            backgroundImage: _avatarImage != null
                                ? FileImage(File(_avatarImage!.path))
                                : null,
                            child: _avatarImage == null
                                ? const Icon(Icons.storefront, size: 36, color: Colors.indigo)
                                : null,
                          ),
                        ),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.primaryColor,
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),

            // --- STORE DETAILS FORM ---
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(
                        labelText: 'Shop Name*',
                        prefixIcon: Icon(Icons.storefront),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Shop name required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _shopLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Shop Location*',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Shop location required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _shopDescriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Shop Description*',
                        hintText: 'Tell customers about your products and services...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Description required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Business Support Phone*',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Phone required' : null,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveStoreProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Save & Continue to Dashboard',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}