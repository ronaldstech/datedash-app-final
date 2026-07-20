import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_model.dart';
import '../services/profile_service.dart';
import '../providers/language_provider.dart';
import 'landing_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late UserProfile _profile;
  final Color _primaryColor = const Color(0xFFFF4D85);
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final _profileService = ProfileService();
  final ImagePicker _picker = ImagePicker();
  final String _uploadUrl = 'https://unimarket-mw.com/datedash/api/upload.php';

  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _profile = UserProfile.empty();
    _loadProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final existingProfile = await _profileService.getUserProfile(user.uid);
      if (existingProfile != null) {
        _profile = existingProfile;
      } else {
        if (user.displayName != null) {
          _profile.firstName = user.displayName;
        }
        if (user.photoURL != null) {
          _profile.photos = [user.photoURL!];
        }
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final languageProvider = context.read<LanguageProvider>();
    setState(() => _isSaving = true);
    try {
      await _profileService.saveUserProfile(user.uid, _profile);
      if (mounted) {
        _showPremiumSnack(languageProvider.getString('profile_saved_snack'), isSuccess: true);
        Navigator.pop(context); // Return to summary screen after save
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnack('${languageProvider.getString('failed_save_profile_snack')}: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _onFieldUpdated() {
    setState(() {}); // Unconditionally trigger rebuild to update percentage
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    
    final List<Map<String, dynamic>> categories = [
      {'title': languageProvider.getString('category_basic'), 'icon': Iconsax.user, 'key': 'Basic'},
      {'title': languageProvider.getString('category_personal'), 'icon': Iconsax.heart, 'key': 'Personal'},
      {'title': languageProvider.getString('category_goals'), 'icon': Iconsax.cup, 'key': 'Goals'},
      {'title': languageProvider.getString('category_work'), 'icon': Iconsax.briefcase, 'key': 'Work'},
      {'title': languageProvider.getString('category_lifestyle'), 'icon': Iconsax.activity, 'key': 'Lifestyle'},
      {'title': languageProvider.getString('category_interests'), 'icon': Iconsax.music, 'key': 'Interests'},
      {'title': languageProvider.getString('category_personality'), 'icon': Iconsax.lamp, 'key': 'Personality'},
      {'title': languageProvider.getString('category_media'), 'icon': Iconsax.camera, 'key': 'Media'},
      {'title': languageProvider.getString('category_location'), 'icon': Iconsax.location, 'key': 'Location'},
      {'title': languageProvider.getString('category_prompts'), 'icon': Iconsax.messages_2, 'key': 'Prompts'},
    ];

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.getString('edit_profile_label'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 	0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_profile.completionPercentage}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                      fontSize: 13),
                ),
              ),
            ),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: _buildCategorySelector(categories),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: _buildPages(languageProvider),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveProfile,
        backgroundColor: _primaryColor,
        icon: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Iconsax.save_2, color: Colors.white),
        label: Text(
          _isSaving ? languageProvider.getString('saving_label') : languageProvider.getString('save_profile_button'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCategorySelector(List<Map<String, dynamic>> categories) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 12, top: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _currentPage == index;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primaryColor
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? _primaryColor
                          : Theme.of(context).dividerColor,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _primaryColor.withValues(alpha: 	0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        category['icon'],
                        size: 15,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context)
                                .iconTheme
                                .color
                                ?.withValues(alpha: 	0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category['title'],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 	0.8),
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_profile.isCategoryComplete(category['key']))
                  Positioned(
                    right: 6,
                    top: -2,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPages(LanguageProvider languageProvider) {
    return [
      // 1. Basic Profile
      _buildPageContent([
        _buildTextField(
          label: languageProvider.getString('username_label'),
          initialValue: _profile.firstName,
          onChanged: (val) => _profile.firstName = val,
        ),
        _buildDatePicker(
          label: languageProvider.getString('dob_label'),
          value: _profile.dob,
          onChanged: (val) => _profile.dob = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('gender_label'),
          value: _profile.gender,
          items: const ['Male', 'Female', 'Other'],
          onChanged: (val) => _profile.gender = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('interested_in_label'),
          value: _profile.interestedIn,
          items: const ['Men', 'Women', 'Everyone'],
          onChanged: (val) => _profile.interestedIn = val,
        ),
        _buildTextField(
          label: languageProvider.getString('bio_about_label'),
          maxLines: 4,
          initialValue: _profile.bio,
          onChanged: (val) => _profile.bio = val,
        ),
      ]),
      // 2. Personal Details
      _buildPageContent([
        _buildTextField(
          label: languageProvider.getString('height_label'),
          hint: languageProvider.getString('height_hint'),
          initialValue: _profile.height,
          onChanged: (val) => _profile.height = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('body_type_label'),
          value: _profile.bodyType,
          items: const [
            'Slim',
            'Athletic',
            'Average',
            'Curvy',
            'A few extra pounds',
            'Prefer not to say'
          ],
          onChanged: (val) => _profile.bodyType = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('relationship_status_label'),
          value: _profile.relationshipStatus,
          items: const [
            'Single',
            'Married',
            'Divorced',
            'Widowed',
            'Separated'
          ],
          onChanged: (val) => _profile.relationshipStatus = val,
        ),
        _buildTextField(
          label: languageProvider.getString('religion_label'),
          initialValue: _profile.religion,
          onChanged: (val) => _profile.religion = val,
        ),
        _buildTextField(
          label: languageProvider.getString('languages_spoken_label'),
          initialValue: _profile.languages.join(', '),
          onChanged: (val) => _profile.languages = val
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        ),
      ]),
      // 3. Relationship Goals
      _buildPageContent([
        _buildChoiceChips(
          label: languageProvider.getString('looking_for_label'),
          value:
              _profile.lookingFor.isNotEmpty ? _profile.lookingFor.first : null,
          items: const [
            'Marriage',
            'Long Term Relationship',
            'Short Term Relationship',
            'Hookups',
            'Short Term Fun',
            'New Friends',
            'Coffee Date',
            'Movie Night',
            'Sponsor',
            'Figuring Out'
          ],
          onChanged: (val) => _profile.lookingFor = [val],
        ),
        _buildSwitch(
          label: languageProvider.getString('open_to_long_distance_label'),
          value: _profile.openToLongDistance ?? false,
          onChanged: (val) => _profile.openToLongDistance = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('want_kids_label'),
          value: _profile.wantKids,
          items: const ['Yes', 'No', 'Maybe', 'Already have'],
          onChanged: (val) => _profile.wantKids = val,
        ),
        _buildChoiceChips(
          label: 'Family Plans',
          value: _profile.familyPlans,
          items: const ['Want some day', 'Don\'t want', 'Have and want more', 'Have and don\'t want more', 'Not sure yet'],
          onChanged: (val) => _profile.familyPlans = val,
        ),
      ]),

      // 4. Work & Education
      _buildPageContent([
        _buildTextField(
          label: languageProvider.getString('occupation_label'),
          initialValue: _profile.occupation,
          onChanged: (val) => _profile.occupation = val,
        ),
        _buildTextField(
          label: languageProvider.getString('industry_label'),
          initialValue: _profile.industry,
          onChanged: (val) => _profile.industry = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('education_level_label'),
          value: _profile.educationLevel,
          items: const [
            'High School',
            'In College',
            'Undergraduate',
            'Postgraduate',
            'Other'
          ],
          onChanged: (val) => _profile.educationLevel = val,
        ),
        _buildTextField(
          label: languageProvider.getString('school_label'),
          initialValue: _profile.school,
          onChanged: (val) => _profile.school = val,
        ),
      ]),
      // 5. Lifestyle and Habits
      _buildPageContent([
        _buildChoiceChips(
          label: languageProvider.getString('smoking_label'),
          value: _profile.smoking,
          items: const ['Yes', 'No', 'Occasionally'],
          onChanged: (val) => _profile.smoking = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('drinking_label'),
          value: _profile.drinking,
          items: const ['Yes', 'No', 'Socially'],
          onChanged: (val) => _profile.drinking = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('fitness_label'),
          value: _profile.fitness,
          items: const ['Active', 'Moderate', 'Occasional', 'Couch Potato'],
          onChanged: (val) => _profile.fitness = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('diet_label'),
          value: _profile.diet,
          items: const [
            'Eat anything',
            'Vegetarian',
            'Vegan',
            'Halal',
            'Kosher',
            'Other'
          ],
          onChanged: (val) => _profile.diet = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('sleeping_habits_label'),
          value: _profile.sleepingHabits,
          items: const ['Early Bird', 'Night Owl', 'Flexible'],
          onChanged: (val) => _profile.sleepingHabits = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('pets_label'),
          value: _profile.pets,
          items: const ['Dog person', 'Cat person', 'Both', 'No pets', 'Other'],
          onChanged: (val) => _profile.pets = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('zodiac_label'),
          value: _profile.zodiac,
          items: const [
            'Aries',
            'Taurus',
            'Gemini',
            'Cancer',
            'Leo',
            'Virgo',
            'Libra',
            'Scorpio',
            'Sagittarius',
            'Capricorn',
            'Aquarius',
            'Pisces'
          ],
          onChanged: (val) => _profile.zodiac = val,
        ),
      ]),
      // 6. Interests & Hobbies
      _buildPageContent([
        _buildMultiChoiceChips(
          label: languageProvider.getString('hobbies_label'),
          values: _profile.hobbies,
          items: const [
            'Sports',
            'Music',
            'Travel',
            'Gaming',
            'Reading',
            'Cooking',
            'Art',
            'Photography',
            'Hiking',
            'Movies',
            'Dancing',
            'Writing',
            'Gardening',
            'Yoga',
            'Gym',
            'Swimming',
            'Shopping',
            'Coffee',
            'Foodie',
            'Fashion',
            'Animals',
            'Outdoors',
            'Cycling',
            'Fishing',
            'Camping',
            'Board Games'
          ],
          onChanged: (val) => _profile.hobbies = val,
        ),
        _buildTextField(
          label: languageProvider.getString('music_genres_label'),
          initialValue: _profile.musicGenres.join(', '),
          hint: 'Pop, Rock, R&B...',
          onChanged: (val) => _profile.musicGenres = val
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        ),
        _buildTextField(
          label: languageProvider.getString('movies_shows_label'),
          initialValue: _profile.moviesShows.join(', '),
          onChanged: (val) => _profile.moviesShows = val
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        ),
        _buildTextField(
          label: languageProvider.getString('weekend_activities_label'),
          initialValue: _profile.weekendActivities.join(', '),
          onChanged: (val) => _profile.weekendActivities = val
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        ),
      ]),
      // 7. Personality & Values
      _buildPageContent([
        _buildChoiceChips(
          label: languageProvider.getString('introvert_extrovert_label'),
          value: _profile.introvertExtrovert,
          items: const ['Introvert', 'Extrovert', 'Ambivert'],
          onChanged: (val) => _profile.introvertExtrovert = val,
        ),
        _buildChoiceChips(
          label: languageProvider.getString('love_language_label'),
          value: _profile.loveLanguage,
          items: const [
            'Words of Affirmation',
            'Acts of Service',
            'Receiving Gifts',
            'Quality Time',
            'Physical Touch'
          ],
          onChanged: (val) => _profile.loveLanguage = val,
        ),
        _buildTextField(
          label: languageProvider.getString('personality_type_label'),
          initialValue: _profile.mbti,
          onChanged: (val) => _profile.mbti = val,
        ),
        _buildTextField(
          label: languageProvider.getString('political_views_label'),
          initialValue: _profile.politicalViews,
          onChanged: (val) => _profile.politicalViews = val,
        ),
        _buildTextField(
          label: languageProvider.getString('core_values_label'),
          initialValue: _profile.coreValues,
          hint: 'Family, Ambition, Honesty...',
          onChanged: (val) => _profile.coreValues = val,
        ),
        _buildChoiceChips(
          label: 'Communication Style',
          value: _profile.communicationStyle,
          items: const ['Big text in person', 'Phone caller', 'Video chatter', 'Bad texter', 'Better in person'],
          onChanged: (val) => _profile.communicationStyle = val,
        ),
        _buildChoiceChips(
          label: 'Love Style',
          value: _profile.loveStyle,
          items: const ['Thoughtful gestures', 'Presents', 'Touch', 'Deep talks', 'Time together'],
          onChanged: (val) => _profile.loveStyle = val,
        ),
      ]),
      // 8. Media & Verification
      _buildPageContent([
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.getString('add_photos_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                languageProvider.getString('upload_photos_sub'),
                style:
                    const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (_isUploading)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageProvider.getString('uploading_photos'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    Text(
                      '${(_uploadProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: _primaryColor.withValues(alpha: 	0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        _buildPhotoGrid(),
      ]),
      // 9. Location
      _buildLocationCategory(languageProvider),
      // 10. Prompts
      _buildPageContent([
        _buildTextField(
          label: languageProvider.getString('perfect_date_prompt'),
          initialValue: _profile.promptPerfectDate,
          onChanged: (val) => _profile.promptPerfectDate = val,
          maxLines: 2,
        ),
        _buildTextField(
          label: languageProvider.getString('fall_for_you_prompt'),
          initialValue: _profile.promptFallForYou,
          onChanged: (val) => _profile.promptFallForYou = val,
          maxLines: 2,
        ),
        _buildTextField(
          label: languageProvider.getString('green_flag_prompt'),
          initialValue: _profile.promptGreenFlag,
          onChanged: (val) => _profile.promptGreenFlag = val,
          maxLines: 2,
        ),
        _buildTextField(
          label: languageProvider.getString('two_truths_prompt'),
          initialValue: _profile.promptTwoTruths,
          onChanged: (val) => _profile.promptTwoTruths = val,
          maxLines: 2,
        ),
      ]),
    ];
  }

  Widget _buildLocationCategory(LanguageProvider languageProvider) {
    bool hasLocation = _profile.latitude != null && _profile.longitude != null;
    return _buildPageContent([
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageProvider.getString('location_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              languageProvider.getString('location_sub'),
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      _buildTextField(
        label: languageProvider.getString('city_neighborhood_label'),
        initialValue: _profile.location,
        onChanged: (val) => _profile.location = val,
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasLocation
                ? Colors.green.withValues(alpha: 	0.3)
                : Theme.of(context).dividerColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 	0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (hasLocation ? Colors.green : _primaryColor)
                    .withValues(alpha: 	0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasLocation ? Iconsax.location_tick : Iconsax.location,
                color: hasLocation ? Colors.green : _primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasLocation ? languageProvider.getString('location_synced') : languageProvider.getString('location_not_set'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (hasLocation)
              Text(
                'Lat: ${_profile.latitude!.toStringAsFixed(4)}, Long: ${_profile.longitude!.toStringAsFixed(4)}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text(
                languageProvider.getString('location_sub'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _getCurrentLocation(languageProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasLocation ? Colors.green : _primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.radar, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    hasLocation ? languageProvider.getString('update_location_button') : languageProvider.getString('sync_location_now_button'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
    ]);
  }

  Future<void> _getCurrentLocation(LanguageProvider languageProvider) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showPremiumSnack(languageProvider.getString('location_services_disabled'),
          isError: true);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPremiumSnack(languageProvider.getString('location_permission_denied'), isError: true);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPremiumSnack(languageProvider.getString('location_permission_denied_forever'),
          isError: true);
      return;
    }

    _showPremiumSnack(languageProvider.getString('fetching_coordinates'));

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _profile.latitude = position.latitude;
        _profile.longitude = position.longitude;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _profileService.saveUserProfile(user.uid, _profile);
      }

      _showPremiumSnack(languageProvider.getString('location_updated_snack'), isSuccess: true);
    } catch (e) {
      _showPremiumSnack('${languageProvider.getString('error_fetching_location')}: $e', isError: true);
    }
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        final bool hasPhoto = _profile.photos.length > index;
        final bool isRequired = index < 4;

        return GestureDetector(
          onTap: hasPhoto ? null : _pickAndUploadImages,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasPhoto
                    ? _primaryColor.withValues(alpha: 	0.5)
                    : isRequired
                        ? Colors.orange.withValues(alpha: 	0.5)
                        : Theme.of(context).dividerColor,
                width: 2,
                style: hasPhoto ? BorderStyle.solid : BorderStyle.none,
              ),
            ),
            child: Stack(
              children: [
                if (hasPhoto)
                  Positioned.fill(
                    child: Image.network(
                      _profile.photos[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF4D85),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(
                              Iconsax.image,
                              color: Colors.grey,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (!hasPhoto)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.add_square,
                          color: isRequired
                              ? Colors.orange.withValues(alpha: 	0.5)
                              : Colors.grey.withValues(alpha: 	0.3),
                          size: 32,
                        ),
                        if (isRequired)
                          const Text(
                            'Required',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                if (hasPhoto)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        setState(() {
                          _profile.photos.removeAt(index);
                        });
                        // Auto-save to Firestore
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await _profileService.saveUserProfile(
                              user.uid, _profile);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Iconsax.close_circle,
                            color: _primaryColor, size: 16),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 	0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImages() async {
    // Prevent app lock when picking images
    try {
      LandingScreen.ignoreNextLock = true;
    } catch (_) {}
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    int remainingSlots = 8 - _profile.photos.length;
    if (remainingSlots <= 0) {
      _showPremiumSnack('You can only have up to 8 photos.', isError: true);
      return;
    }

    final List<XFile> toUpload = images.take(remainingSlots).toList();

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    _showPremiumSnack('Starting upload of ${toUpload.length} photos...');

    int successCount = 0;
    int completed = 0;
    for (var image in toUpload) {
      try {
        var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
        request.files
            .add(await http.MultipartFile.fromPath('image', image.path));

        var response = await request.send();
        if (response.statusCode == 200) {
          var responseData = await response.stream.bytesToString();
          debugPrint('Server Response: $responseData');
          var jsonResponse = json.decode(responseData);

          if (jsonResponse['status'] == 'success') {
            String imageUrl = jsonResponse['url'];
            debugPrint('Image uploaded: $imageUrl');
            setState(() {
              _profile.photos.add(imageUrl);
            });
            successCount++;
          } else {
            _showPremiumSnack(
                'Server Error: ${jsonResponse['message'] ?? 'Unknown error'}',
                isError: true);
          }
        } else {
          _showPremiumSnack('HTTP Error: ${response.statusCode}',
              isError: true);
        }
      } catch (e) {
        debugPrint('Upload error: $e');
        _showPremiumSnack('Connection Error: $e', isError: true);
      } finally {
        completed++;
        setState(() {
          _uploadProgress = completed / toUpload.length;
        });
      }
    }

    setState(() {
      _isUploading = false;
    });

    if (successCount > 0) {
      // Auto-save many to Firestore after successful batch
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await _profileService.saveUserProfile(user.uid, _profile);
        } catch (e) {
          debugPrint('Firestore save error: $e');
        }
      }

      if (successCount == toUpload.length) {
        _showPremiumSnack('All photos uploaded and saved!', isSuccess: true);
      } else {
        _showPremiumSnack(
            'Uploaded $successCount of ${toUpload.length} photos and saved profile.',
            isSuccess: true);
      }
    } else if (toUpload.isNotEmpty) {
      _showPremiumSnack('Upload failed. Check your server logs.',
          isError: true);
    }
  }

  void _showPremiumSnack(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Iconsax.info_circle
                  : (isSuccess ? Iconsax.tick_circle : Iconsax.cloud_plus),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? Colors.red.shade400
            : (isSuccess ? Colors.green.shade400 : _primaryColor),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        duration: const Duration(seconds: 3),
        elevation: 10,
      ),
    );
  }

  Widget _buildPageContent(List<Widget> children) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
          left: 28,
          right: 28,
          top: 20,
          bottom: 100), // Increased horizontal padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String? initialValue,
    String? hint,
    int maxLines = 1,
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: initialValue,
            maxLines: maxLines,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint ?? 'Tap to enter...',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontWeight: FontWeight.normal),
              alignLabelWithHint: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: _primaryColor.withValues(alpha: 	0.6), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 	0.5),
                    width: 1.5),
              ),
            ),
            onChanged: (val) {
              onChanged(val);
              _onFieldUpdated();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChips({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: items.map((item) {
              final isSelected = value == item;
              return ChoiceChip(
                label: Text(item),
                selected: isSelected,
                selectedColor: _primaryColor,
                backgroundColor: Theme.of(context).cardColor,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 	0.7),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? _primaryColor
                        : Theme.of(context).dividerColor,
                    width: isSelected ? 0 : 1.5,
                  ),
                ),
                showCheckmark: false,
                onSelected: (selected) {
                  if (selected) {
                    onChanged(item);
                    _onFieldUpdated();
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiChoiceChips({
    required String label,
    required List<String> values,
    required List<String> items,
    required Function(List<String>) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: items.map((item) {
              final isSelected = values.contains(item);
              return FilterChip(
                label: Text(item),
                selected: isSelected,
                selectedColor: _primaryColor,
                backgroundColor: Theme.of(context).cardColor,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 	0.7),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? _primaryColor
                        : Theme.of(context).dividerColor,
                    width: isSelected ? 0 : 1.5,
                  ),
                ),
                onSelected: (selected) {
                  final newValues = List<String>.from(values);
                  if (selected) {
                    newValues.add(item);
                  } else {
                    newValues.remove(item);
                  }
                  onChanged(newValues);
                  _onFieldUpdated();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch({
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        ),
        child: SwitchListTile(
          title: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          value: value,
          activeThumbColor: _primaryColor,
          activeTrackColor: _primaryColor.withValues(alpha: 	0.3),
          inactiveThumbColor: Theme.of(context).disabledColor,
          inactiveTrackColor: Theme.of(context).dividerColor,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            onChanged(val);
            _onFieldUpdated();
          },
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required Function(DateTime) onChanged,
  }) {
    final languageProvider = context.read<LanguageProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
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
                      colorScheme: Theme.of(context).colorScheme.brightness ==
                              Brightness.light
                          ? ColorScheme.light(primary: _primaryColor)
                          : ColorScheme.dark(
                              primary: _primaryColor,
                              surface: const Color(0xFF1F1F3D)),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                onChanged(date);
                _onFieldUpdated();
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Theme.of(context).dividerColor, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value != null
                        ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'
                        : languageProvider.getString('select_date'),
                    style: TextStyle(
                      color: value != null
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Theme.of(context).hintColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Icon(Iconsax.calendar_1,
                      color:
                          Theme.of(context).iconTheme.color?.withValues(alpha: 	0.5),
                      size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

