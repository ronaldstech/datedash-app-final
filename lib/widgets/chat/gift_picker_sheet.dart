import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/gift_model.dart';
import '../../providers/profile_provider.dart';
import '../../providers/language_provider.dart';

class GiftPickerSheet extends StatelessWidget {
  final Function(String giftType, int giftCost) onSelectGift;

  const GiftPickerSheet({
    super.key,
    required this.onSelectGift,
  });

  static Future<void> show({
    required BuildContext context,
    required Function(String giftType, int giftCost) onSelectGift,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GiftPickerSheet(onSelectGift: onSelectGift),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gifts = GiftData.gifts;
    final profileProvider = context.watch<ProfileProvider>();
    final userCredits = profileProvider.userProfile?.credits ?? 0;
    final lp = context.watch<LanguageProvider>();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lp.getString('send_gift_title') != 'send_gift_title'
                    ? lp.getString('send_gift_title')
                    : 'Send a Gift',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$userCredits',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: gifts.length,
            itemBuilder: (context, index) {
              final gift = gifts[index];
              final canAfford = userCredits >= gift.cost;

              return GestureDetector(
                onTap: () {
                  if (!canAfford) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not enough credits!')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  onSelectGift(gift.name, gift.cost);
                },
                child: Opacity(
                  opacity: canAfford ? 1.0 : 0.4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: gift.color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: gift.color.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          gift.icon,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          gift.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${gift.cost}',
                          style: TextStyle(
                            color: gift.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
