import 'package:flutter/material.dart';
import 'SubscriptionScreen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedRole = 'buyer'; // 'buyer', 'buyer_seller', 'business'

  void _handleRoleSubmission() {
    switch (_selectedRole) {
      case 'buyer':
      // FREE tier: Goes directly to Main Shell
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        break;

      case 'buyer_seller':
      case 'business':
      // PAID tiers: Must complete subscription/billing step
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
        title: const Text('Choose Account Type'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How will you use the platform?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can update your tier or subscribe anytime later in settings.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // Option 1: Buyer Only
              _buildRoleOptionCard(
                id: 'buyer',
                title: 'Buyer (Individual)',
                subtitle: 'Browse items, chat with sellers, save favorites.',
                badgeText: 'FREE',
                badgeColor: Colors.green,
                icon: Icons.shopping_bag_outlined,
              ),
              const SizedBox(height: 12),

              // Option 2: Individual Seller
              _buildRoleOptionCard(
                id: 'buyer_seller',
                title: 'Buyer + Seller (Individual)',
                subtitle: 'Post & manage items in your personal seller dashboard.',
                badgeText: 'SUBSCRIPTION',
                badgeColor: Colors.amber.shade800,
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 12),

              // Option 3: Business Store
              _buildRoleOptionCard(
                id: 'business',
                title: 'Business Store',
                subtitle: 'Branded storefront, custom banner/logo & store features.',
                badgeText: 'BUSINESS TIER',
                badgeColor: Colors.indigo,
                icon: Icons.business_outlined,
              ),

              const Spacer(),

              // Submit Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleRoleSubmission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _selectedRole == 'buyer'
                        ? 'Get Started (Free)'
                        : 'Continue to Subscription Plan',
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

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.indigo : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: isSelected ? Colors.indigo : Colors.grey.shade600),
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
                          color: badgeColor.withOpacity(0.1),
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
                      color: Colors.grey.shade600,
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