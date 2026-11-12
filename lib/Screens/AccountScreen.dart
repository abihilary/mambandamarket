import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_client.dart';
import '../api/auth_errors.dart';
import '../api/auth_service.dart';
import '../api/config.dart';
import '../api/models.dart';
import '../api/remote_config.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../l10n/locale_controller.dart';
import '../Components/plan_card.dart';
import '../Components/menu_group.dart';
import '../Components/support_sheet.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'EditProfileScreen.dart';
import '../theme/app_tokens.dart';
import 'ResetPasswordScreen.dart';
import '../Components/safe_bottom.dart';
import '../theme/breakpoints.dart';

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
    // The totals this device saved last time paint at once; the read below
    // revalidates them.
    final uid = AuthService.instance.userId;
    if (uid != null) {
      final saved = ListingsRepository.instance.savedDashboard(uid);
      _dashboard = saved?.value;
      _dashboardStamp = saved?.stamp;
    }
    // Publishing, editing or selling changes the totals; the tabs live in an
    // IndexedStack, so this screen is not rebuilt on its own.
    ListingsRepository.instance.revision.addListener(_onCatalogueChanged);
    _loadDashboard();
  }

  @override
  void dispose() {
    ListingsRepository.instance.revision.removeListener(_onCatalogueChanged);
    super.dispose();
  }

  void _onCatalogueChanged() {
    if (mounted) _loadDashboard();
  }

  /// Totals for the stat strip: earnings and active listings from the seller
  /// dashboard, the message count from the chat repository. Never throws — the
  /// strip simply stays hidden until the numbers arrive, so a failed or slow
  /// call costs a card, not the screen.
  SellerDashboard? _dashboard;

  /// What the strip shows (null: nothing yet), and which load may land: only
  /// the latest, and only when its answer differs.
  String? _dashboardStamp;
  int _dashboardSeq = 0;

  Future<void> _loadDashboard() async {
    final uid = AuthService.instance.userId;
    if (uid == null) return;
    final seq = ++_dashboardSeq;
    try {
      final r = await ListingsRepository.instance.fetchDashboard(uid);
      if (!mounted || seq != _dashboardSeq || !r.isCurrent) return;
      if (_dashboard == null || r.stamp != _dashboardStamp) {
        setState(() {
          _dashboard = r.value;
          _dashboardStamp = r.stamp;
        });
      }
    } catch (_) {
      // Leave the strip as it is (hidden, or the saved totals) rather than
      // showing zeros that look like fact.
    }
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
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final path = await ListingsRepository.instance.uploadImage(
        picked,
        bucket: 'avatars',
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.confirmationEmailSent)));
    } on AuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(e, l10n))));
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

  /// Ask to delete this account, from inside the app.
  ///
  /// The address is not a field. The caller is signed in, so the server takes
  /// it from the verified token — typing it again is a step that only exists
  /// on the public web form, which has no session to read it from, and an
  /// opportunity to mistype it into silence (that endpoint answers the same
  /// way whether or not an address has an account).
  ///
  /// The confirmation email stays. A session proves who is asking, but an
  /// unlocked phone is also a session, and this cannot be undone.
  Future<void> _deleteAccount() async {
    final l10n = context.l10n;
    final email = AuthService.instance.user?.email ?? '';

    // The sheet owns its own text controller, which is why it is a widget and
    // not a closure here. A controller created in this method and disposed as
    // soon as `showModalBottomSheet` returns is disposed too early: the sheet
    // is still mounted through its exit animation, and the TextField reaches
    // for it one more frame later. Returning the reason as the pop value
    // means nothing outside the sheet has to touch the controller at all.
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _DeleteAccountSheet(
        email: email,
        sendsToLine: _sendsToLine,
      ),
    );

    if (reason == null || !mounted) return;

    final text = reason.trim();

    try {
      await ApiClient.instance.post('/account/request-deletion', {
        if (text.isNotEmpty) 'reason': text,
        'locale': LocaleController.instance.locale.value?.languageCode ?? 'en',
      });
      if (!mounted) return;

      // A dialog, not a snackbar: the sign-out below tears this screen down,
      // and a snackbar would go with it before it could be read. The only
      // button is the sign-out, so the message cannot be skipped past.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deleteAccount),
          content: Text(l10n.deleteAccountSent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.logOut),
            ),
          ],
        ),
      );

      // Signed out on purpose. The account still exists until the link in the
      // email is opened, but leaving the session live invites the owner to
      // carry on using an account they have just asked to destroy — and the
      // link has to be opened from the mailbox either way, so there is
      // nothing left to do in here.
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteAccountFailed),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// "We will email a confirmation link to <address>." with the address picked
  /// out, in whatever language the sentence is written.
  ///
  /// Split on the address itself rather than on wording: it is the one token
  /// guaranteed to be in the string and in the same form in every locale, so
  /// this needs no per-language cases. A locale that somehow lost the
  /// placeholder falls back to plain text instead of dropping the line.
  ///
  /// `accentInk` is the colour, not `primary`: it is the one token defined to
  /// stay readable as *text* on both grounds — lime in the dark, a deepened
  /// lime in the light, where the bright one cannot be read.
  Widget _sendsToLine(BuildContext context, String sentence, String email) {
    final scheme = Theme.of(context).colorScheme;
    final base = TextStyle(color: scheme.onSurfaceVariant);
    final at = sentence.indexOf(email);
    if (at < 0) return Text(sentence, style: base);

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: sentence.substring(0, at)),
          TextSpan(
            text: email,
            style: TextStyle(
              color: context.tokens.accentInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: sentence.substring(at + email.length)),
        ],
      ),
    );
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
              (
                ThemeMode.system,
                l10n.appearanceSystem,
                Icons.brightness_auto_outlined,
              ),
              (
                ThemeMode.light,
                l10n.appearanceLight,
                Icons.light_mode_outlined,
              ),
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
  Future<void> _setMarketing(BuildContext context, bool value) async {
    try {
      await ApiClient.instance.patch('/me', {'notify_marketing': value});
      await AuthService.instance.refreshMe();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

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
                ? Icon(
                    Icons.check,
                    color: Theme.of(sheetContext).colorScheme.primary,
                  )
                : null,
            onTap: () {
              controller.setLocale(code == null ? null : Locale(code));
              Navigator.pop(sheetContext);
            },
          );
        }

        // A modal sheet sits above the shell's bar, not under it, so it needs
        // its own clearance from the system navigation bar.
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.language,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.chooseLanguage,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.accountTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
            onRefresh: () async =>
                Future.wait([auth.refreshMe(), _loadDashboard()]),
            child: ListView(
              // Bottom room for the docked FAB, which overhangs the bar
              // and would otherwise sit on top of the last row.
              // Plus the system bar: the app draws edge-to-edge.
              // Centred at form width on a desktop: settings rows 1400px
              // long put the label and its chevron a screen apart.
              padding: frameInsets(
                context,
                maxWidth: Breakpoints.form,
                min: 16,
              ).copyWith(top: 16, bottom: shellBottomClearance(context)),
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
                        Tappable(
                          onTap: _changeAvatar,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: scheme.primary.withValues(
                                  alpha: 0.12,
                                ),
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
                                          color: scheme.primary,
                                        ),
                                      )
                                    : (avatar == null || avatar.isEmpty)
                                    ? Text(
                                        name.characters.first.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.primary,
                                        ),
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
                                      color: scheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.photo_camera,
                                    size: 12,
                                    color: scheme.onPrimary,
                                  ),
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
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 24,
                          color: context.tokens.accentInk,
                        ),
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
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                      title: Text(
                        l10n.emailNotConfirmed,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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

                // Earnings, active listings, messages — the three numbers the
                // deck puts under the progress card. Real: the first two come
                // from the seller dashboard, the third from the chat inbox.
                // Hidden until the dashboard resolves, so nothing shows a
                // fabricated zero.
                if (_dashboard != null) ...[
                  const SizedBox(height: 4),
                  // The inbox revalidates on its own; the count follows it.
                  ValueListenableBuilder<List<Conversation>>(
                    valueListenable: ChatRepository.instance.threads,
                    builder: (context, threads, _) => _StatStrip(
                      earnings: _dashboard!.displayEarnings,
                      activeListings: _dashboard!.activeListings,
                      messages: threads.length,
                      earningsLabel: l10n.statTotalEarnings,
                      activeLabel: l10n.statActiveListings,
                      messagesLabel: l10n.statMessages,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Grouped, as the deck arranges them. Previously these were
                // bare ListTiles at the top level of the ListView: nothing
                // said which rows belonged together, the trailing glyph
                // alternated between two different chevrons, and Log out
                // looked exactly like one more place to navigate to.
                MenuGroup(
                  children: [
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
                    MenuRow(
                      icon: Icons.account_balance_wallet_outlined,
                      title: l10n.walletTitle,
                      subtitle: l10n.walletMenuSubtitle,
                      onTap: () => Navigator.pushNamed(context, '/wallet'),
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
                  ],
                ),

                MenuGroup(
                  children: [
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
                    // Offers and news. The switch the campaigns honour;
                    // delivery and order updates ignore it, and the subtitle
                    // says so.
                    MenuRow(
                      icon: Icons.notifications_outlined,
                      title: l10n.notificationsPrefTitle,
                      subtitle: l10n.notificationsPrefSub,
                      // Explicit colours: the platform defaults paint thumb and
                      // track the same lime in dark mode and the same ink in
                      // light, and a switch you cannot read is not a switch.
                      trailing: Switch(
                        value: profile?.notifyMarketing ?? true,
                        onChanged: (v) => _setMarketing(context, v),
                        activeTrackColor: tokens.accentFill,
                        activeThumbColor: tokens.onAccentFill,
                        inactiveTrackColor: scheme.surfaceContainerHighest,
                        inactiveThumbColor: scheme.onSurfaceVariant,
                        trackOutlineColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected) ? Colors.transparent : scheme.outlineVariant,
                        ),
                      ),
                      onTap: () => _setMarketing(context, !(profile?.notifyMarketing ?? true)),
                    ),
                    MenuRow(
                      icon: Icons.lock_outline,
                      title: l10n.changePassword,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResetPasswordScreen(),
                        ),
                      ),
                    ),
                    // A way to reach a person. The site has a contact form;
                    // this is the same inbox, with the account attached so the
                    // reply lands without anyone typing their address.
                    MenuRow(
                      icon: Icons.support_agent_outlined,
                      title: l10n.contactSupport,
                      subtitle: l10n.contactSupportSub,
                      onTap: () => openSupportThread(context),
                    ),
                  ],
                ),

                // "Settings & privacy" used to sit here with `onTap: () {}`.
                // It went nowhere, so it is gone rather than left as a row
                // that does nothing when pressed.
                MenuGroup(
                  children: [
                    MenuRow(
                      icon: Icons.logout,
                      title: l10n.logOut,
                      danger: true,
                      onTap: () => _logOut(context),
                    ),
                  ],
                ),

                // Deliberately its own group, below signing out and set apart
                // from it. Both rows are red, and sitting them together put
                // the irreversible one directly above the one people tap all
                // the time — a thumb aiming for Log out lands on Delete.
                MenuGroup(
                  margin: const EdgeInsets.only(top: 16, bottom: 16),
                  children: [
                    MenuRow(
                      icon: Icons.delete_outline,
                      title: l10n.deleteAccount,
                      danger: true,
                      onTap: _deleteAccount,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The three-number strip under the progress card: earnings, active listings,
/// messages. One glass card, three columns split by hairline dividers — the
/// deck's arrangement, and the same surface language as the groups around it.
class _StatStrip extends StatelessWidget {
  final String earnings;
  final int activeListings;
  final int messages;
  final String earningsLabel;
  final String activeLabel;
  final String messagesLabel;

  const _StatStrip({
    required this.earnings,
    required this.activeListings,
    required this.messages,
    required this.earningsLabel,
    required this.activeLabel,
    required this.messagesLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.groupSurface,
        borderRadius: BorderRadius.circular(20),
        border: theme.brightness == Brightness.dark
            ? Border.all(color: theme.dividerColor)
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Stat(
              icon: Icons.bar_chart_rounded,
              value: earnings,
              label: earningsLabel,
            ),
            _Divider(color: theme.dividerColor),
            _Stat(
              icon: Icons.sell_outlined,
              value: '$activeListings',
              label: activeLabel,
            ),
            _Divider(color: theme.dividerColor),
            _Stat(
              icon: Icons.chat_bubble_outline,
              value: '$messages',
              label: messagesLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The lit tile from the menu rows, at a smaller size, so the strip
            // belongs to the same family as the groups beneath it.
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.85,
                  colors: [tokens.iconTile, tokens.iconTileEdge],
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: tokens.accentInk,
                shadows: [Shadow(color: tokens.iconGlow, blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) => VerticalDivider(
    width: 1,
    thickness: 1,
    color: color,
    indent: 4,
    endIndent: 4,
  );
}

/// The delete-account confirmation sheet.
///
/// Exists as a widget purely so the reason field's controller has an owner
/// with a `dispose` that runs at the right moment — when the sheet's element
/// is actually unmounted, not when the route's future completes. Pops the
/// typed reason (empty string when blank) on confirm, and null on cancel, so
/// the caller never holds a reference to the controller.
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.email, required this.sendsToLine});

  final String email;
  final Widget Function(BuildContext, String, String) sendsToLine;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: safeBottom(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteAccount,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          // The irreversibility is its own string rather than a phrase cut out
          // of the warning: emphasis by slicing a sentence only works in the
          // language it was written for, and this screen is trilingual.
          Text(
            l10n.deleteAccountIrreversible,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.error,
            ),
          ),
          const SizedBox(height: 6),
          Text(l10n.deleteAccountWarning),
          const SizedBox(height: 16),
          if (widget.email.isNotEmpty) ...[
            widget.sendsToLine(
              context,
              l10n.deleteAccountSendsTo(widget.email),
              widget.email,
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _reason,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: l10n.deleteAccountReason,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          // Stacked, not side by side. Every button in this app is themed
          // `minimumSize: Size.fromHeight(52)` — a minimum *width* of
          // infinity — so it is built to be full width and cannot be laid out
          // in a Row at all: the infinity reaches the Material and fails
          // performLayout.
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, _reason.text),
            child: Text(l10n.deleteAccountContinue),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}
