import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/user_profile_model.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../screens/landing_screen.dart';

class IncompleteProfileWizard extends StatefulWidget {
  final UserProfile profile;
  final int completion;

  const IncompleteProfileWizard({
    super.key,
    required this.profile,
    required this.completion,
  });

  @override
  State<IncompleteProfileWizard> createState() => _IncompleteProfileWizardState();
}

class _IncompleteProfileWizardState extends State<IncompleteProfileWizard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  late TextEditingController _firstNameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _heightController;
  late TextEditingController _occupationController;
  
  DateTime? _selectedDob;
  String? _selectedGender;
  String? _selectedInterestedIn;
  String? _selectedRelationshipStatus;
  String? _selectedLookingFor;
  String? _selectedBodyType;
  String? _selectedSmoking;
  String? _selectedDrinking;
  String? _selectedWantKids;
  String? _selectedEducationLevel;
  String? _selectedZodiac;

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final String _uploadUrl = 'https://unimarket-mw.com/datedash/api/upload.php';
  
  final Color _primaryColor = const Color(0xFFFF4D85);

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.profile.firstName ?? '');
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _locationController = TextEditingController(text: widget.profile.location ?? '');
    _heightController = TextEditingController(text: widget.profile.height ?? '');
    _occupationController = TextEditingController(text: widget.profile.occupation ?? '');
    
    _selectedDob = widget.profile.dob;
    _selectedGender = widget.profile.gender;
    _selectedInterestedIn = widget.profile.interestedIn;
    _selectedRelationshipStatus = widget.profile.relationshipStatus;
    _selectedLookingFor = widget.profile.lookingFor.isNotEmpty ? widget.profile.lookingFor.first : null;
    _selectedBodyType = widget.profile.bodyType;
    _selectedSmoking = widget.profile.smoking;
    _selectedDrinking = widget.profile.drinking;
    _selectedWantKids = widget.profile.wantKids;
    _selectedEducationLevel = widget.profile.educationLevel;
    _selectedZodiac = widget.profile.zodiac;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _heightController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _saveAndNext() async {
    setState(() {
      _isSaving = true;
    });

    final provider = context.read<ProfileProvider>();
    final profile = widget.profile;
    
    // Update local object
    profile.firstName = _firstNameController.text.trim();
    profile.bio = _bioController.text.trim();
    profile.location = _locationController.text.trim();
    profile.height = _heightController.text.trim();
    profile.occupation = _occupationController.text.trim();
    
    if (_selectedDob != null) profile.dob = _selectedDob;
    if (_selectedGender != null) profile.gender = _selectedGender;
    if (_selectedInterestedIn != null) profile.interestedIn = _selectedInterestedIn;
    if (_selectedRelationshipStatus != null) profile.relationshipStatus = _selectedRelationshipStatus;
    if (_selectedLookingFor != null) profile.lookingFor = [_selectedLookingFor!];
    if (_selectedBodyType != null) profile.bodyType = _selectedBodyType;
    if (_selectedSmoking != null) profile.smoking = _selectedSmoking;
    if (_selectedDrinking != null) profile.drinking = _selectedDrinking;
    if (_selectedWantKids != null) profile.wantKids = _selectedWantKids;
    if (_selectedEducationLevel != null) profile.educationLevel = _selectedEducationLevel;
    if (_selectedZodiac != null) profile.zodiac = _selectedZodiac;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await provider.saveUserProfile(user.uid, profile);
    }

    setState(() {
      _isSaving = false;
    });

    // Animate to next page if not the last
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      if (!mounted) return;
      final newCompletion = profile.completionPercentage;
      if (newCompletion < 40) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Your profile is currently $newCompletion% complete. Upload more details or photos to reach 40%!'),
            backgroundColor: _primaryColor,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadImages() async {
    // Prevent app locking when launching system image picker
    try {
      // Import of landing_screen.dart will be added at top, or we can use relative path
      // ignore: avoid_redundant_argument_values
      LandingScreen.ignoreNextLock = true;
    } catch (_) {}
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    if (!mounted) return;
    final List<String> photos = List<String>.from(widget.profile.photos);
    int remainingSlots = 6 - photos.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only have up to 6 photos in the wizard.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final List<XFile> toUpload = images.take(remainingSlots).toList();

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    int completed = 0;
    for (var image in toUpload) {
      try {
        var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
        request.files.add(await http.MultipartFile.fromPath('image', image.path));

        var response = await request.send();
        if (response.statusCode == 200) {
          var responseData = await response.stream.bytesToString();
          var jsonResponse = json.decode(responseData);

          if (jsonResponse['status'] == 'success') {
            String imageUrl = jsonResponse['url'];
            setState(() {
              photos.add(imageUrl);
              widget.profile.photos = photos;
            });
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Server Error: ${jsonResponse['message'] ?? 'Unknown error'}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('HTTP Error: ${response.statusCode}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Upload error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        completed++;
        setState(() {
          _uploadProgress = completed / toUpload.length;
        });
      }
    }

    if (!mounted) return;
    // Save updates
    final provider = context.read<ProfileProvider>();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await provider.saveUserProfile(user.uid, widget.profile);
    }

    setState(() {
      _isUploading = false;
    });
  }

  Widget _buildTextInput({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 	0.8),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 	0.35)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 	0.03),
            prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 	0.4), size: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 	0.08), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomSelectGrid({
    required String label,
    required String? value,
    required List<_SelectCardItem> items,
    required Function(String) onChanged,
    int crossAxisCount = 2,
    double childAspectRatio = 2.2,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 	0.8),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (crossAxisCount == 1)
          Column(
            children: items.map((item) {
              final isSelected = value == item.label;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: GestureDetector(
                  onTap: () => onChanged(item.label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 56,
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryColor.withValues(alpha: 	0.12) : Colors.white.withValues(alpha: 	0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? _primaryColor : Colors.white.withValues(alpha: 	0.08),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _primaryColor.withValues(alpha: 	0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? _primaryColor.withValues(alpha: 	0.2) : Colors.white.withValues(alpha: 	0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.icon,
                            color: isSelected ? _primaryColor : Colors.white.withValues(alpha: 	0.6),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 	0.7),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Iconsax.tick_circle,
                            color: _primaryColor,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = value == item.label;
              
              return GestureDetector(
                onTap: () => onChanged(item.label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryColor.withValues(alpha: 	0.12) : Colors.white.withValues(alpha: 	0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? _primaryColor : Colors.white.withValues(alpha: 	0.08),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _primaryColor.withValues(alpha: 	0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? _primaryColor.withValues(alpha: 	0.2) : Colors.white.withValues(alpha: 	0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.icon,
                          color: isSelected ? _primaryColor : Colors.white.withValues(alpha: 	0.6),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 	0.7),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Iconsax.tick_circle,
                          color: _primaryColor,
                          size: 14,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required Function(DateTime) onChanged,
  }) {
    final languageProvider = context.read<LanguageProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 	0.8),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: _primaryColor,
                      onPrimary: Colors.white,
                      surface: const Color(0xFF1E0B16),
                      onSurface: Colors.white,
                    ),
                    dialogTheme: const DialogThemeData(
                      backgroundColor: Color(0xFF0F0F12),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              onChanged(date);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 	0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 	0.08),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Iconsax.calendar,
                      color: Colors.white.withValues(alpha: 	0.4),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      value != null
                          ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'
                          : languageProvider.getString('select_date'),
                      style: TextStyle(
                        color: value != null ? Colors.white : Colors.white.withValues(alpha: 	0.35),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Iconsax.arrow_down_1,
                  color: Colors.white.withValues(alpha: 	0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoUploadGrid() {
    final photos = widget.profile.photos;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Photos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Upload up to 6 high-quality photos. Adding photos significantly boosts your completion score.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 	0.5),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        if (_isUploading)
          Column(
            children: [
              LinearProgressIndicator(
                value: _uploadProgress,
                color: _primaryColor,
                backgroundColor: Colors.white.withValues(alpha: 	0.1),
              ),
              const SizedBox(height: 8),
              Text(
                'Uploading selected photos...',
                style: TextStyle(color: Colors.white.withValues(alpha: 	0.5), fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            final hasPhoto = index < photos.length;
            
            if (hasPhoto) {
              final photoUrl = photos[index];
              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.white.withValues(alpha: 	0.05),
                          child: const Icon(Iconsax.image, color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () async {
                        final updatedPhotos = List<String>.from(widget.profile.photos);
                        updatedPhotos.removeAt(index);
                        setState(() {
                          widget.profile.photos = updatedPhotos;
                        });
                        final provider = context.read<ProfileProvider>();
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await provider.saveUserProfile(user.uid, widget.profile);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.close_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return GestureDetector(
                onTap: _isUploading ? null : _pickAndUploadImages,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 	0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 	0.12),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Iconsax.add,
                      color: _primaryColor.withValues(alpha: 	0.8),
                      size: 28,
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildProgressHeader(LanguageProvider lp) {
    final double progress = (_currentPage + 1) / 7.0;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Setup Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step ${_currentPage + 1} of 7',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 	0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 	0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primaryColor.withValues(alpha: 	0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.star5, color: Color(0xFFFF9F43), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Score: ${widget.completion}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Sleek neon progress bar
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 	0.06),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                width: MediaQuery.of(context).size.width * 0.88 * progress,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF4D85),
                      Color(0xFFFF9F43),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D85).withValues(alpha: 	0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWizardFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          if (_currentPage > 0)
            GestureDetector(
              onTap: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 	0.03),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 	0.08)),
                ),
                child: const Icon(
                  Iconsax.arrow_left_2,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            )
          else
            const SizedBox(width: 52),

          // Page indicators
          Row(
            children: List.generate(7, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: isActive ? 16 : 6,
                decoration: BoxDecoration(
                  color: isActive ? _primaryColor : Colors.white.withValues(alpha: 	0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),

          // Next / Finish button
          GestureDetector(
            onTap: _isSaving ? null : _saveAndNext,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor,
                    const Color(0xFFFF9F43),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 	0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _currentPage == 6 ? Iconsax.tick_circle : Iconsax.arrow_right_3,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWizardPage({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 	0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Background elegant gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F0F12),
                    Color(0xFF1C0A15),
                  ],
                ),
              ),
            ),
          ),
          // Glows
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryColor.withValues(alpha: 	0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB388FF).withValues(alpha: 	0.06),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildProgressHeader(languageProvider),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 	0.03),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 	0.08),
                              width: 1.5,
                            ),
                          ),
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            children: [
                              // PAGE 1: Basics (Name & DOB)
                              _buildWizardPage(
                                title: 'The Basics',
                                subtitle: 'Introduce yourself to the community',
                                children: [
                                  _buildTextInput(
                                    label: languageProvider.getString('username_label'),
                                    controller: _firstNameController,
                                    hint: 'Enter your first name',
                                    icon: Iconsax.user,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildDatePicker(
                                    label: languageProvider.getString('dob_label'),
                                    value: _selectedDob,
                                    onChanged: (date) {
                                      setState(() {
                                        _selectedDob = date;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              // PAGE 2: Identity & Vibe
                              _buildWizardPage(
                                title: 'Identity',
                                subtitle: 'Who are you and who matches your vibe?',
                                children: [
                                  _buildCustomSelectGrid(
                                    label: languageProvider.getString('gender_label'),
                                    value: _selectedGender,
                                    items: const [
                                      _SelectCardItem(label: 'Male', icon: Iconsax.man),
                                      _SelectCardItem(label: 'Female', icon: Iconsax.woman),
                                      _SelectCardItem(label: 'Non-Binary', icon: Iconsax.profile_2user),
                                      _SelectCardItem(label: 'Other', icon: Iconsax.more),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedGender = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  _buildCustomSelectGrid(
                                    label: languageProvider.getString('interested_in_label'),
                                    value: _selectedInterestedIn,
                                    items: const [
                                      _SelectCardItem(label: 'Men', icon: Iconsax.man),
                                      _SelectCardItem(label: 'Women', icon: Iconsax.woman),
                                      _SelectCardItem(label: 'Everyone', icon: Iconsax.people),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedInterestedIn = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              // PAGE 3: Status & Goals
                              _buildWizardPage(
                                title: 'Goals & Status',
                                subtitle: 'What are you looking for on DateDash?',
                                children: [
                                  _buildCustomSelectGrid(
                                    label: languageProvider.getString('relationship_status_label'),
                                    value: _selectedRelationshipStatus,
                                    items: const [
                                      _SelectCardItem(label: 'Single', icon: Iconsax.user),
                                      _SelectCardItem(label: 'Married', icon: Iconsax.heart5),
                                      _SelectCardItem(label: 'Divorced', icon: Iconsax.user_remove),
                                      _SelectCardItem(label: 'Widowed', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Separated', icon: Iconsax.slash),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedRelationshipStatus = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  _buildCustomSelectGrid(
                                    label: 'Looking For',
                                    value: _selectedLookingFor,
                                    items: const [
                                      _SelectCardItem(label: 'Marriage', icon: Iconsax.heart5),
                                      _SelectCardItem(label: 'Long Term Relationship', icon: Iconsax.clock),
                                      _SelectCardItem(label: 'Short Term Relationship', icon: Iconsax.timer),
                                      _SelectCardItem(label: 'Hookups', icon: Iconsax.flash),
                                      _SelectCardItem(label: 'Short Term Fun', icon: Iconsax.emoji_happy),
                                      _SelectCardItem(label: 'New Friends', icon: Iconsax.people),
                                      _SelectCardItem(label: 'Coffee Date', icon: Iconsax.cup),
                                      _SelectCardItem(label: 'Movie Night', icon: Iconsax.video),
                                      _SelectCardItem(label: 'Sponsor', icon: Iconsax.card),
                                      _SelectCardItem(label: 'Figuring Out', icon: Iconsax.info_circle),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedLookingFor = val;
                                      });
                                    },
                                    crossAxisCount: 1,
                                  ),
                                ],
                              ),
                              // PAGE 4: Habits & Lifestyle
                              _buildWizardPage(
                                title: 'Habits & Lifestyle',
                                subtitle: 'Help matches understand your daily habits',
                                children: [
                                  _buildCustomSelectGrid(
                                    label: languageProvider.getString('smoking_label'),
                                    value: _selectedSmoking,
                                    items: const [
                                      _SelectCardItem(label: 'Yes', icon: Iconsax.activity),
                                      _SelectCardItem(label: 'No', icon: Iconsax.close_circle),
                                      _SelectCardItem(label: 'Occasionally', icon: Iconsax.timer),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedSmoking = val;
                                      });
                                    },
                                    crossAxisCount: 3,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildCustomSelectGrid(
                                    label: languageProvider.getString('drinking_label'),
                                    value: _selectedDrinking,
                                    items: const [
                                      _SelectCardItem(label: 'Yes', icon: Iconsax.cup),
                                      _SelectCardItem(label: 'No', icon: Iconsax.close_circle),
                                      _SelectCardItem(label: 'Socially', icon: Iconsax.people),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedDrinking = val;
                                      });
                                    },
                                    crossAxisCount: 3,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildCustomSelectGrid(
                                    label: languageProvider.getString('want_kids_label'),
                                    value: _selectedWantKids,
                                    items: const [
                                      _SelectCardItem(label: 'Yes', icon: Iconsax.emoji_happy),
                                      _SelectCardItem(label: 'No', icon: Iconsax.close_circle),
                                      _SelectCardItem(label: 'Maybe', icon: Iconsax.info_circle),
                                      _SelectCardItem(label: 'Already have', icon: Iconsax.star),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedWantKids = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              // PAGE 5: Details & Star Sign
                              _buildWizardPage(
                                title: 'Personality & Vibe',
                                subtitle: 'What makes you unique?',
                                children: [
                                  _buildCustomSelectGrid(
                                    label: languageProvider.getString('body_type_label'),
                                    value: _selectedBodyType,
                                    items: const [
                                      _SelectCardItem(label: 'Slim', icon: Iconsax.profile),
                                      _SelectCardItem(label: 'Athletic', icon: Iconsax.activity),
                                      _SelectCardItem(label: 'Average', icon: Iconsax.user),
                                      _SelectCardItem(label: 'Curvy', icon: Iconsax.profile_2user),
                                      _SelectCardItem(label: 'A few extra pounds', icon: Iconsax.profile_add),
                                      _SelectCardItem(label: 'Prefer not to say', icon: Iconsax.close_circle),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedBodyType = val;
                                      });
                                    },
                                    crossAxisCount: 1,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildCustomSelectGrid(
                                    label: languageProvider.getString('education_level_label'),
                                    value: _selectedEducationLevel,
                                    items: const [
                                      _SelectCardItem(label: 'High School', icon: Iconsax.teacher),
                                      _SelectCardItem(label: 'In College', icon: Iconsax.book),
                                      _SelectCardItem(label: 'Undergraduate', icon: Iconsax.award),
                                      _SelectCardItem(label: 'Postgraduate', icon: Iconsax.briefcase),
                                      _SelectCardItem(label: 'Other', icon: Iconsax.more),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedEducationLevel = val;
                                      });
                                    },
                                    crossAxisCount: 1,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildCustomSelectGrid(
                                    label: languageProvider.getString('zodiac_label'),
                                    value: _selectedZodiac,
                                    items: const [
                                      _SelectCardItem(label: 'Aries', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Taurus', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Gemini', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Cancer', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Leo', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Virgo', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Libra', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Scorpio', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Sagittarius', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Capricorn', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Aquarius', icon: Iconsax.star),
                                      _SelectCardItem(label: 'Pisces', icon: Iconsax.star),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedZodiac = val;
                                      });
                                    },
                                    childAspectRatio: 2.4,
                                  ),
                                ],
                              ),
                              // PAGE 6: Bio & Location
                              _buildWizardPage(
                                title: 'Tell Us More',
                                subtitle: 'Where do you live and what is your story?',
                                children: [
                                  _buildTextInput(
                                    label: languageProvider.getString('location_title'),
                                    controller: _locationController,
                                    hint: 'e.g. London, UK',
                                    icon: Iconsax.location,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildTextInput(
                                    label: 'Height',
                                    controller: _heightController,
                                    hint: 'e.g. 175 cm',
                                    icon: Iconsax.ruler,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildTextInput(
                                    label: languageProvider.getString('occupation_label'),
                                    controller: _occupationController,
                                    hint: 'e.g. Software Engineer',
                                    icon: Iconsax.briefcase,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildTextInput(
                                    label: languageProvider.getString('bio_about_label'),
                                    controller: _bioController,
                                    hint: 'Tell us a bit about who you are...',
                                    maxLines: 4,
                                    icon: Iconsax.note_2,
                                  ),
                                ],
                              ),
                              // PAGE 7: Photo upload
                              _buildWizardPage(
                                title: 'Photos',
                                subtitle: 'Show off your best angles!',
                                children: [
                                  _buildPhotoUploadGrid(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildWizardFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectCardItem {
  final String label;
  final IconData icon;
  const _SelectCardItem({required this.label, required this.icon});
}
