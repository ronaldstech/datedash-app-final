import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/profile_provider.dart';
import 'premium_screen.dart';

class SwipeFiltersScreen extends StatefulWidget {
  const SwipeFiltersScreen({super.key});

  @override
  State<SwipeFiltersScreen> createState() => _SwipeFiltersScreenState();
}

class _SwipeFiltersScreenState extends State<SwipeFiltersScreen> {
  late int _minAge;
  late int _maxAge;
  late double _maxDistance;
  late String _gender;
  late bool _ageStrict;
  late bool _distanceStrict;
  
  // Advanced Discovery Filters
  late String _relationshipStatus;
  late String _religion;
  late String _smoking;
  late String _drinking;
  late String _zodiac;
  late String _educationLevel;
  late bool _verifiedOnly;
  late String _kids;
  late String _pets;
  late String _introvertExtrovert;
  late String _lookingFor;
  late int _maxPhotos;
  late bool _hasBio;
  late String _familyPlans;
  late String _communicationStyle;
  late String _loveStyle;

  bool _isSaving = false;

  final List<String> _genderOptions = ['Men', 'Women', 'Everyone'];
  
  // Custom Filter options lists
  final List<String> _lookingForOptions = [
    'Any',
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
  ];
  
  final List<String> _familyPlansOptions = ['Any', 'Want some day', 'Don\'t want', 'Have and want more', 'Have and don\'t want more', 'Not sure yet'];
  final List<String> _communicationStyleOptions = ['Any', 'Big text in person', 'Phone caller', 'Video chatter', 'Bad texter', 'Better in person'];
  final List<String> _loveStyleOptions = ['Any', 'Thoughtful gestures', 'Presents', 'Touch', 'Deep talks', 'Time together'];
  
  // Custom Filter options lists
  final List<String> _relationshipStatusOptions = [
    'Any', 
    'Single', 
    'In a relationship', 
    'Engaged', 
    'Married', 
    'Divorced', 
    'Widowed', 
    'It\'s complicated'
  ];
  final List<String> _religionOptions = [
    'Any', 
    'Christian', 
    'Muslim', 
    'Hindu', 
    'Buddhist', 
    'Atheist', 
    'Spiritual', 
    'Other'
  ];
  final List<String> _habitOptions = ['Any', 'No', 'Yes', 'Socially'];
  final List<String> _zodiacOptions = [
    'Any', 
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
  ];
  final List<String> _educationOptions = [
    'Any', 
    'High School', 
    'College', 
    'University', 
    'Post Graduate'
  ];
  final List<String> _kidsOptions = ['Any', 'Yes', 'No', 'Maybe', 'Already have'];
  final List<String> _petsOptions = ['Any', 'Dog person', 'Cat person', 'Both', 'No pets', 'Other'];
  final List<String> _introvertExtrovertOptions = ['Any', 'Introvert', 'Extrovert', 'Ambivert'];

  final Color _primaryColor = const Color(0xFFFF4D85);
  final Color _secondaryColor = const Color(0xFF4FC3F7);

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().userProfile;
    
    _minAge = profile?.filterMinAge ?? 18;
    _maxAge = (profile?.filterMaxAge ?? 60) < _minAge ? _minAge : (profile?.filterMaxAge ?? 60);
    _maxDistance = profile?.filterMaxDistance ?? 50.0;

    _gender = profile?.filterGender ?? 'Everyone';
    if ((profile?.filterGender == null || profile!.filterGender!.isEmpty) &&
        profile?.gender != null) {
      if (profile!.gender == 'Male') _gender = 'Women';
      if (profile.gender == 'Female') _gender = 'Men';
    }

    _ageStrict = profile?.filterAgeStrict ?? false;
    _distanceStrict = profile?.filterDistanceStrict ?? false;
    
    if (!_genderOptions.contains(_gender)) {
      _gender = 'Everyone';
    }

    // Initialize advanced filters
    _relationshipStatus = profile?.filterRelationshipStatus ?? 'Any';
    _religion = profile?.filterReligion ?? 'Any';
    _smoking = profile?.filterSmoking ?? 'Any';
    _drinking = profile?.filterDrinking ?? 'Any';
    _zodiac = profile?.filterZodiac ?? 'Any';
    _educationLevel = profile?.filterEducationLevel ?? 'Any';
    _verifiedOnly = profile?.filterVerifiedOnly ?? false;
    _kids = profile?.filterKids ?? 'Any';
    _pets = profile?.filterPets ?? 'Any';
    _introvertExtrovert = profile?.filterIntrovertExtrovert ?? 'Any';
    _lookingFor = profile?.filterLookingFor ?? 'Any';
    _maxPhotos = profile?.filterMaxPhotos ?? 9;
    _hasBio = profile?.filterHasBio ?? false;
    _familyPlans = profile?.filterFamilyPlans ?? 'Any';
    _communicationStyle = profile?.filterCommunicationStyle ?? 'Any';
    _loveStyle = profile?.filterLoveStyle ?? 'Any';
  }

  Future<void> _saveFilters() async {
    setState(() => _isSaving = true);
    try {
      await context.read<ProfileProvider>().updateFilters(
            _minAge,
            _maxAge,
            _maxDistance,
            _gender,
            _ageStrict,
            _distanceStrict,
            filterRelationshipStatus: _relationshipStatus,
            filterReligion: _religion,
            filterSmoking: _smoking,
            filterDrinking: _drinking,
            filterZodiac: _zodiac,
            filterEducationLevel: _educationLevel,
            filterVerifiedOnly: _verifiedOnly,
            filterKids: _kids,
            filterPets: _pets,
            filterIntrovertExtrovert: _introvertExtrovert,
            filterLookingFor: _lookingFor,
            filterMaxPhotos: _maxPhotos,
            filterHasBio: _hasBio,
            filterFamilyPlans: _familyPlans,
            filterCommunicationStyle: _communicationStyle,
            filterLoveStyle: _loveStyle,
          );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving filters: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildGroupCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 	0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 	0.08) : Colors.black.withValues(alpha: 	0.04),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  void _showPremiumUpgradePrompt() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 	0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.crown,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Premium Feature',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Advanced filters are exclusive to premium members. Upgrade your plan to get unlimited access and unlock advanced filters!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Maybe Later',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(this.context);
                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                              builder: (context) => const PremiumScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D85),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Upgrade',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
    bool isPremiumLocked = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: isPremiumLocked ? _showPremiumUpgradePrompt : null,
      behavior: HitTestBehavior.opaque,
      child: AbsorbPointer(
        absorbing: isPremiumLocked,
        child: Opacity(
          opacity: isPremiumLocked ? 0.6 : 1.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        if (isPremiumLocked) ...[
                          const SizedBox(width: 8),
                          const Icon(Iconsax.crown, color: Colors.amber, size: 14),
                        ],
                      ],
                    ),
                    if (!value || isPremiumLocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 32,
                child: Transform.scale(
                  scale: 0.85,
                  child: Switch.adaptive(
                    value: isPremiumLocked ? false : value,
                    activeThumbColor: isPremiumLocked ? Colors.amber : activeColor,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownCard({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    required Color color,
    bool isPremiumLocked = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: isPremiumLocked ? _showPremiumUpgradePrompt : null,
      behavior: HitTestBehavior.opaque,
      child: AbsorbPointer(
        absorbing: isPremiumLocked,
        child: Opacity(
          opacity: isPremiumLocked ? 0.6 : 1.0,
          child: _buildGroupCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: isPremiumLocked ? Colors.amber : color),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (isPremiumLocked) ...[
                      const SizedBox(width: 8),
                      const Icon(Iconsax.crown, color: Colors.amber, size: 14),
                    ],
                  ],
                ),
                DropdownButton<String>(
                  value: value,
                  dropdownColor: Theme.of(context).cardColor,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w700, 
                    color: isDark ? Colors.white : Colors.black87
                  ),
                  onChanged: (val) {
                    if (val != null) onChanged(val);
                  },
                  items: items.map<DropdownMenuItem<String>>((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _primaryColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileProvider = context.watch<ProfileProvider>();
    final isPremium = profileProvider.userProfile?.isPremium ?? false;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull Tab
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discovery Filters',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? Colors.white12 : Colors.black.withValues(alpha: 	0.04),
                        minimumSize: const Size(32, 32),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),

              // Scrollable Filter Sections
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Basic discovery filters
                      _buildSectionHeader('Basic Demographics'),
                      
                      // Show me Gender card
                      _buildGroupCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Iconsax.profile_2user, size: 18, color: _primaryColor),
                                const SizedBox(width: 8),
                                const Text(
                                  'Show me',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 	0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: _genderOptions.map((option) {
                                  final isSelected = _gender == option;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _gender = option);
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          color: isSelected ? _primaryColor : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          option,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Looking For card
                      _buildDropdownCard(
                        icon: Iconsax.search_status,
                        title: 'Looking For',
                        value: _lookingFor,
                        items: _lookingForOptions,
                        onChanged: (val) => setState(() => _lookingFor = val),
                        color: _primaryColor,
                      ),

                      // Age range card
                      _buildGroupCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Iconsax.calendar_1, size: 18, color: _primaryColor),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Age Range',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withValues(alpha: 	0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$_minAge - $_maxAge',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: _primaryColor,
                                inactiveTrackColor: _primaryColor.withValues(alpha: 	0.15),
                                thumbColor: Colors.white,
                                overlayColor: _primaryColor.withValues(alpha: 	0.1),
                                trackHeight: 4,
                                rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                              ),
                              child: RangeSlider(
                                values: RangeValues(_minAge.toDouble(), _maxAge.toDouble()),
                                min: 18,
                                max: 99,
                                onChanged: (RangeValues values) {
                                  setState(() {
                                    _minAge = values.start.round();
                                    _maxAge = values.end.round();
                                  });
                                },
                              ),
                            ),
                            Divider(color: isDark ? Colors.white12 : Colors.black12, height: 24),
                            _buildToggleRow(
                              title: 'Strict Age Match',
                              subtitle: "We'll slip in a few outliers if you run out.",
                              value: _ageStrict,
                              activeColor: _primaryColor,
                              onChanged: (val) => setState(() => _ageStrict = val),
                            ),
                          ],
                        ),
                      ),

                      // Distance card
                      _buildGroupCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Iconsax.location, size: 18, color: _secondaryColor),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Maximum Distance',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _secondaryColor.withValues(alpha: 	0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_maxDistance.round()} km',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _secondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: _secondaryColor,
                                inactiveTrackColor: _secondaryColor.withValues(alpha: 	0.15),
                                thumbColor: Colors.white,
                                overlayColor: _secondaryColor.withValues(alpha: 	0.1),
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                              ),
                              child: Slider(
                                value: _maxDistance,
                                min: 1,
                                max: 150,
                                onChanged: (value) {
                                  setState(() {
                                    _maxDistance = value;
                                  });
                                },
                              ),
                            ),
                            Divider(color: isDark ? Colors.white12 : Colors.black12, height: 24),
                            _buildToggleRow(
                              title: 'Strict Distance Match',
                              subtitle: "We'll suggest folks further away if you run out.",
                              value: _distanceStrict,
                              activeColor: _secondaryColor,
                              onChanged: (val) => setState(() => _distanceStrict = val),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 2. Advanced Premium filters
                      _buildSectionHeader('Premium Advanced Filters'),
                      
                      // Relationship Goal
                      _buildDropdownCard(
                        icon: Icons.favorite_rounded,
                        title: 'Relationship Status',
                        value: _relationshipStatus,
                        items: _relationshipStatusOptions,
                        onChanged: (val) => setState(() => _relationshipStatus = val),
                        color: Colors.redAccent,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Religion
                      _buildDropdownCard(
                        icon: Icons.menu_book_rounded,
                        title: 'Religion / Beliefs',
                        value: _religion,
                        items: _religionOptions,
                        onChanged: (val) => setState(() => _religion = val),
                        color: Colors.amber,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Smoking
                      _buildDropdownCard(
                        icon: Icons.smoking_rooms_rounded,
                        title: 'Smoking Habits',
                        value: _smoking,
                        items: _habitOptions,
                        onChanged: (val) => setState(() => _smoking = val),
                        color: Colors.orangeAccent,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Drinking
                      _buildDropdownCard(
                        icon: Icons.local_bar_rounded,
                        title: 'Drinking Habits',
                        value: _drinking,
                        items: _habitOptions,
                        onChanged: (val) => setState(() => _drinking = val),
                        color: Colors.purpleAccent,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Zodiac
                      _buildDropdownCard(
                        icon: Icons.star_rounded,
                        title: 'Zodiac Sign',
                        value: _zodiac,
                        items: _zodiacOptions,
                        onChanged: (val) => setState(() => _zodiac = val),
                        color: Colors.cyanAccent,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Education
                      _buildDropdownCard(
                        icon: Icons.school_rounded,
                        title: 'Education level',
                        value: _educationLevel,
                        items: _educationOptions,
                        onChanged: (val) => setState(() => _educationLevel = val),
                        color: Colors.lightGreenAccent,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Verified Only
                      _buildGroupCard(
                        child: _buildToggleRow(
                          title: 'Verified Profiles Only',
                          subtitle: 'Only show users who have verified their identity.',
                          value: _verifiedOnly,
                          activeColor: const Color(0xFFFF4D85),
                          onChanged: (val) => setState(() => _verifiedOnly = val),
                          isPremiumLocked: !isPremium,
                        ),
                      ),
                      
                      // Kids
                      _buildDropdownCard(
                        icon: Icons.child_care_rounded,
                        title: 'Kids / Children',
                        value: _kids,
                        items: _kidsOptions,
                        onChanged: (val) => setState(() => _kids = val),
                        color: Colors.pinkAccent,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Pets
                      _buildDropdownCard(
                        icon: Icons.pets_rounded,
                        title: 'Pets',
                        value: _pets,
                        items: _petsOptions,
                        onChanged: (val) => setState(() => _pets = val),
                        color: Colors.brown,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Introvert/Extrovert
                      _buildDropdownCard(
                        icon: Icons.psychology_rounded,
                        title: 'Personality Type',
                        value: _introvertExtrovert,
                        items: _introvertExtrovertOptions,
                        onChanged: (val) => setState(() => _introvertExtrovert = val),
                        color: Colors.tealAccent,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Max Photos
                      _buildGroupCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.photo_library_rounded, size: 18, color: Colors.blueAccent),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Max Photos Needed',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    if (!isPremium) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Iconsax.crown, color: Colors.amber, size: 14),
                                    ],
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(alpha: 	0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _maxPhotos >= 9 ? 'Any' : '$_maxPhotos photos',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AbsorbPointer(
                              absorbing: !isPremium,
                              child: Opacity(
                                opacity: !isPremium ? 0.6 : 1.0,
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: Colors.blueAccent,
                                    inactiveTrackColor: Colors.blueAccent.withValues(alpha: 	0.15),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.blueAccent.withValues(alpha: 	0.1),
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                                  ),
                                  child: Slider(
                                    value: _maxPhotos.toDouble(),
                                    min: 1,
                                    max: 9,
                                    divisions: 8,
                                    onChanged: (value) {
                                      setState(() {
                                        _maxPhotos = value.round();
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Has Bio
                      _buildGroupCard(
                        child: _buildToggleRow(
                          title: 'Must Have a Bio',
                          subtitle: 'Only show users who have written a bio.',
                          value: _hasBio,
                          activeColor: const Color(0xFFFF4D85),
                          onChanged: (val) => setState(() => _hasBio = val),
                          isPremiumLocked: !isPremium,
                        ),
                      ),
                      
                      // Family Plans
                      _buildDropdownCard(
                        icon: Icons.family_restroom_rounded,
                        title: 'Family Plans',
                        value: _familyPlans,
                        items: _familyPlansOptions,
                        onChanged: (val) => setState(() => _familyPlans = val),
                        color: Colors.indigoAccent,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Communication Style
                      _buildDropdownCard(
                        icon: Icons.chat_bubble_rounded,
                        title: 'Communication Style',
                        value: _communicationStyle,
                        items: _communicationStyleOptions,
                        onChanged: (val) => setState(() => _communicationStyle = val),
                        color: Colors.deepPurpleAccent,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      // Love Style
                      _buildDropdownCard(
                        icon: Icons.favorite_border_rounded,
                        title: 'Love Style',
                        value: _loveStyle,
                        items: _loveStyleOptions,
                        onChanged: (val) => setState(() => _loveStyle = val),
                        color: Colors.redAccent,
                        isPremiumLocked: !isPremium,
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),

              // Apply Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveFilters,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
