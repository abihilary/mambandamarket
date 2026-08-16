import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../Components/local_image.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/config.dart';
import '../api/models.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';

/// Edit your own profile: picture, name, phone, city, bio.
///
/// These were only ever settable while becoming a seller. A buyer — and any
/// seller who had already been through onboarding — had no way to correct their
/// own name or number anywhere in the app, which is why "updating my profile"
/// appeared to do nothing: there was nothing to update it with.
///
/// Saving goes through AuthService.updateProfile, which PATCHes /me and then
/// reloads it, so every screen watching `me` (the account header, the drawer
/// name, the avatar) redraws as soon as this returns.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _bio = TextEditingController();

  /// Chosen but not yet uploaded. The upload happens on save, not on pick, so
  /// backing out of this screen cannot leave an orphaned file in storage.
  XFile? _pickedImage;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = AuthService.instance.me.value?.profile;
    _name.text = p?.displayName ?? '';
    _phone.text = p?.phone ?? '';
    _city.text = p?.city ?? '';
    _bio.text = p?.bio ?? '';
    // The profile may not have loaded yet; top it up and fill the form when it
    // arrives, so the fields are never blank for someone who does have details.
    AuthService.instance.ensureMe().then((_) {
      if (!mounted) return;
      final loaded = AuthService.instance.me.value?.profile;
      if (loaded == null) return;
      setState(() {
        if (_name.text.isEmpty) _name.text = loaded.displayName ?? '';
        if (_phone.text.isEmpty) _phone.text = loaded.phone ?? '';
        if (_city.text.isEmpty) _city.text = loaded.city ?? '';
        if (_bio.text.isEmpty) _bio.text = loaded.bio ?? '';
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.avatarFromGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.avatarFromCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.avatarCancel),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 512, maxHeight: 512);
    if (picked == null || !mounted) return;
    setState(() => _pickedImage = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    try {
      // Upload first: if the picture fails there is no point writing the rest,
      // and this way the profile never points at a file that did not arrive.
      String? avatarUrl;
      if (_pickedImage != null) {
        final path = await ListingsRepository.instance
            .uploadImage(_pickedImage!, bucket: 'avatars');
        avatarUrl = AppConfig.storagePublicUrl('avatars', path);
      }

      // Blank means "clear it", so empty strings are sent rather than skipped —
      // otherwise a field could be filled in but never emptied again.
      await AuthService.instance.updateProfile({
        'display_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'bio': _bio.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      });

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.editProfileSaved)));
      navigator.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.editProfileFailed),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfileTitle)),
      body: SafeArea(
        child: AbsorbPointer(
          // Nothing is editable mid-save: a second tap on Save, or a change to a
          // field whose old value is already in flight, produces a profile that
          // does not match what is on screen.
          absorbing: _saving,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ValueListenableBuilder<Me?>(
                          valueListenable: AuthService.instance.me,
                          builder: (context, me, _) {
                            final existing = me?.profile?.avatarUrl;
                            final image = _pickedImage != null
                                ? localImageProvider(_pickedImage!.path)
                                : (existing != null && existing.isNotEmpty
                                    ? NetworkImage(existing)
                                    : null) as ImageProvider?;
                            final initial = (_name.text.trim().isNotEmpty
                                    ? _name.text.trim()
                                    : l10n.profileFallbackName)
                                .characters
                                .first
                                .toUpperCase();
                            return CircleAvatar(
                              radius: 48,
                              backgroundColor: scheme.primary.withValues(alpha: 0.12),
                              backgroundImage: image,
                              child: image != null
                                  ? null
                                  : Text(initial,
                                      style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.primary)),
                            );
                          },
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: scheme.surface, width: 2),
                            ),
                            child: Icon(Icons.photo_camera,
                                size: 15, color: scheme.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.fullName,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? l10n.onbIndNameTooShort
                      : null,
                  onChanged: (_) => setState(() {}), // keep the initial in sync
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.editProfilePhone,
                    helperText: l10n.editProfilePhoneHelper,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.editProfileCity,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bio,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: l10n.editProfileBio,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      // A save uploads a picture and then writes the profile, so
                      // it is long enough that a button which merely goes flat
                      // reads as a tap that missed.
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.onPrimary),
                        )
                      : Text(l10n.editProfileSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
