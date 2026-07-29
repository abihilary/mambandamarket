import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/auth_service.dart';
import '../api/models.dart';
import '../l10n/l10n.dart';
import 'ResetPasswordScreen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

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
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
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
                ? const Icon(Icons.check, color: Colors.indigo)
                : null,
            onTap: () {
              controller.setLocale(code == null ? null : Locale(code));
              Navigator.pop(sheetContext);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.language, color: Colors.indigo),
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
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.indigo.shade50,
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(avatar)
                        : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? Text(
                            name.characters.first.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo),
                          )
                        : null,
                  ),
                  title: Text(name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text(email),
                ),

                // Unconfirmed accounts can hold a session, so surface it here —
                // otherwise the user never learns why some things fail.
                if (!auth.isEmailConfirmed && email.isNotEmpty)
                  Card(
                    elevation: 0,
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade800),
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
                    child: Card(
                      elevation: 0,
                      color: Colors.indigo.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.workspace_premium_outlined,
                            color: Colors.indigo),
                        title: Text(
                          me.subscription?['plan'] != null
                              ? l10n.planLabel(me.subscription!['plan'].toString())
                              : l10n.freePlan,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          me.listingLimit == null
                              ? l10n.listingsUnlimited(me.activeListings)
                              : l10n.listingsUsed(
                                  me.activeListings, me.listingLimit!),
                        ),
                        trailing: TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/subscription'),
                          child: Text(l10n.changePlan),
                        ),
                      ),
                    ),
                  ),

                const Divider(height: 32),

                ListTile(
                  leading: const Icon(Icons.storefront_outlined,
                      color: Colors.indigo),
                  title: Text(l10n.businessDashboard),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () =>
                      Navigator.pushNamed(context, '/business-dashboard'),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.person_outline, color: Colors.indigo),
                  title: Text(l10n.sellerSpace),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/seller-dashboard'),
                ),
                const Divider(),

                // Language switcher — the "place to change language".
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.language),
                  subtitle: Text(_currentLanguageLabel(context)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _pickLanguage(context),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(l10n.changePassword),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ResetPasswordScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(l10n.settingsPrivacy),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(l10n.logOut,
                      style: const TextStyle(color: Colors.red)),
                  onTap: () => _logOut(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
