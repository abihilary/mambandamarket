import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/auth_service.dart';
import '../api/models.dart';
import 'ResetPasswordScreen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _resendConfirmation(BuildContext context, String email) async {
    try {
      await AuthService.instance.resendConfirmation(email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmation email sent.')),
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

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ValueListenableBuilder<Me?>(
        valueListenable: auth.me,
        builder: (context, me, _) {
          final profile = me?.profile;
          final name = profile?.displayName?.isNotEmpty == true
              ? profile!.displayName!
              : (auth.user?.email?.split('@').first ?? 'Your account');
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
                    backgroundImage:
                        (avatar != null && avatar.isNotEmpty)
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
                      title: const Text('Email not confirmed',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Confirm your address to secure your account.'),
                      trailing: TextButton(
                        onPressed: () => _resendConfirmation(context, email),
                        child: const Text('Resend'),
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
                              ? 'Plan: ${me.subscription!['plan']}'
                              : 'Free plan',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          me.listingLimit == null
                              ? '${me.activeListings} active · unlimited listings'
                              : '${me.activeListings} of ${me.listingLimit} listings used',
                        ),
                        trailing: TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/subscription'),
                          child: const Text('Upgrade'),
                        ),
                      ),
                    ),
                  ),

                const Divider(height: 32),

                ListTile(
                  leading: const Icon(Icons.storefront_outlined,
                      color: Colors.indigo),
                  title: const Text('Switch to Business Dashboard'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () =>
                      Navigator.pushNamed(context, '/business-dashboard'),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.person_outline, color: Colors.indigo),
                  title: const Text('Switch to Seller Hub'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/seller-dashboard'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ResetPasswordScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings & Privacy'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Log Out',
                      style: TextStyle(color: Colors.red)),
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
