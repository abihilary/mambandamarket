import 'package:flutter/material.dart';

class SubscriptionScreen extends StatefulWidget {
  final String roleType; // 'buyer_seller' or 'business'

  const SubscriptionScreen({
    super.key,
    required this.roleType,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isAnnual = true;
  bool _isLoading = false;
  String _selectedTier = 'pro'; // Default selection: 'classic', 'pro', or 'vip'

  // Tier Data Map
  Map<String, Map<String, dynamic>> _getTierData(bool isBusiness) {
    if (isBusiness) {
      return {
        'classic': {
          'name': 'Classic',
          'monthlyPrice': '€14.99',
          'annualPrice': '€11.99',
          'badge': null,
          'features': [
            'Basic Storefront Page',
            'Up to 25 Active Listings',
            'Standard Search Ranking',
            'Basic Customer Analytics',
          ],
        },
        'pro': {
          'name': 'Pro Business',
          'monthlyPrice': '€29.99',
          'annualPrice': '€23.99',
          'badge': 'MOST POPULAR',
          'features': [
            'Fully Custom Branded Storefront',
            'Unlimited Active Listings',
            'Priority Search Ranking',
            'Custom Logo & Shop Banner',
            'Advanced Sales Analytics',
          ],
        },
        'vip': {
          'name': 'VIP Enterprise',
          'monthlyPrice': '€59.99',
          'annualPrice': '€47.99',
          'badge': 'EXCLUSIVE',
          'features': [
            'All Pro Features Included',
            'Top Tier Homepage Placement',
            'Dedicated Account Manager',
            'Zero Marketplace Transaction Fees',
            'Verified Business Badge',
          ],
        },
      };
    } else {
      return {
        'classic': {
          'name': 'Classic',
          'monthlyPrice': '€2.99',
          'annualPrice': '€1.99',
          'badge': null,
          'features': [
            'Post Up to 5 Items',
            'Personal Seller Dashboard',
            'Standard Support',
          ],
        },
        'pro': {
          'name': 'Pro Seller',
          'monthlyPrice': '€5.99',
          'annualPrice': '€4.49',
          'badge': 'BEST VALUE',
          'features': [
            'Unlimited Item Listings',
            'Personal Seller Dashboard',
            'Direct Buyer Messaging',
            'Featured Listing Badges',
          ],
        },
        'vip': {
          'name': 'VIP Seller',
          'monthlyPrice': '€11.99',
          'annualPrice': '€8.99',
          'badge': 'TOP SELLER',
          'features': [
            'All Pro Features Included',
            'Top Placement in Search Results',
            'Instant Push Notifications to Buyers',
            '24/7 Priority Support',
          ],
        },
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = widget.roleType == 'business';
    final tierData = _getTierData(isBusiness);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Plan'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBusiness ? 'Business Store Plans' : 'Seller Subscriptions',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose the plan that fits your growth goals.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // Monthly / Yearly Billing Toggle Switch
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isAnnual = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isAnnual ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !_isAnnual
                                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                      : [],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Monthly',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isAnnual = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isAnnual ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _isAnnual
                                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                      : [],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Yearly (Save 20%)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Tier 1: Classic
                    _buildTierCard(
                      id: 'classic',
                      data: tierData['classic']!,
                    ),
                    const SizedBox(height: 16),

                    // Tier 2: Pro (Default & Highlighted)
                    _buildTierCard(
                      id: 'pro',
                      data: tierData['pro']!,
                    ),
                    const SizedBox(height: 16),

                    // Tier 3: VIP
                    _buildTierCard(
                      id: 'vip',
                      data: tierData['vip']!,
                    ),

                    const SizedBox(height: 16),

                    // Store Policy & Restore Purchases Link (App Store Requirement)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('Terms of Use', style: TextStyle(fontSize: 12)),
                        ),
                        const Text('•', style: TextStyle(color: Colors.grey)),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Privacy Policy', style: TextStyle(fontSize: 12)),
                        ),
                        const Text('•', style: TextStyle(color: Colors.grey)),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Restore Purchases', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Checkout CTA Button
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _processSubscription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : Text(
                    'Subscribe to ${tierData[_selectedTier]!['name']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final isSelected = _selectedTier == id;
    final price = _isAnnual ? data['annualPrice'] : data['monthlyPrice'];
    final List<String> features = List<String>.from(data['features']);
    final String? badge = data['badge'];

    return GestureDetector(
      onTap: () => setState(() => _selectedTier = id),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected ? Colors.indigo.shade50.withOpacity(0.5) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.indigo : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: Colors.indigo.withOpacity(0.1), blurRadius: 10)]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data['name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.indigo : Colors.black,
                      ),
                    ),
                    Radio<String>(
                      value: id,
                      groupValue: _selectedTier,
                      activeColor: Colors.indigo,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTier = val);
                      },
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ month',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
                if (_isAnnual)
                  const Text(
                    'Billed annually',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                const Divider(height: 24),
                ...features.map((feature) => _buildFeatureRow(feature)),
              ],
            ),
          ),

          // Top Popular / Badge Chip
          if (badge != null)
            Positioned(
              top: -12,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.indigo : Colors.amber.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _processSubscription() async {
    setState(() => _isLoading = true);

    // Simulate Payment Gateway delay (e.g. Stripe / Apple In-App Purchase)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Navigate to appropriate flow upon successful billing
    if (widget.roleType == 'business') {
      Navigator.pushNamedAndRemoveUntil(context, '/bussiness', (route) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/seller-onboard', (route) => false);
    }
  }
}