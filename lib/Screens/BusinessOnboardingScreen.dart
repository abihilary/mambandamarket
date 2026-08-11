
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/config.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../Components/local_image.dart';

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
    final l10n = context.l10n;
    return await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final accent = Theme.of(ctx).colorScheme.primary;
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
                leading: Icon(Icons.camera_alt, color: accent),
                title: Text(l10n.onbBizTakePhoto),
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
                leading: Icon(Icons.photo_library, color: accent),
                title: Text(l10n.onbBizChooseFromGallery),
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
    final l10n = context.l10n;
    try {
      final image = await _showImageSourceSheet(context, l10n.onbBizSelectBanner);
      if (image != null) {
        setState(() {
          _bannerImage = image;
        });
      }
    } catch (e) {
      _showErrorSnackBar(l10n.onbBizBannerPickFailed(e.toString()));
    }
  }

  // Pick Avatar / Logo Image
  Future<void> _pickAvatarImage() async {
    final l10n = context.l10n;
    try {
      final image = await _showImageSourceSheet(context, l10n.onbBizSelectLogo);
      if (image != null) {
        setState(() {
          _avatarImage = image;
        });
      }
    } catch (e) {
      _showErrorSnackBar(l10n.onbBizAvatarPickFailed(e.toString()));
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  bool _isSaving = false;

  /// Uploads a picked image and returns its public URL, or null if there was
  /// nothing to upload. Banner and logo live in the store-assets bucket.
  Future<String?> _uploadAsset(XFile? file) async {
    if (file == null) return null;
    final path = await ListingsRepository.instance
        .uploadImage(file, bucket: 'store-assets');
    return AppConfig.storagePublicUrl('store-assets', path);
  }

  Future<void> _saveStoreProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    final l10n = context.l10n;
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
        SnackBar(
            content: Text(l10n.onbBizSaved),
            backgroundColor: AppColors.success),
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
      _showErrorSnackBar(l10n.onbBizSaveFailed);
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
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onbBizTitle),
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
                      // A brand-tinted upload plate rather than a fixed pastel,
                      // so it reads as "empty" on either ground.
                      color: scheme.primary.withValues(alpha: 0.08),
                      image: _bannerImage != null
                          ? DecorationImage(
                        image: localImageProvider(_bannerImage!.path),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: _bannerImage == null
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: scheme.primary, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            l10n.onbBizUploadBanner,
                            style: TextStyle(
                              color: scheme.primary,
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
                              // Scrim over the user's own photo — stays a dark
                              // plate with white text in either theme.
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.edit, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.onbBizChangeBanner,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
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
                          backgroundColor: scheme.surface,
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor:
                                scheme.primary.withValues(alpha: 0.08),
                            backgroundImage: _avatarImage != null
                                ? localImageProvider(_avatarImage!.path)
                                : null,
                            child: _avatarImage == null
                                ? Icon(Icons.storefront,
                                    size: 36, color: scheme.primary)
                                : null,
                          ),
                        ),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: scheme.primary,
                          child: Icon(Icons.camera_alt,
                              size: 14, color: scheme.onPrimary),
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
                      decoration: InputDecoration(
                        labelText: l10n.onbBizShopNameLabel,
                        prefixIcon: const Icon(Icons.storefront),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? l10n.onbBizShopNameRequired : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _shopLocationController,
                      decoration: InputDecoration(
                        labelText: l10n.onbBizShopLocationLabel,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? l10n.onbBizShopLocationRequired : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _shopDescriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.onbBizShopDescriptionLabel,
                        hintText: l10n.onbBizShopDescriptionHint,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? l10n.onbBizDescriptionRequired : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: l10n.onbBizSupportPhoneLabel,
                        prefixIcon: const Icon(Icons.phone),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? l10n.onbBizPhoneRequired : null,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveStoreProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          l10n.onbBizSaveContinue,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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