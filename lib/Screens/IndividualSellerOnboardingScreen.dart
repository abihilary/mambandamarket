import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../DashBoards/SellerDashboardScreen.dart';
import '../api/auth_service.dart';
import '../api/config.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

class IndividualSellerOnboardingScreen extends StatefulWidget {
  const IndividualSellerOnboardingScreen({super.key});

  @override
  State<IndividualSellerOnboardingScreen> createState() =>
      _IndividualSellerOnboardingScreenState();
}

class _IndividualSellerOnboardingScreenState
    extends State<IndividualSellerOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Editing Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // Image Picker instance
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Fully functional image picker modal
  Future<void> _pickProfileImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(context.l10n.onbIndChooseFromGallery),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(context.l10n.onbIndTakePhoto),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImage(ImageSource.camera);
                },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.danger),
                  title: Text(
                    context.l10n.onbIndRemovePhoto,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _profileImage = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to execute ImagePicker logic
  Future<void> _getImage(ImageSource source) async {
    final l10n = context.l10n;
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onbIndImagePickFailed(e.toString()))),
      );
    }
  }

  void _submitOnboarding() async {
    if (_formKey.currentState!.validate()) {
      final l10n = context.l10n;
      setState(() {
        _isSubmitting = true;
      });

      final String fullName = _nameController.text.trim();
      final String phoneNumber = _phoneController.text.trim();
      final String bio = _bioController.text.trim();
      final File? imageFile = _profileImage;

      try {
        // Promote the account to a seller, then save the profile fields.
        await AuthService.instance.syncProfile(
          displayName: fullName,
          role: 'individual_seller',
          phone: phoneNumber,
        );

        String? avatarUrl;
        if (imageFile != null) {
          // Direct-to-storage upload via a signed URL, same as listing images.
          final path = await ListingsRepository.instance.uploadImage(imageFile);
          avatarUrl = AppConfig.storagePublicUrl('listing-images', path);
        }

        await AuthService.instance.updateProfile({
          'display_name': fullName,
          if (phoneNumber.isNotEmpty) 'phone': phoneNumber,
          if (bio.isNotEmpty) 'bio': bio,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        });

        if (!mounted) return;

        setState(() {
          _isSubmitting = false;
        });

        // Navigate to Seller Dashboard on success
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SellerDashboardScreen(),
          ),
        );
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.onbIndSubmissionFailed(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.onbIndAppBarTitle),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER SECTION
                Text(
                  context.l10n.onbIndHeaderTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.onbIndHeaderSubtitle,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // PROFILE PHOTO PICKER WITH REAL-TIME PREVIEW
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: scheme.surfaceContainerHighest,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null
                            ? Icon(
                          Icons.person,
                          size: 52,
                          color: scheme.onSurfaceVariant,
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickProfileImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _profileImage == null
                                  ? Icons.camera_alt
                                  : Icons.edit,
                              color: scheme.onPrimary,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // FORM FIELDS
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n.onbIndNameLabel,
                    hintText: context.l10n.onbIndNameHint,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.onbIndNameRequired;
                    }
                    if (value.trim().length < 2) {
                      return context.l10n.onbIndNameTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n.onbIndPhoneLabel,
                    hintText: context.l10n.onbIndPhoneHint,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    helperText: context.l10n.onbIndPhoneHelper,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.onbIndPhoneRequired;
                    }
                    if (value.trim().length < 8) {
                      return context.l10n.onbIndPhoneInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 200,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: context.l10n.onbIndBioLabel,
                    hintText: context.l10n.onbIndBioHint,
                    alignLabelWithHint: true,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.info_outline),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // TERMS & INFO BANNER
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // Informational, not a money state — a neutral plate rather
                    // than a pastel blue that only exists in light mode.
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          color: scheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.onbIndInfoBanner,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitOnboarding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: scheme.onPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                        : Text(
                      context.l10n.onbIndSubmitButton,
                      style: const TextStyle(
                        fontSize: 16,
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
}