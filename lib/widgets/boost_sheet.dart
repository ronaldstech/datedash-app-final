import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../screens/premium_screen.dart';

class BoostSheet extends StatefulWidget {
  const BoostSheet({super.key});

  @override
  State<BoostSheet> createState() => _BoostSheetState();
}

class _BoostSheetState extends State<BoostSheet> {
  int _selectedWeeks = 1;
  bool _isActivating = false;

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProfileProvider>();
    final profile = pp.userProfile;
    final isPremium = profile?.isPremium == true;
    final sparks = profile?.sparks ?? 0;
    final isAlreadyBoosted = profile?.isBoosted == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final costs = {1: 100, 2: 180, 3: 250};
    final currentCost = costs[_selectedWeeks] ?? 100;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D85).withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Glowing Icon Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4D85), Color(0xFFFF9E00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Iconsax.flash5,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Boost Your Profile ⚡',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get up to 10x more views and matches by boosting your visibility!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          if (isAlreadyBoosted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9E00).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF9E00), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.flash5, color: Color(0xFFFF9E00), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Profile currently boosted until ${_formatDate(profile?.boostExpiry)}!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFFF9E00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Duration options
          Row(
            children: [1, 2, 3].map((weeks) {
              final isSelected = _selectedWeeks == weeks;
              final cost = costs[weeks]!;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedWeeks = weeks),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFFFF4D85), Color(0xFFFF9E00)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF4D85)
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF4D85).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Column(
                        children: [
                          if (weeks == 3)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'BEST VALUE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          Text(
                            '$weeks ${weeks == 1 ? 'Week' : 'Weeks'}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.flash5,
                                size: 14,
                                color: isSelected ? Colors.amber : Colors.amber.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPremium && weeks == 1 ? 'FREE' : '$cost Sparks',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Sparks balance info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.flash5, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Your Sparks Balance:',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$sparks Sparks',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D85),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 8,
                shadowColor: const Color(0xFFFF4D85).withValues(alpha: 0.4),
              ),
              onPressed: _isActivating ? null : _handleActivateBoost,
              child: _isActivating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      isAlreadyBoosted
                          ? 'Extend Boost ($currentCost Sparks)'
                          : (isPremium && _selectedWeeks == 1
                              ? 'Activate Free Boost'
                              : 'Activate Boost ($currentCost Sparks)'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleActivateBoost() async {
    final pp = context.read<ProfileProvider>();
    final isPremium = pp.userProfile?.isPremium == true;
    final useSparks = !(isPremium && _selectedWeeks == 1);

    setState(() => _isActivating = true);

    try {
      await pp.activateProfileBoost(_selectedWeeks, useSparks: useSparks);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚡ Profile Boost Activated for $_selectedWeeks ${_selectedWeeks == 1 ? 'week' : 'weeks'}!',
            ),
            backgroundColor: const Color(0xFFFF4D85),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActivating = false);
        if (e.toString().contains('Insufficient Sparks')) {
          _showTopUpSparksPrompt();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error activating boost: $e')),
          );
        }
      }
    }
  }

  void _showTopUpSparksPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Iconsax.flash5, color: Colors.amber),
            SizedBox(width: 10),
            Text('Need More Sparks?'),
          ],
        ),
        content: const Text(
          'You need more Sparks to activate this Profile Boost. Top up Sparks or upgrade to Premium for free boosts!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            child: const Text('Get Sparks / Premium'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }
}
