import 'package:flutter/material.dart';

import '../Components/ReferalScreen.dart';
import '../api/auth_service.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'SignUpScreen.dart';
import 'SubscriptionScreen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedRole = 'buyer'; // 'buyer', 'buyer_seller', 'business'

  /// UI ids map onto the roles the API/database accept.
  String get _apiRole => switch (_selectedRole) {
        'buyer_seller' => 'individual_seller',
        'business' => 'business',
        _ => 'buyer',
      };

  Future<void> _handleRoleSubmission() async {
    final l10n = context.l10n;
    final auth = AuthService.instance;

    // No account yet → create one carrying the chosen role.
    if (auth.session == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SignUpScreen(role: _apiRole)),
      );
      return;
    }

    // Already signed in → persist the chosen role. This covers both a Google
    // sign-up finishing onboarding (creating its profile row with the picked
    // role + Google name) and an existing user upgrading from buyer.
    //
    // Read before the flag is cleared: it is what distinguishes a brand-new
    // social account from an existing user changing their role, and only the
    // former should be asked for a referral code.
    final isNewSocialSignUp = auth.needsRoleSelection.value;
    var referralHandled = false;
    try {
      await auth.syncProfile(
        role: _apiRole,
        displayName: auth.pendingOAuthDisplayName,
      );
      auth.pendingOAuthDisplayName = null;
      auth.needsRoleSelection.value = false;
      await auth.refreshMe();
      // The profile now exists, so a code parked earlier (someone who started
      // on the sign-up form, then chose Google instead) can finally be claimed.
      referralHandled = await auth.redeemPendingReferral();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.roleUpdateError)),
      );
      return;
    }
    if (!mounted) return;

    // A Google sign-up never sees the sign-up form, so this is the only moment
    // it can be asked who invited them — without this step the whole referral
    // feature is invisible to everyone who signs in with Google. Existing users
    // merely changing role skip it: they were attributed (or not) long ago, and
    // the server would refuse a second code anyway.
    if (isNewSocialSignUp && !referralHandled) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReferralScreen(
            nextRoute: _selectedRole == 'buyer' ? '/home' : '/subscription',
          ),
        ),
      );
      return;
    }

    switch (_selectedRole) {
      case 'buyer':
        // FREE tier: straight into the app.
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        break;

      case 'buyer_seller':
      case 'business':
        // PAID tiers: continue to the subscription step.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubscriptionScreen(roleType: _selectedRole),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.roleAppBarTitle),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.roleHeading,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.roleSubheading,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // Option 1: Buyer Only
              _buildRoleOptionCard(
                id: 'buyer',
                title: context.l10n.roleBuyerTitle,
                subtitle: context.l10n.roleBuyerSubtitle,
                badgeText: context.l10n.roleBadgeFree,
                badgeColor: AppColors.success,
                icon: Icons.shopping_bag_outlined,
              ),
              const SizedBox(height: 12),

              // Option 2: Individual Seller
              _buildRoleOptionCard(
                id: 'buyer_seller',
                title: context.l10n.roleBuyerSellerTitle,
                subtitle: context.l10n.roleBuyerSellerSubtitle,
                badgeText: context.l10n.roleBadgeSubscription,
                badgeColor: AppColors.warning,
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 12),

              // Option 3: Business Store
              _buildRoleOptionCard(
                id: 'business',
                title: context.l10n.roleBusinessTitle,
                subtitle: context.l10n.roleBusinessSubtitle,
                badgeText: context.l10n.roleBadgeBusiness,
                badgeColor: theme.colorScheme.primary,
                icon: Icons.business_outlined,
              ),

              const Spacer(),

              // Submit Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleRoleSubmission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _selectedRole == 'buyer'
                        ? context.l10n.roleContinueFree
                        : context.l10n.roleContinuePaid,
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
    );
  }

  Widget _buildRoleOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == id;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.08)
              : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? scheme.primary : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 28,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}