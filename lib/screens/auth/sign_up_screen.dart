import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../widgets/social_login_button.dart';
import '../../services/auth_service.dart';
import '../../services/email_verification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

import 'verify_email_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _phoneNumber = '';
  String _detectedCountryCode = 'US';
  final _authService = AuthService();
  final _emailVerificationService = EmailVerificationService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _detectCountry();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _detectCountry() async {
    // 1. Try system locale first (Instant & Offline)
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

    // 2. Try IP-based lookup as a second layer (More accurate if user is traveling)
    try {
      // Using ip-api.com as it's often more accessible than ipapi.co
      final response = await http.get(
        Uri.parse('http://ip-api.com/json'),
        headers: {'User-Agent': 'Snellum/1.0.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String? countryCode =
            data['countryCode']; // ip-api uses countryCode
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

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        name.isEmpty ||
        _phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getString('fill_all_fields'),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Send verification code
      await _emailVerificationService.requestCode(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code sent to $email'),
          backgroundColor: const Color(0xFFFF4D85),
        ),
      );

      // 2. Navigate to dedicated VerifyEmailScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: email,
            password: password,
            name: name,
            phoneNumber: _phoneNumber,
            isSignUpFlow: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send verification code: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'An error occurred')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/newlogo.png',
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                languageProvider.getString('signup_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                languageProvider.getString('signup_sub'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                hintText: languageProvider.getString('full_name'),
                icon: Iconsax.user,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _emailController,
                hintText: languageProvider.getString('email'),
                icon: Iconsax.sms,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IntlPhoneField(
                  decoration: InputDecoration(
                    hintText: 'Phone Number',
                    counterText: "",
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Iconsax.mobile,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                  initialCountryCode: _detectedCountryCode,
                  key: ValueKey(_detectedCountryCode),
                  dropdownIconPosition: IconPosition.trailing,
                  dropdownIcon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  pickerDialogStyle: PickerDialogStyle(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    countryCodeStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    countryNameStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    searchFieldInputDecoration: InputDecoration(
                      hintText: 'Search country',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  flagsButtonPadding: const EdgeInsets.only(left: 8),
                  showDropdownIcon: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: (phone) {
                    _phoneNumber = phone.completeNumber;
                  },
                  languageCode: "en",
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _passwordController,
                hintText: languageProvider.getString('password'),
                icon: Iconsax.lock,
                isPassword: true,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _handleSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D85),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFFFF4D85).withValues(alpha: 0.5),
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
                    : Text(
                        languageProvider.getString('signup_button'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      languageProvider.getString('register_with'),
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 8),
              SocialLoginButton(
                text: languageProvider.getString('google_signin'),
                assetPath: 'assets/images/google_logo.png',
                onPressed: _isLoading ? () {} : _handleGoogleSignIn,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    languageProvider.getString('already_have_account'),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      languageProvider.getString('signin_button'),
                      style: const TextStyle(
                        color: Color(0xFFFF4D85),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
