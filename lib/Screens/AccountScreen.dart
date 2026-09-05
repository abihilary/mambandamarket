
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/auth_service.dart';
import '../api/config.dart';
import '../api/models.dart';
import '../api/remote_config.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../Components/plan_card.dart';
import '../Components/menu_group.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'EditProfileScreen.dart';
import '../theme/app_tokens.dart';
import 'ResetPasswordScreen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    // Repair the profile if launch failed to load it. Without this, a single
    // failed refresh at startup hides every role-gated entry below — a verified
    // company would open this screen and find no Company dashboard at all.
    AuthService.instance.ensureMe();
  }

  /// True while a new picture is uploading, so the avatar can show progress
  /// instead of looking like the tap did nothing.
  bool _uploadingAvatar = false;

  /// Set the account picture.
  ///
  /// The file goes straight to Supabase Storage on a short-lived signed URL —
  /// it never streams through the API — and only the resulting public URL is
  /// saved on the profile. The bucket namespaces every path under the caller's
  /// user id, so one account can never overwrite another's picture.
  Future<void> _changeAvatar() async {
    if (_uploadingAvatar) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

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

    // Downscaled on the way out: an avatar is rendered at 34pt, and shipping a
    // 12MP original over a mobile connection to draw a thumbnail is a cost the
    // user pays for nothing.
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final path = await ListingsRepository.instance
          .uploadImage(picked, bucket: 'avatars');
      await AuthService.instance.updateProfile({
        'avatar_url': AppConfig.storagePublicUrl('avatars', path),
      });
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.avatarUploadFailed)));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  /// Whether to offer the business dashboard — the storefront: stock levels,
  /// orders, a shop page. It only means something to an account that has a
  /// store behind it, so plain buyers do not see it once sign-up has stopped
  /// asking what kind of account somebody wants.
  bool _showsBusinessDashboard(Profile? profile) {
    if (RemoteConfig.instance.roleSelectionEnabled) return true;
    return profile?.isSeller == true || profile?.isCompany == true;
  }

  /// The seller area is a different thing: it is where you look after what
  /// *you* posted — what is still live, what sold, what it earned. Every
  /// account can post now, so every account gets it. Letting somebody publish
  /// and then giving them nowhere to manage it afterwards is half a feature.
  bool _showsSellerDashboard(Profile? profile) => profile != null;

  /// Open the profile editor. `me` is reloaded by the save itself, so the
  /// header behind this redraws on return without anything else being asked.
  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  Future<void> _resendConfirmation(BuildContext context, String email) async {
    final l10n = context.l10n;
    try {
      await AuthService.instance.resendConfirmation(email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.confirmationEmailSent)),
      );
    } on AuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _logOut(BuildContext context) async {
    final l10n = context.l10n;
    // Was a single tap, at the bottom of a list of navigation rows, styled
    // like all of them. Easy to hit by accident, and there is no undo — the
    // session is gone and the password has to come back out.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logOutConfirmTitle),
        content: Text(l10n.logOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.logOutConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.logOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
  }

  String _themeLabel(BuildContext context, ThemeMode mode) {
    final l10n = context.l10n;
    return switch (mode) {
      ThemeMode.light => l10n.appearanceLight,
      ThemeMode.dark => l10n.appearanceDark,
      ThemeMode.system => l10n.appearanceSystem,
    };
  }

  /// Bottom sheet to pick light / dark / follow-the-device.
  void _pickTheme(BuildContext context) {
    final l10n = context.l10n;
    final controller = ThemeController.instance;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in <(ThemeMode, String, IconData)>[
              (ThemeMode.system, l10n.appearanceSystem, Icons.brightness_auto_outlined),
              (ThemeMode.light, l10n.appearanceLight, Icons.light_mode_outlined),
              (ThemeMode.dark, l10n.appearanceDark, Icons.dark_mode_outlined),
            ])
              ListTile(
                leading: Icon(entry.$3),
                title: Text(entry.$2),
                trailing: controller.mode.value == entry.$1
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  controller.setMode(entry.$1);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet to pick the app language. "System default" clears the
  /// override so the app follows the device again.
  void _pickLanguage(BuildContext context) {
    final l10n = context.l10n;
    final controller = LocaleController.instance;
    final current = controller.locale.value?.languageCode;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        Widget option(String label, String? subtitle, String? code) {
          final selected = current == code;
          return ListTile(
            title: Text(label),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: selected
                ? Icon(Icons.check,
                    color: Theme.of(sheetContext).colorScheme.primary)
                : null,
            onTap: () {
              controller.setLocale(code == null ? null : Locale(code));
              Navigator.pop(sheetContext);
            },
          );
        }

        return SafeArea(
          // See HomeScreen: the list runs under the glass bar and its own
          // bottom padding is the clearance.
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.language,
                        color: Theme.of(sheetContext).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(l10n.chooseLanguage,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              option(l10n.languageEnglish, null, 'en'),
              option(l10n.languageFrench, null, 'fr'),
              const Divider(height: 1),
              option(l10n.languageSystem, l10n.languageSystemSubtitle, null),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Human-readable label for the currently active language choice.
  String _currentLanguageLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (LocaleController.instance.locale.value?.languageCode) {
      case 'en':
        return l10n.languageEnglish;
      case 'fr':
        return l10n.languageFrench;
      default:
        return l10n.languageSystem;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ValueListenableBuilder<Me?>(
        valueListenable: auth.me,
        builder: (context, me, _) {
          final profile = me?.profile;
          final name = profile?.displayName?.isNotEmpty == true
              ? profile!.displayName!
              : (auth.user?.email?.split('@').first ?? l10n.accountTitle);
          final email = auth.user?.email ?? '';
          final avatar = profile?.avatarUrl;

          return RefreshIndicator(
            onRefresh: () async => auth.refreshMe(),
            child: ListView(
              // Bottom room for the docked FAB, which overhangs the bar
              // and would otherwise sit on top of the last row.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                // The person, on the page itself — no card behind them.
                //
                // A card here boxed the one thing the screen is about and made
                // it look like just another row. Sitting on the ground, with a
                // larger portrait and a heavier name, it reads as the header it
                // is; the groups below carry the cards.
                InkWell(
                  onTap: _openEditProfile,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _changeAvatar,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor:
                                        scheme.primary.withValues(alpha: 0.12),
                                    backgroundImage:
                                        (avatar != null && avatar.isNotEmpty)
                                            ? NetworkImage(avatar)
                                            : null,
                                    child: _uploadingAvatar
                                        ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: scheme.primary),
                                          )
                                        : (avatar == null || avatar.isEmpty)
                                            ? Text(
                                                name.characters.first
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.bold,
                                                    color: scheme.primary),
                                              )
                                            : null,
                                  ),
                                  // Without this the picture looks like
                                  // decoration; the camera dot is the only
                                  // thing that says it is a button.
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: scheme.surface, width: 2),
                                      ),
                                      child: Icon(Icons.photo_camera,
                                          size: 12, color: scheme.onPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        height: 1.15,
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                size: 24, color: context.tokens.accentInk),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 20),

                // Unconfirmed accounts can hold a session, so surface it here —
                // otherwise the user never learns why some things fail.
                if (!auth.isEmailConfirmed && email.isNotEmpty)
                  Card(
                    elevation: 0,
                    color: AppColors.warning.withValues(alpha: 0.12),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning),
                      title: Text(l10n.emailNotConfirmed,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(l10n.emailNotConfirmedBody),
                      trailing: TextButton(
                        onPressed: () => _resendConfirmation(context, email),
                        child: Text(l10n.resend),
                      ),
                    ),
                  ),

                // Plan + remaining quota, straight from /me entitlements.
                if (me != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: PlanCard(
                      title: l10n.sellerProgress,
                      planLabel: me.subscription?['plan'] != null
                          ? l10n.planLabel(me.subscription!['plan'].toString())
                          : l10n.freePlan,
                      publishedLabel: l10n.listingsPublished,
                      activeListings: me.activeListings,
                      listingLimit: me.listingLimit,
                      actionLabel: l10n.changePlan,
                      onAction: () =>
                          Navigator.pushNamed(context, '/subscription'),
                    ),
                  ),

                const SizedBox(height: 20),

                // Grouped, as the deck arranges them. Previously these were
                // bare ListTiles at the top level of the ListView: nothing
                // said which rows belonged together, the trailing glyph
                // alternated between two different chevrons, and Log out
                // looked exactly like one more place to navigate to.
                MenuGroup(children: [
                  MenuRow(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.myOrders,
                    subtitle: l10n.myOrdersSubtitle,
                    onTap: () => Navigator.pushNamed(context, '/my-orders'),
                  ),
                  MenuRow(
                    icon: Icons.card_giftcard_outlined,
                    title: l10n.inviteFriends,
                    subtitle: l10n.inviteFriendsSubtitle,
                    onTap: () => Navigator.pushNamed(context, '/invite'),
                  ),
                  // Verified merchants only — companies are provisioned by an
                  // admin, so there is nothing to show anyone else.
                  if (profile?.isCompany == true)
                    MenuRow(
                      icon: Icons.verified_outlined,
                      title: l10n.companyDashboard,
                      onTap: () =>
                          Navigator.pushNamed(context, '/company-dashboard'),
                    ),
                  // The storefront belongs to accounts that have a store; the
                  // seller area belongs to anybody who can publish, which is
                  // everybody. Two different promises, gated separately.
                  if (_showsBusinessDashboard(profile))
                    MenuRow(
                      icon: Icons.storefront_outlined,
                      title: l10n.businessDashboard,
                      onTap: () =>
                          Navigator.pushNamed(context, '/business-dashboard'),
                    ),
                  if (_showsSellerDashboard(profile))
                    MenuRow(
                      icon: Icons.sell_outlined,
                      title: l10n.sellerSpace,
                      subtitle: l10n.sellerSpaceSubtitle,
                      onTap: () =>
                          Navigator.pushNamed(context, '/seller-dashboard'),
                    ),
                ]),

                MenuGroup(children: [
                  MenuRow(
                    icon: Icons.language,
                    title: l10n.language,
                    subtitle: _currentLanguageLabel(context),
                    onTap: () => _pickLanguage(context),
                  ),
                  // Appearance sits beside language: both are "how the app
                  // looks to me", and both persist across launches.
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.instance.mode,
                    builder: (context, mode, _) => MenuRow(
                      icon: switch (mode) {
                        ThemeMode.dark => Icons.dark_mode_outlined,
                        ThemeMode.light => Icons.light_mode_outlined,
                        ThemeMode.system => Icons.brightness_auto_outlined,
                      },
                      title: l10n.appearance,
                      subtitle: _themeLabel(context, mode),
                      onTap: () => _pickTheme(context),
                    ),
                  ),
                  MenuRow(
                    icon: Icons.lock_outline,
                    title: l10n.changePassword,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ResetPasswordScreen()),
                    ),
                  ),
                ]),

                // "Settings & privacy" used to sit here with `onTap: () {}`.
                // It went nowhere, so it is gone rather than left as a row
                // that does nothing when pressed.
                MenuGroup(children: [
                  MenuRow(
                    icon: Icons.logout,
                    title: l10n.logOut,
                    danger: true,
                    onTap: () => _logOut(context),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
