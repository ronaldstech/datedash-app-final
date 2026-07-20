import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../services/profile_service.dart';
import '../services/payment_service.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final ProfileService _profileService = ProfileService();
  final PaymentService _paymentService = PaymentService();
  final Set<String> _loadingIds = {};

  Future<void> _reverifyTransaction(TransactionModel tx) async {
    if (tx.chargeId == null || tx.chargeId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No tracking ID found for this transaction')),
      );
      return;
    }

    setState(() => _loadingIds.add(tx.id));

    try {
      final result = await _paymentService.verifyPayment(tx.chargeId!);
      
      final topStatus = result['status']?.toString().toLowerCase();
      final innerStatus = result['data']?['status']?.toString().toLowerCase();

      if (topStatus == 'successful' || topStatus == 'success' || innerStatus == 'success') {
        // 1. Update Firestore status
        await _profileService.updateTransactionStatus(tx.id, 'success');

        // 2. Apply the purchased product
        if (tx.type == 'subscription' && tx.plan != null) {
          final isMonthly = tx.plan!.toLowerCase().contains('monthly') || 
                            tx.amount > 10000; // Hard fallback logic if needed
          await _profileService.updatePremiumStatus(tx.uid, tx.plan!, isMonthly);
        } else if (tx.type == 'credits' && tx.creditAmount != null) {
          await _profileService.addCredits(tx.uid, tx.creditAmount!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment confirmed! Your account has been updated.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          final msg = result['message'] ?? 'Payment still pending or failed on server.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingIds.remove(tx.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D11) : const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(
          languageProvider.getString('transactions'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: profileProvider.currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<TransactionModel>>(
              stream: _profileService.getUserTransactions(profileProvider.currentUser!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D85)));
                }

                if (snapshot.hasError) {
                  debugPrint('Transactions Error: ${snapshot.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.danger5, size: 64, color: Colors.blueGrey),
                          const SizedBox(height: 16),
                          Text('Error loading transactions', style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 	0.05) : Colors.black.withValues(alpha: 	0.03),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Iconsax.receipt_21, size: 64, color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No transactions yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your payment history will appear here',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return _buildTransactionCard(context, tx, isDark);
                  },
                );
              },
            ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, TransactionModel tx, bool isDark) {
    final status = tx.status.toLowerCase();
    final isSuccess = status == 'success';
    final statusColor = isSuccess ? Colors.greenAccent : (status == 'pending' ? Colors.orangeAccent : Colors.redAccent);
    final isSubscription = tx.type == 'subscription';
    final isLoading = _loadingIds.contains(tx.id);
    
    final dateStr = '${tx.timestamp.day}/${tx.timestamp.month}/${tx.timestamp.year} ${tx.timestamp.hour}:${tx.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 	0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 	0.05) : Colors.black.withValues(alpha: 	0.03)),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 	0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Leading Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: (isSubscription ? const Color(0xFFFF4D85) : Colors.blueAccent).withValues(alpha: 	0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSubscription ? Iconsax.ranking : Iconsax.wallet_2,
                color: isSubscription ? const Color(0xFFFF4D85) : Colors.blueAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSubscription ? (tx.plan ?? 'Premium') : '${tx.creditAmount} Credits',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(color: Theme.of(context).hintColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tx.operator.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).hintColor),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Amount & Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tx.amount.toInt()} MWK',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isSuccess)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: isLoading 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF4D85)))
                          : IconButton(
                              onPressed: () => _reverifyTransaction(tx),
                              icon: const Icon(Iconsax.refresh, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Re-verify Payment',
                            ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 	0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSuccess ? Icons.check_circle : (status == 'pending' ? Icons.history : Icons.error),
                            size: 12,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tx.status.toUpperCase(),
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

