import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MandatoryPhoneSheet extends StatefulWidget {
  const MandatoryPhoneSheet({super.key});

  @override
  State<MandatoryPhoneSheet> createState() => _MandatoryPhoneSheetState();
}

class _MandatoryPhoneSheetState extends State<MandatoryPhoneSheet> {
  String _phoneNumber = '';
  String _detectedCountryCode = 'US';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _detectCountry();
  }

  Future<void> _detectCountry() async {
    // 1. Try system locale first
    try {
      final String? localeCode =
          WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      if (localeCode != null && localeCode.length == 2) {
        if (mounted) {
          setState(() {
            _detectedCountryCode = localeCode.toUpperCase();
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting locale: $e');
    }

    // 2. Try IP-based lookup
    try {
      final response = await http.get(
        Uri.parse('http://ip-api.com/json'),
        headers: {'User-Agent': 'Datedash/1.0.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String? countryCode = data['countryCode'];
        if (countryCode != null && countryCode.length == 2 && mounted) {
          setState(() {
            _detectedCountryCode = countryCode.toUpperCase();
          });
        }
      }
    } catch (e) {
      debugPrint('Error detecting country via IP: $e');
    }
  }

  Future<void> _handleSubmit() async {
    if (_phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.updateProfileField('phoneNumber', _phoneNumber);
      await profileProvider.updateProfileField('countryCode', _detectedCountryCode);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFFF4D85);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 32,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            32,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121217) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 	0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Icon(Iconsax.mobile5, color: Color(0xFFFF4D85), size: 48),
          const SizedBox(height: 16),
          const Text(
            'One last thing!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please verify your phone number to continue using DateDash safely.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 	0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 	0.1)
                    : Colors.grey.shade200,
              ),
            ),
            child: IntlPhoneField(
              decoration: InputDecoration(
                hintText: 'Phone Number',
                counterText: "",
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              initialCountryCode: _detectedCountryCode,
              key: ValueKey(_detectedCountryCode),
              onChanged: (phone) {
                _phoneNumber = phone.completeNumber;
                _detectedCountryCode = phone.countryISOCode;
              },
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
              dropdownTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'VERIFY & CONTINUE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
