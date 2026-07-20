import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import 'landing_screen.dart';


class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idNumberController = TextEditingController();
  
  XFile? _selectedImage;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  final ImagePicker _picker = ImagePicker();
  final String _uploadUrl = 'https://unimarket-mw.com/datedash/api/upload.php';
  final Color _primaryColor = const Color(0xFFFF4D85);

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }


  @override
  void dispose() {
    _nameController.dispose();
    _idNumberController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Prevent app lock when picking images
      try {
        LandingScreen.ignoreNextLock = true;
      } catch (_) {}
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      _showSnack('Error selecting image: $e', isError: true);
    }
  }



  Future<void> _submitVerification(ProfileProvider profileProvider, LanguageProvider lp) async {
    if (_nameController.text.trim().isEmpty || _idNumberController.text.trim().isEmpty) {
      _showSnack('Please fill in your name and ID number.', isError: true);
      return;
    }

    if (_selectedImage == null) {
      _showSnack('Please capture or select your ID document photo.', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
    });

    String? finalImageUrl;

    // Upload ID document photo
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.files.add(await http.MultipartFile.fromPath('image', _selectedImage!.path));
      
      setState(() => _uploadProgress = 0.4);
      var response = await request.send();
      
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);
        if (jsonResponse['status'] == 'success') {
          finalImageUrl = jsonResponse['url'];
        } else {
          throw Exception(jsonResponse['message'] ?? 'Upload rejected by server.');
        }
      } else {
        throw Exception('Server error code: ${response.statusCode}');
      }
    } catch (e) {
      _showSnack('Failed to upload ID photo. Please try again.', isError: true);
      if (mounted) setState(() { _isUploading = false; _uploadProgress = 0.0; });
      return;
    }

    setState(() => _uploadProgress = 0.8);

    try {
      final user = profileProvider.currentUser;
      if (user != null && profileProvider.userProfile != null) {
        final profile = profileProvider.userProfile!;
        profile.verificationStatus = 'pending';
        profile.nationalId = _idNumberController.text.trim();
        profile.nationalIdUrl = finalImageUrl;
        
        await profileProvider.saveUserProfile(user.uid, profile);
        
        _showSnack(lp.getString('verification_submitted_success'), isSuccess: true);
      }
    } catch (e) {
      _showSnack('Submission failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }



  void _showSnack(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError 
                  ? Icons.error_outline_rounded 
                  : (isSuccess ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded),
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : (isSuccess ? Colors.green : _primaryColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.userProfile;
    final status = profile?.verificationStatus ?? 'unverified';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lp.getString('verification_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          // Elegant dark-mode gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E0B29),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 550),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: _buildStateContent(status, profileProvider, lp),
              ),
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 	0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _primaryColor, value: _uploadProgress > 0 ? _uploadProgress : null),
                      const SizedBox(height: 20),
                      Text(
                        lp.getString('saving_label'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStateContent(String status, ProfileProvider profileProvider, LanguageProvider lp) {
    if (status == 'verified') {
      return _buildVerifiedState(lp);
    } else if (status == 'pending') {
      return _buildPendingState(profileProvider, lp);
    } else {
      return _buildUnverifiedState(profileProvider, lp);
    }
  }

  // State: UNVERIFIED
  Widget _buildUnverifiedState(ProfileProvider profileProvider, LanguageProvider lp) {
    return Column(
      key: const ValueKey('unverified_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trust Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor.withValues(alpha: 	0.15), Colors.purple.withValues(alpha: 	0.15)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _primaryColor.withValues(alpha: 	0.2)),
          ),
          child: Column(
            children: [
              Icon(Iconsax.shield_tick5, size: 50, color: _primaryColor),
              const SizedBox(height: 16),
              Text(
                lp.getString('verification_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                lp.getString('verification_sub'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 	0.7), fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Form Section
        Text(
          lp.getString('booking_preferences').toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primaryColor, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),

        Form(
          key: _formKey,
          child: Column(
            children: [
              // Full Name Input
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                decoration: InputDecoration(
                  labelText: lp.getString('full_name_on_id'),
                  prefixIcon: const Icon(Iconsax.user),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  floatingLabelStyle: TextStyle(color: _primaryColor),
                ),
              ),
              const SizedBox(height: 16),

              // ID Number Input
              TextFormField(
                controller: _idNumberController,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                decoration: InputDecoration(
                  labelText: lp.getString('national_id_number'),
                  prefixIcon: const Icon(Iconsax.personalcard),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  floatingLabelStyle: TextStyle(color: _primaryColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Document Image Selector
        Text(
          lp.getString('id_document_photo').toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primaryColor, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor, style: BorderStyle.solid),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _selectedImage != null
                ? Stack(
                    children: [
                      Image.file(
                        File(_selectedImage!.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 50),
                      ),
                      _imageOverlays(),
                    ],
                  )
                : InkWell(
                    onTap: () => _showImageSourcePicker(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.camera5, size: 44, color: _primaryColor.withValues(alpha: 	0.7)),
                        const SizedBox(height: 12),
                        Text(
                          lp.getString('id_document_photo'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to upload front side of ID card',
                          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 32),

        // Action Buttons
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _submitVerification(profileProvider, lp),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              lp.getString('submit_verification'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),

      ],
    );
  }

  Widget _imageOverlays() {
    return Positioned(
      top: 10,
      right: 10,
      child: Material(
        color: Colors.black.withValues(alpha: 	0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showImageSourcePicker(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: const Row(
              children: [
                Icon(Iconsax.edit, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Change', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select ID Photo Source',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 	0.1), shape: BoxShape.circle),
                child: Icon(Iconsax.camera, color: _primaryColor),
              ),
              title: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 	0.1), shape: BoxShape.circle),
                child: const Icon(Iconsax.gallery, color: Colors.purple),
              ),
              title: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // State: PENDING
  Widget _buildPendingState(ProfileProvider profileProvider, LanguageProvider lp) {
    final profile = profileProvider.userProfile;

    return Column(
      key: const ValueKey('pending_view'),
      children: [
        const SizedBox(height: 40),
        // Pulsating Pending Shield
        ScaleTransition(
          scale: _pulseScale,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 	0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.orange.withValues(alpha: 	0.2), width: 2),
            ),
            child: const Icon(
              Iconsax.shield_search,
              color: Colors.orange,
              size: 72,
            ),
          ),
        ),
        const SizedBox(height: 32),

        Text(
          lp.getString('verification_status_pending'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            lp.getString('verification_status_pending_sub'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 	0.6), fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 32),

        // Submitted Info Summary Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Submitted Details',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Name', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                  Text(profile?.firstName ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ID Number', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                  Text(profile?.nationalId ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Informational waiting card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 	0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.orange.withValues(alpha: 	0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Iconsax.info_circle, color: Colors.orange, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Under Review',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Colors.orange, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Our safety team typically reviews submissions within 24 hours. You will receive a notification once your identity has been verified.',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 	0.75),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // State: VERIFIED
  Widget _buildVerifiedState(LanguageProvider lp) {
    return Column(
      key: const ValueKey('verified_view'),
      children: [
        const SizedBox(height: 50),
        // Confetti burst animation structure (large green badge with verification mark)
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 	0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 	0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.verified,
            color: Colors.green,
            size: 88,
          ),
        ),
        const SizedBox(height: 36),

        Text(
          lp.getString('verification_status_verified'),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            lp.getString('verification_status_verified_sub'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 	0.65), fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 48),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.green.withValues(alpha: 	0.15)),
          ),
          child: const Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.verify, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'All Set!',
                    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 15),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Your verified checkmark is now visible on your profile card to matched users. Enjoy increased matching frequency and elevated trustworthiness!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
