import 'package:datedash/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:datedash/services/payment_service.dart';
import 'package:datedash/models/payment_operator_model.dart';
import 'package:datedash/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'edit_profile_screen.dart';

class PremiumScreen extends StatefulWidget {
  final int initialTab;
  const PremiumScreen({super.key, this.initialTab = 0});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  bool _isMonthly = true;
  int _currentPlanIndex = 1; // Default to 'Premium' (Index 1)
  final PaymentService _paymentService = PaymentService();

  final Map<String, Map<String, dynamic>> _countryData = {
    'MW': {
      'currency': 'MWK',
      'pro_weekly': '5,000',
      'pro_monthly': '10,000',
      'premium_weekly': '7,000',
      'premium_monthly': '15,000',
      'elite_weekly': '10,000',
      'elite_monthly': '30,000',
      'credit_prefix': 'MK',
      'credit_multiplier': 1,
      'phone_prefix': '+265',
    },
    'ZA': {
      'currency': 'ZAR',
      'pro_weekly': '99',
      'pro_monthly': '199',
      'premium_weekly': '149',
      'premium_monthly': '299',
      'elite_weekly': '199',
      'elite_monthly': '599',
      'credit_prefix': 'R',
      'credit_multiplier': 0.05,
      'phone_prefix': '+27',
    },
    'ZM': {
      'currency': 'ZMW',
      'pro_weekly': '150',
      'pro_monthly': '300',
      'premium_weekly': '200',
      'premium_monthly': '450',
      'elite_weekly': '300',
      'elite_monthly': '900',
      'credit_prefix': 'K',
      'credit_multiplier': 0.03,
      'phone_prefix': '+260',
    },
    'TZ': {
      'currency': 'TZS',
      'pro_weekly': '15,000',
      'pro_monthly': '30,000',
      'premium_weekly': '20,000',
      'premium_monthly': '45,000',
      'elite_weekly': '30,000',
      'elite_monthly': '90,000',
      'credit_prefix': 'TSh',
      'credit_multiplier': 3,
      'phone_prefix': '+255',
    },
    'MZ': {
      'currency': 'MZN',
      'pro_weekly': '350',
      'pro_monthly': '700',
      'premium_weekly': '500',
      'premium_monthly': '1,100',
      'elite_weekly': '700',
      'elite_monthly': '2,200',
      'credit_prefix': 'MT',
      'credit_multiplier': 0.06,
      'phone_prefix': '+258',
    },
    'KE': {
      'currency': 'KES',
      'pro_weekly': '700',
      'pro_monthly': '1,400',
      'premium_weekly': '1,000',
      'premium_monthly': '2,100',
      'elite_weekly': '1,400',
      'elite_monthly': '4,200',
      'credit_prefix': 'KSh',
      'credit_multiplier': 0.15,
      'phone_prefix': '+254',
    },
    'UG': {
      'currency': 'UGX',
      'pro_weekly': '20,000',
      'pro_monthly': '40,000',
      'premium_weekly': '25,000',
      'premium_monthly': '60,000',
      'elite_weekly': '40,000',
      'elite_monthly': '120,000',
      'credit_prefix': 'USh',
      'credit_multiplier': 4,
      'phone_prefix': '+256',
    },
    'RW': {
      'currency': 'RWF',
      'pro_weekly': '6,500',
      'pro_monthly': '13,000',
      'premium_weekly': '9,000',
      'premium_monthly': '19,000',
      'elite_weekly': '13,000',
      'elite_monthly': '39,000',
      'credit_prefix': 'FRw',
      'credit_multiplier': 1.3,
      'phone_prefix': '+250',
    },
    'BW': {
      'currency': 'BWP',
      'pro_weekly': '70',
      'pro_monthly': '140',
      'premium_weekly': '100',
      'premium_monthly': '210',
      'elite_weekly': '140',
      'elite_monthly': '420',
      'credit_prefix': 'P',
      'credit_multiplier': 0.014,
      'phone_prefix': '+267',
    },
    'ZW': {
      'currency': 'USD',
      'pro_weekly': '4.99',
      'pro_monthly': '9.99',
      'premium_weekly': '6.99',
      'premium_monthly': '14.99',
      'elite_weekly': '9.99',
      'elite_monthly': '29.99',
      'credit_prefix': '\$',
      'credit_multiplier': 0.001,
      'phone_prefix': '+263',
    },
  };

  Map<String, dynamic> _getPricing(String? countryCode) {
    if (countryCode != null && _countryData.containsKey(countryCode)) {
      return _countryData[countryCode]!;
    }
    // Default to USD
    return {
      'currency': 'USD',
      'pro_weekly': '4.99',
      'pro_monthly': '9.99',
      'premium_weekly': '6.99',
      'premium_monthly': '14.99',
      'elite_weekly': '9.99',
      'elite_monthly': '29.99',
      'credit_prefix': '\$',
      'credit_multiplier': 0.001,
    };
  }

  final List<String> proFeatures = [
    'Meet new friends',
    'Extended Filter',
    'Looking For',
    'See everyone\'s online status',
    'Rewind',
    '2x more profile views',
    'Unlimited likes',
    'See all your matches',
    'Unlimited messages',
    'Unlimited voice calls',
  ];

  final List<String> premiumFeatures = [
    'Meet new friends',
    'Extended Filter',
    'Looking For',
    'See everyone\'s online status',
    'Rewind',
    '2x more profile views',
    'Unlimited likes',
    'See all your matches',
    'Unlimited messages',
    'Unlimited voice calls',
    'Unlimited video calls',
    'See missed matches',
    '1 free profile boost per week',
  ];

  final List<String> eliteFeatures = [
    'Meet new friends',
    'Extended Filter',
    'Looking For',
    'See everyone\'s online status',
    'Rewind',
    '2x more profile views',
    'Unlimited likes',
    'See all your matches',
    'Unlimited messages',
    'Unlimited voice calls',
    'Unlimited video calls',
    'See missed matches',
    '2 free profile boosts',
    'Get 2000 free credits',
    'Hide your age on profile',
    'Green card',
    'Lock your profile',
    'Unlimited chat requests',
    'See who likes and match instantly',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    // ViewportFraction < 1 lets adjacent cards peek out at the edges
    _pageController = PageController(viewportFraction: 0.95, initialPage: 1);
  }

  @override
  void didUpdateWidget(covariant PremiumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabController.animateTo(widget.initialTab);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    // Force a dark premium look or enhance the dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0D11) : const Color(0xFFF7F7F9);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSubscriptionsTab(isDark),
                  _buildCreditsTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          // Custom TabBar Container
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 	0.05)
                  : Colors.black.withValues(alpha: 	0.03),
              borderRadius: BorderRadius.circular(19),
              border:
                  Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            padding: const EdgeInsets.all(2),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 	0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 	0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ]),
              labelColor: isDark ? Colors.white : Colors.black,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
              labelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Subscriptions'),
                Tab(text: 'Credits'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsTab(bool isDark) {
    return Column(
      children: [
        // Billing Toggle
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModernToggle(
                title: 'Weekly',
                isSelected: !_isMonthly,
                onTap: () => setState(() => _isMonthly = false),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildModernToggle(
                title: 'Monthly',
                isSelected: _isMonthly,
                onTap: () => setState(() => _isMonthly = true),
                isDark: isDark,
              ),
            ],
          ),
        ),

        // Clean PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) {
              setState(() => _currentPlanIndex = idx);
            },
            itemCount: 3,
            itemBuilder: (context, index) {
              return Opacity(
                opacity: index == _currentPlanIndex ? 1.0 : 0.7,
                child: _getPlanCardForIndex(index, isDark),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Simple Page Indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: index == _currentPlanIndex ? 24 : 8,
              decoration: BoxDecoration(
                color: index == _currentPlanIndex
                    ? const Color(0xFFFF4D85)
                    : (isDark ? Colors.white24 : Colors.black12),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildModernToggle(
      {required String title,
      required bool isSelected,
      required VoidCallback onTap,
      required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4D85) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF4D85)
                : (isDark ? Colors.white24 : Colors.black12),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: const Color(0xFFFF4D85).withValues(alpha: 	0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white54 : Colors.black54),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _getPlanCardForIndex(int index, bool isDark) {
    final profileProvider = context.read<ProfileProvider>();
    String? countryCode = profileProvider.userProfile?.countryCode;
    
    // Smart fallback: if countryCode is null but phone exists, try to detect from prefix
    if (countryCode == null || countryCode.isEmpty) {
      final phone = profileProvider.userProfile?.phoneNumber;
      if (phone != null) {
        for (var entry in _countryData.entries) {
          if (phone.startsWith(entry.value['phone_prefix'])) {
            countryCode = entry.key;
            break;
          }
        }
      }
    }

    final pricing = _getPricing(countryCode?.toUpperCase());

    if (index == 0) {
      return _buildPremiumGlassCard(
        title: 'PRO',
        weeklyPrice: pricing['pro_weekly'],
        monthlyPrice: pricing['pro_monthly'],
        currency: pricing['currency'],
        features: proFeatures,
        accentColor: const Color(0xFF4FC3F7),
        icon: Iconsax.flash5,
        isDark: isDark,
      );
    } else if (index == 1) {
      return _buildPremiumGlassCard(
        title: 'PREMIUM',
        weeklyPrice: pricing['premium_weekly'],
        monthlyPrice: pricing['premium_monthly'],
        currency: pricing['currency'],
        features: premiumFeatures,
        accentColor: const Color(0xFFFF4D85),
        icon: Iconsax.star5,
        isPopular: true,
        isDark: isDark,
      );
    } else {
      return _buildPremiumGlassCard(
        title: 'ELITE',
        weeklyPrice: pricing['elite_weekly'],
        monthlyPrice: pricing['elite_monthly'],
        currency: pricing['currency'],
        features: eliteFeatures,
        accentColor: const Color(0xFFB388FF),
        icon: Iconsax.crown5,
        isDark: isDark,
      );
    }
  }

  void _showFeaturesSheet(BuildContext context, String title,
      List<String> features, Color accentColor, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A1A22), const Color(0xFF0D0D11)]
                  : [Colors.white, const Color(0xFFF7F7F9)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 	0.15),
                blurRadius: 40,
                offset: const Offset(0, -10),
              )
            ],
          ),
          child: Stack(
            children: [
              // Decorative background element
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 	0.05),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Plan Icon/Badge (Reduced size)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 	0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withValues(alpha: 	0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          title == 'PRO'
                              ? Iconsax.flash5
                              : (title == 'PREMIUM'
                                  ? Iconsax.star5
                                  : Iconsax.crown5),
                          color: accentColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$title BENEFITS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: features.length,
                          itemBuilder: (context, index) {
                            return _buildPremiumFeatureItem(
                                features[index], accentColor, isDark);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Action Button
                      Container(
                        width: double.infinity,
                        height: 54,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor,
                              accentColor.withValues(alpha: 	0.8)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 	0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'BACK TO PLANS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumFeatureItem(
      String feature, Color accentColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 	0.03)
            : Colors.black.withValues(alpha: 	0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 	0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.tick_circle5,
            color: accentColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
      String feature, bool isPopular, Color accentColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Iconsax.tick_circle,
            color: isPopular ? Colors.white : accentColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isPopular
                    ? Colors.white.withValues(alpha: 	0.9)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumGlassCard({
    required String title,
    required String weeklyPrice,
    required String monthlyPrice,
    required String currency,
    required List<String> features,
    required Color accentColor,
    required IconData icon,
    required bool isDark,
    bool isPopular = false,
  }) {
    final price = _isMonthly ? monthlyPrice : weeklyPrice;
    final period = _isMonthly ? 'month' : 'week';
    const themePink = Color(0xFFFF4D85);
    const themePinkLight = Color(0xFFFF8EBD);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: isPopular
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [themePink, themePink.withValues(alpha: 	0.8)],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 	0.12),
                        Colors.white.withValues(alpha: 	0.05),
                      ]
                    : [
                        Colors.white,
                        Colors.white.withValues(alpha: 	0.9),
                      ],
              ),
        border: Border.all(
          color: isPopular
              ? Colors.white.withValues(alpha: 	0.3)
              : (isDark ? Colors.white12 : Colors.black12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPopular
                ? themePink.withValues(alpha: 	0.4)
                : (isDark ? Colors.black45 : Colors.black.withValues(alpha: 	0.05)),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Decorative elements for the most popular card
            if (isPopular)
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        themePinkLight.withValues(alpha: 	0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPopular
                              ? Colors.white.withValues(alpha: 	0.2)
                              : accentColor.withValues(alpha: 	0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          icon,
                          color: isPopular ? Colors.white : accentColor,
                          size: 24,
                        ),
                      ),
                      if (isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'MOST POPULAR',
                            style: TextStyle(
                              color: themePink,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isPopular
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        price.toString(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: isPopular
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$currency/$period',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isPopular
                              ? Colors.white70
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Feature Summary List (limit to 3)
                  Column(
                    children: features.take(3).map((feature) {
                      return _buildFeatureRow(
                          feature, isPopular, accentColor, isDark);
                    }).toList(),
                  ),
                  // See all features button
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: TextButton(
                        onPressed: () => _showFeaturesSheet(
                            context, title, features, accentColor, isDark),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          backgroundColor: isPopular
                              ? Colors.white.withValues(alpha: 	0.15)
                              : accentColor.withValues(alpha: 	0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View all ${features.length} benefits',
                              style: TextStyle(
                                color: isPopular ? Colors.white : accentColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Iconsax.arrow_right_3,
                              size: 14,
                              color: isPopular ? Colors.white : accentColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _showPaymentSheet(
                        context,
                        title: title,
                        price: double.parse(price.replaceAll(',', '')),
                        type: 'subscription',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPopular
                            ? Colors.white
                            : (isDark
                                ? Colors.white.withValues(alpha: 	0.1)
                                : Colors.black87),
                        foregroundColor: isPopular ? themePink : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Choose Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

  Widget _buildCreditsTab(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Modern Balance Card
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 	0.08),
                              Colors.white.withValues(alpha: 	0.02)
                            ]
                          : [
                              const Color(0xFFFFB300).withValues(alpha: 	0.1),
                              const Color(0xFFFFB300).withValues(alpha: 	0.05)
                            ],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark
                          ? Colors.white12
                          : const Color(0xFFFFB300).withValues(alpha: 	0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300).withValues(alpha: 	0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.wallet_3,
                            size: 32, color: Color(0xFFFFB300)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AVAILABLE BALANCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white60 : Colors.black54,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Consumer<ProfileProvider>(
                            builder: (context, provider, _) {
                              return Text(
                                _formatNumber(
                                    provider.userProfile?.credits ?? 0),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFFB300),
                                  height: 1.1,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'CREDITS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFB300),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Withdrawal Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _showWithdrawalSheet(context, isDark),
                    icon: const Icon(Iconsax.export_1, size: 20),
                    label: const Text(
                      'Withdraw Funds',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFB300),
                      side: BorderSide(
                        color: const Color(0xFFFFB300).withValues(alpha: 	0.5),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Purchase Credits',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 60 + MediaQuery.of(context).padding.bottom,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildListDelegate([
              _buildCreditGlassBundle(500, isDark),
              _buildCreditGlassBundle(1000, isDark, isPopular: true),
              _buildCreditGlassBundle(5000, isDark),
              _buildCreditGlassBundle(10000, isDark),
              _buildCreditGlassBundle(20000, isDark),
              _buildCreditGlassBundle(50000, isDark, bonus: '10,000 FREE'),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCreditGlassBundle(int amount, bool isDark,
      {bool isPopular = false, String? bonus}) {
    const themePink = Color(0xFFFF4D85);
    final profileProvider = context.read<ProfileProvider>();
    String? countryCode = profileProvider.userProfile?.countryCode;

    // Smart fallback: if countryCode is null but phone exists, try to detect from prefix
    if (countryCode == null || countryCode.isEmpty) {
      final phone = profileProvider.userProfile?.phoneNumber;
      if (phone != null) {
        for (var entry in _countryData.entries) {
          if (phone.startsWith(entry.value['phone_prefix'])) {
            countryCode = entry.key;
            break;
          }
        }
      }
    }

    final pricing = _getPricing(countryCode?.toUpperCase());
    final prefix = pricing['credit_prefix'];
    final multiplier = pricing['credit_multiplier'] as num;
    final priceValue = (amount * multiplier).toStringAsFixed(multiplier < 1 ? 2 : 0);

    return Container(
      decoration: BoxDecoration(
        color: isPopular
            ? themePink
            : (isDark ? Colors.white.withValues(alpha: 	0.05) : Colors.white),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isPopular
              ? Colors.white.withValues(alpha: 	0.3)
              : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 	0.05)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPopular
                ? themePink.withValues(alpha: 	0.3)
                : (isDark ? Colors.black45 : Colors.black.withValues(alpha: 	0.05)),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPopular
                          ? Colors.white.withValues(alpha: 	0.2)
                          : const Color(0xFFFFB300).withValues(alpha: 	0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.coin5,
                      size: 28,
                      color: isPopular ? Colors.white : const Color(0xFFFFB300),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatNumber(amount),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isPopular
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    'Credits',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPopular
                          ? Colors.white70
                          : (isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isPopular
                          ? Colors.white
                          : (isDark
                              ? Colors.white.withValues(alpha: 	0.1)
                              : Colors.black87),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showPaymentSheet(
                        context,
                        title: '$amount Credits',
                        price: double.parse(priceValue.replaceAll(',', '')),
                        type: 'credits',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        '$prefix $priceValue',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isPopular ? themePink : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isPopular && bonus == null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: themePink,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            if (bonus != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Text(
                    bonus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSheet(
    BuildContext context, {
    required String title,
    required double price,
    required String type,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _PaymentSheetContent(
          title: title,
          price: price,
          type: type,
          paymentService: _paymentService,
          isMonthly: _isMonthly,
        );
      },
    );
  }

  void _showWithdrawalSheet(BuildContext context, bool isDark) {
    final profileProvider = context.read<ProfileProvider>();
    final percentage = profileProvider.userProfile?.completionPercentage ?? 0;
    if (percentage < 100) {
      _showProfileIncompleteDialog(context, percentage);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _WithdrawalSheet(isDark: isDark);
      },
    );
  }

  void _showProfileIncompleteDialog(BuildContext context, int percentage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4D85), size: 28),
            SizedBox(width: 8),
            Text(
              'Profile Incomplete',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your profile is currently $percentage% complete.',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'For verification and security purposes, you must complete your profile to 100% before you can withdraw funds.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey.withValues(alpha: 	0.2),
                color: const Color(0xFFFF4D85),
                minHeight: 8,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalSheet extends StatefulWidget {
  final bool isDark;
  const _WithdrawalSheet({required this.isDark});

  @override
  State<_WithdrawalSheet> createState() => _WithdrawalSheetState();
}

class _WithdrawalSheetState extends State<_WithdrawalSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  PaymentOperator? _selectedOperator;
  bool _isProcessing = false;
  String? _errorMessage; // shown inline inside the sheet

  // 1 Credit = 1 MWK (example conversion)
  // Fees: 20% Service, 5% Gateway = 25% total
  double get _serviceFeePercent => 0.20;
  double get _gatewayFeePercent => 0.05;
  double get _totalFeePercent => _serviceFeePercent + _gatewayFeePercent;

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final balance = profileProvider.userProfile?.credits ?? 0;

    int amount = int.tryParse(_amountController.text) ?? 0;
    double fee = amount * _totalFeePercent;
    double payout = amount - fee;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Withdraw Funds',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Convert your credits to MWK and withdraw to your mobile wallet.',
              style: TextStyle(
                color: widget.isDark ? Colors.white60 : Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // Inline error banner
            if (_errorMessage != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _errorMessage = null),
                      child: Icon(Icons.close_rounded,
                          color: Colors.red.shade400, size: 18),
                    ),
                  ],
                ),
              ),

            // Amount Input
            Text(
              'AMOUNT TO WITHDRAW (Available: $balance)',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Minimum 5,000 Credits',
                prefixIcon: const Icon(Iconsax.coin),
                filled: true,
                fillColor: widget.isDark
                    ? Colors.white.withValues(alpha: 	0.05)
                    : Colors.black.withValues(alpha: 	0.03),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            // Operator Selection
            const Text(
              'SELECT OPERATOR',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildOperatorOption(
                    'Airtel Money', 'airtel', 'assets/images/airtel_logo.png'),
                const SizedBox(width: 12),
                _buildOperatorOption(
                    'TNM Mpamba', 'tnm', 'assets/images/tnm_logo.png'),
              ],
            ),
            const SizedBox(height: 24),

            // Phone Number
            const Text(
              'MOBILE WALLET NUMBER',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '09xxxxxxx or 08xxxxxxx',
                prefixIcon: const Icon(Iconsax.mobile),
                filled: true,
                fillColor: widget.isDark
                    ? Colors.white.withValues(alpha: 	0.05)
                    : Colors.black.withValues(alpha: 	0.03),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),

            // Fee Breakdown Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withValues(alpha: 	0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFFFB300).withValues(alpha: 	0.1)),
              ),
              child: Column(
                children: [
                  _buildFeeRow(
                      'Gross Amount', 'MK ${amount.toStringAsFixed(0)}'),
                  const Divider(height: 24),
                  _buildFeeRow('Service Fee (20%)',
                      '- MK ${(amount * _serviceFeePercent).toStringAsFixed(0)}'),
                  _buildFeeRow('Payment Gateway (5%)',
                      '- MK ${(amount * _gatewayFeePercent).toStringAsFixed(0)}'),
                  const Divider(height: 24),
                  _buildFeeRow('Total Payout', 'MK ${payout.toStringAsFixed(0)}',
                      isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: Withdrawals are processed within 24-48 hours.',
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _submitWithdrawal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirm Withdrawal',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorOption(String name, String id, String asset) {
    bool isSelected = _selectedOperator?.name == name;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedOperator = PaymentOperator(
              id: 0,
              name: name,
              refId: id,
              shortCode: id,
              logo: asset,
              supportsWithdrawals: true,
            );
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFB300).withValues(alpha: 	0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFB300)
                  : (widget.isDark ? Colors.white12 : Colors.black12),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(id == 'airtel' ? Icons.phone_android : Icons.mobile_friendly,
                  color: isSelected ? const Color(0xFFFFB300) : Colors.grey),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? const Color(0xFFFFB300) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeeRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
            color: isTotal
                ? (widget.isDark ? Colors.white : Colors.black87)
                : Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            color: isTotal
                ? const Color(0xFFFFB300)
                : (widget.isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  void _submitWithdrawal() async {
    final amountText = _amountController.text.trim();
    final amount = int.tryParse(amountText) ?? 0;
    final phone = _phoneController.text.trim();

    if (amount < 5000) {
      _showError('Minimum withdrawal is 5,000 Credits');
      return;
    }

    if (_selectedOperator == null) {
      _showError('Please select a mobile operator');
      return;
    }

    if (phone.length < 9) {
      _showError('Please enter a valid mobile number');
      return;
    }

    final lp = Provider.of<ProfileProvider>(context, listen: false);
    if ((lp.userProfile?.credits ?? 0) < amount) {
      _showError('Insufficient balance');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Consume credits
      await lp.useCredits(amount);

      // Simulate API Call for withdrawal record
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Failed to process withdrawal: $e');
      }
    }
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Withdrawal Submitted!',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            SizedBox(height: 8),
            Text(
                'Your request is being processed. You will receive MWK in your mobile wallet soon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it!')),
        ],
      ),
    );
  }
}

class _PaymentSheetContent extends StatefulWidget {
  final String title;
  final double price;
  final String type;
  final PaymentService paymentService;
  final bool isMonthly;

  const _PaymentSheetContent({
    required this.title,
    required this.price,
    required this.type,
    required this.paymentService,
    required this.isMonthly,
  });

  @override
  State<_PaymentSheetContent> createState() => _PaymentSheetContentState();
}

class _PaymentSheetContentState extends State<_PaymentSheetContent> {
  int _step = 0; // 0: Operator, 1: Phone, 2: Processing, 3: Success, 4: Error
  PaymentOperator? _selectedOperator;
  final TextEditingController _phoneController = TextEditingController();
  final ProfileService _profileService = ProfileService();
  String _errorMsg = '';
  String _txRef = '';
  String? _txDocId; // Track the Firestore document ID
  bool _isVerifying = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startPayment() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final user = profileProvider.userProfile;
    if (user == null) return;

    setState(() {
      _step = 2; // Processing
      _errorMsg = '';
    });

    try {
      // 1. Generate unique 32-bit integer reference
      // Unix timestamp in seconds currently fits in int32 (~1.7B < 2.1B)
      final int uniqueRef = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 2. Initialize
      final responseData = await widget.paymentService.initializePayment(
        mobile: _phoneController.text.trim(),
        amount: widget.price,
        email: profileProvider.currentUser?.email ?? 'user@datedash.com',
        operatorId: _selectedOperator!.refId,
        txRef: uniqueRef,
        firstName: user.firstName,
        lastName: '',
      );

      // CRITICAL: charge_id is the key for verification polling
      // ref_id is the secondary reference
      _txRef = (responseData['charge_id'] ?? responseData['ref_id'] ?? '')
          .toString();

      if (_txRef.isEmpty) {
        throw Exception('Invalid transaction record received from PayChangu');
      }

      // 3. Save PENDING transaction to Firestore immediately
      _txDocId = await _profileService.saveTransaction({
        'uid': profileProvider.currentUser!.uid,
        'txRef': uniqueRef, // Our generated integer reference
        'charge_id': _txRef, // PayChangu's tracking ID
        'amount': widget.price,
        'status': 'pending',
        'type': widget.type,
        'plan': widget.type == 'subscription' ? widget.title : null,
        'creditAmount': widget.type == 'credits'
            ? int.parse(widget.title.split(' ')[0])
            : null,
        'operator': _selectedOperator!.shortCode,
        'initResponse': responseData,
      });

      // 4. Start Verification Loop
      _verifyPaymentStatus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = 4;
          _errorMsg = e.toString();
        });
      }
    }
  }

  Future<void> _verifyPaymentStatus() async {
    if (_isVerifying) return;
    _isVerifying = true;

    int attempts = 0;
    const maxAttempts = 15; // Verify for ~45 seconds

    while (attempts < maxAttempts && mounted) {
      try {
        final result = await widget.paymentService.verifyPayment(_txRef);
        // Top level status "successful" or "success", inner status "success"
        final topStatus = result['status']?.toString().toLowerCase();
        final innerStatus = result['data']?['status']?.toString().toLowerCase();

        if (topStatus == 'successful' ||
            topStatus == 'success' ||
            innerStatus == 'success') {
          // Success! Update Firestore document status
          if (_txDocId != null) {
            await _profileService.updateTransactionStatus(_txDocId!, 'success');
          }
          await _handleSuccess();
          if (mounted) setState(() => _step = 3);
          return;
        } else if (topStatus == 'failed' || innerStatus == 'failed') {
          // Update Firestore for failure if possible
          if (_txDocId != null) {
            await _profileService.updateTransactionStatus(_txDocId!, 'failed');
          }
          if (mounted) {
            setState(() {
              _step = 4;
              _errorMsg = result['message'] ?? 'Payment failed';
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('Verification attempt failed: $e');
      }

      attempts++;
      await Future.delayed(const Duration(seconds: 3));
    }

    if (mounted) {
      setState(() {
        _step = 4;
        _errorMsg =
            'Timeout: Payment verification is taking too long. Please check your balance or contact support.';
      });
    }
  }

  Future<void> _handleSuccess() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final uid = profileProvider.currentUser?.uid;
    if (uid == null) return;

    // Transaction is now updated in _verifyPaymentStatus
    // We just handle the profile updates here

    // Update user profile
    if (widget.type == 'subscription') {
      await _profileService.updatePremiumStatus(
          uid, widget.title, widget.isMonthly);
    } else {
      final amount = int.parse(widget.title.split(' ')[0]);
      await _profileService.addCredits(uid, amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 	isDark ? 0.5 : 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 32 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Column(
              key: ValueKey<int>(_step),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                if (_step == 0) _buildOperatorSelection(isDark),
                if (_step == 1) _buildPhoneInput(isDark),
                if (_step == 2) _buildProcessing(isDark),
                if (_step == 3) _buildSuccess(isDark),
                if (_step == 4) _buildError(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorSelection(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          'Select Payment Method',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your preferred mobile money operator',
          style: TextStyle(
              fontSize: 14, color: isDark ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 24),
        FutureBuilder<List<PaymentOperator>>(
          future: widget.paymentService.getMobileOperators(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF4D85))),
              );
            } else if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('Failed to load operators.',
                      style: TextStyle(color: Colors.red.shade300)),
                ),
              );
            } else if (snapshot.hasData) {
              return Column(
                children: snapshot.data!.map((op) {
                  final bool isAirtel = op.shortCode == 'airtel';
                  final Color opColor =
                      isAirtel ? Colors.red : const Color(0xFF00C853);

                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedOperator = op;
                      _step = 1;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 	0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 	0.1)
                                : Colors.black.withValues(alpha: 	0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: opColor.withValues(alpha: 	0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 	0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                                border: Border.all(
                                    color: opColor.withValues(alpha: 	0.2), width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.asset(
                                  'assets/images/${op.shortCode}.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Icon(Iconsax.wallet_35, color: opColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    op.name,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                  Text(
                                    '${op.supportedCountry?.name ?? 'Malawi'} • ${op.supportedCountry?.currency ?? 'MWK'}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: opColor.withValues(alpha: 	0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Iconsax.arrow_right_3,
                                  size: 18, color: opColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildPhoneInput(bool isDark) {
    Color opColor = _selectedOperator!.shortCode == 'airtel'
        ? Colors.red
        : const Color(0xFF00C853);
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          'Confirm Details',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 	0.05)
                : Colors.black.withValues(alpha: 	0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 	0.1)
                    : Colors.black.withValues(alpha: 	0.05)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 	0.05),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                          'assets/images/${_selectedOperator!.shortCode}.png',
                          fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title.toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFFFF4D85),
                                letterSpacing: 1.2)),
                        Text('${_selectedOperator!.name} Payment',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark ? Colors.white70 : Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amount to Pay',
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54)),
                  Text('${widget.price.toInt()} MWK',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(
              fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            labelStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: 0),
            hintText: _selectedOperator?.shortCode == 'airtel'
                ? '09xxxxxxx'
                : '08xxxxxxx',
            prefixIcon: Icon(Iconsax.mobile5, color: opColor),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: opColor, width: 2)),
            filled: true,
            fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4D85), Color(0xFFFF8EBD)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D85).withValues(alpha: 	0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              if (_phoneController.text.length < 9) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please enter a valid number')));
                return;
              }
              _startPayment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Confirm & Pay',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text('Change payment method'),
        ),
      ],
    );
  }

  Widget _buildProcessing(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const _PulsingLogo(),
          const SizedBox(height: 32),
          Text(
            'Securely Processing...',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Confirm the payment prompt on your device. This may take a few seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white38 : Colors.black45,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 	0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.tick_circle5,
                size: 80, color: Colors.greenAccent),
          ),
          const SizedBox(height: 32),
          const Text(
            'Payment Successful!',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            'High five! Your ${widget.title} is now active and ready to go.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : Colors.black54,
                height: 1.5),
          ),
          const SizedBox(height: 40),
          Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4D85), Color(0xFFFF8EBD)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4D85).withValues(alpha: 	0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Done!',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 	0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Iconsax.danger5, size: 80, color: Colors.redAccent),
          ),
          const SizedBox(height: 32),
          const Text(
            'Payment Failed',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMsg,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.redAccent.withValues(alpha: 	0.8),
                fontSize: 16,
                height: 1.5),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? Colors.white.withValues(alpha: 	0.05) : Colors.black12,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo();

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4D85), Color(0xFFFF8EBD)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: const Icon(Iconsax.receipt_2, color: Colors.white, size: 40),
      ),
    );
  }
}

