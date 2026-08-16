import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../services/video_chat_service.dart';
import 'video_matchmaking_screen.dart';
import 'premium_screen.dart';

class LiveListScreen extends StatefulWidget {
  const LiveListScreen({super.key});

  @override
  State<LiveListScreen> createState() => _LiveListScreenState();
}

class _LiveListScreenState extends State<LiveListScreen>
    with TickerProviderStateMixin {
  final VideoChatService _videoChatService = VideoChatService();

  // Filters State
  String _selectedLanguage = 'Any';
  String _selectedGender = 'Any';
  RangeValues _ageRange = const RangeValues(18, 45);
  String _selectedCountry = 'Any';

  bool _isMatching = false;
  bool _countryInitialized = false;
  StreamSubscription<DocumentSnapshot>? _ticketSubscription;

  // Animation controller for the radar scanning effect
  late AnimationController _radarController;

  final List<String> _languages = [
    'Any',
    'English',
    'Kiswahili',
    'Español',
    'Français',
    'Deutsch',
    'Português',
    'Hindi',
    'Japanese',
    'Italian',
    'Chinese',
    'Korean',
    'Arabic',
    'Russian',
  ];

  final List<String> _genders = ['Any', 'Male', 'Female'];

  final List<String> _countries = [
    'Any',
    'United States',
    'Kenya',
    'Tanzania',
    'United Kingdom',
    'Spain',
    'France',
    'Germany',
    'Brazil',
    'Canada',
    'Australia',
    'India',
    'Japan',
    'Italy',
    'Mexico',
    'South Africa',
    'Nigeria',
    'South Korea',
    'China',
  ];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  void _startMatchingFlow(ProfileProvider pp) async {
    final currentUser = pp.userProfile;
    if (currentUser == null || currentUser.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not loaded. Please try again.')),
      );
      return;
    }

    final bool isPremium = currentUser.isPremium;
    final bool isElite = currentUser.isElite;

    // Premium/Elite restriction: non-premium users locked on gender, non-elite users locked on country
    final String effectiveGender = isPremium ? _selectedGender : 'Any';
    final String effectiveCountry = isElite ? _selectedCountry : 'Any';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoMatchmakingScreen(
          currentUser: currentUser,
          filterLanguage: _selectedLanguage,
          filterGender: effectiveGender,
          filterMinAge: _ageRange.start.round(),
          filterMaxAge: _ageRange.end.round(),
          filterCountry: effectiveCountry,
        ),
      ),
    );
  }

  void _cancelMatchingFlow(ProfileProvider pp) async {
    final currentUserId = pp.userProfile?.uid;
    if (currentUserId != null) {
      await _videoChatService.cancelMatching(currentUserId);
    }
    _ticketSubscription?.cancel();
    _radarController.stop();
    if (mounted) {
      setState(() {
        _isMatching = false;
      });
    }
  }

  Future<void> _setDefaultCountryFromGeo(ProfileProvider pp) async {
    final String userLocation = pp.userProfile?.location ?? '';
    final String countryCode = pp.userProfile?.countryCode ?? '';

    final Map<String, String> countryMap = {
      'kenya': 'Kenya',
      'ke': 'Kenya',
      'tanzania': 'Tanzania',
      'tz': 'Tanzania',
      'united states': 'United States',
      'us': 'United States',
      'usa': 'United States',
      'united kingdom': 'United Kingdom',
      'uk': 'United Kingdom',
      'spain': 'Spain',
      'es': 'Spain',
      'france': 'France',
      'fr': 'France',
      'germany': 'Germany',
      'de': 'Germany',
      'brazil': 'Brazil',
      'br': 'Brazil',
      'canada': 'Canada',
      'ca': 'Canada',
      'australia': 'Australia',
      'au': 'Australia',
      'india': 'India',
      'in': 'India',
      'japan': 'Japan',
      'jp': 'Japan',
      'italy': 'Italy',
      'it': 'Italy',
      'mexico': 'Mexico',
      'mx': 'Mexico',
      'south africa': 'South Africa',
      'za': 'South Africa',
      'nigeria': 'Nigeria',
      'ng': 'Nigeria',
      'south korea': 'South Korea',
      'kr': 'South Korea',
      'china': 'China',
      'cn': 'China',
    };

    final locLower = userLocation.toLowerCase();
    final codeLower = countryCode.toLowerCase();

    for (var entry in countryMap.entries) {
      if (locLower.contains(entry.key) || codeLower == entry.key) {
        if (mounted) {
          setState(() {
            _selectedCountry = entry.value;
          });
        }
        return;
      }
    }

    // Fallback if countryCode exists directly as uppercase country name
    if (userLocation.isNotEmpty) {
      if (mounted) {
        setState(() {
          _selectedCountry = userLocation.split(',').last.trim();
        });
      }
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      String deducedCountry = 'Any';
      final lat = position.latitude;
      final lng = position.longitude;

      if (lat > -5 && lat < 5 && lng > 34 && lng < 42) {
        deducedCountry = 'Kenya';
      } else if (lat > -12 && lat < -1 && lng > 29 && lng < 41) {
        deducedCountry = 'Tanzania';
      } else if (lat > 24 && lat < 49 && lng > -125 && lng < -66) {
        deducedCountry = 'United States';
      } else if (lat > 36 && lat < 44 && lng > -9 && lng < 4) {
        deducedCountry = 'Spain';
      } else if (lat > 42 && lat < 51 && lng > -5 && lng < 9) {
        deducedCountry = 'France';
      } else if (lat > 47 && lat < 55 && lng > 5 && lng < 15) {
        deducedCountry = 'Germany';
      } else if (lat > 49 && lat < 61 && lng > -9 && lng < 2) {
        deducedCountry = 'United Kingdom';
      } else if (lat > -34 && lat < 6 && lng > -74 && lng < -34) {
        deducedCountry = 'Brazil';
      }

      if (deducedCountry != 'Any' && mounted) {
        setState(() {
          _selectedCountry = deducedCountry;
        });
      }
    } catch (_) {}
  }

  Widget _buildPremiumLockedOverlay(
    BuildContext context,
    String title, {
    String tier = 'Premium',
  }) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Iconsax.crown5,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$title Filter ($tier)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tap to unlock',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PremiumScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProfileProvider>();
    final lp = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if ((!_countryInitialized || (pp.userProfile?.isPremium == true && _selectedCountry == 'Any')) &&
        pp.userProfile != null) {
      _setDefaultCountryFromGeo(pp);
      _countryInitialized = true;
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D11)
          : const Color(0xFFF7F7F9),
      body: Stack(
        children: [
          // Background decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF4D85).withValues(alpha: 0.15),
              ),
            ),
          ),

          _isMatching
              ? _buildMatchingRadar(pp)
              : _buildFiltersForm(isDark, pp, lp),
        ],
      ),
    );
  }

  Widget _buildFiltersForm(
    bool isDark,
    ProfileProvider pp,
    LanguageProvider lp,
  ) {
    final bool isPremium = pp.userProfile?.isPremium == true;
    final bool isElite = pp.userProfile?.isElite == true;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inline header (scrolls with content)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              lp.getString('video_chat'),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ),
          _buildHeroPanel(pp),
          const SizedBox(height: 18),
          _buildQuickStats(isDark, isPremium),
          const SizedBox(height: 22),
          _buildFilterPanel(
            isDark: isDark,
            title: 'Match preferences',
            subtitle: 'These are used before the full-screen camera search.',
            children: [
              _buildFilterLabel('Partner Language', Iconsax.language_square),
              const SizedBox(height: 10),
              _buildLanguagePickerButton(context, isDark),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFilterLabel('Age Range', Iconsax.calendar),
                  _buildValuePill(
                    '${_ageRange.start.round()}-${_ageRange.end.round()}',
                    isDark,
                  ),
                ],
              ),
              RangeSlider(
                values: _ageRange,
                min: 18,
                max: 80,
                activeColor: const Color(0xFFFF4D85),
                inactiveColor: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.06),
                labels: RangeLabels(
                  _ageRange.start.round().toString(),
                  _ageRange.end.round().toString(),
                ),
                onChanged: (values) => setState(() => _ageRange = values),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFilterPanel(
            isDark: isDark,
            title: 'Premium & Elite filters',
            subtitle: isElite
                ? 'Tune gender and country for a more focused match.'
                : (isPremium
                    ? 'Gender filter unlocked. Country filter requires Elite.'
                    : 'Upgrade to control gender (Premium) and country (Elite) matching.'),
            children: [
              _buildFilterLabel('Desired Gender', Iconsax.user),
              const SizedBox(height: 10),
              Stack(
                children: [
                  Row(
                    children: _genders.map((gender) {
                      final isSelected = _selectedGender == gender;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: gender == _genders.last ? 0 : 8,
                          ),
                          child: _buildGenderCard(gender, isSelected, isDark),
                        ),
                      );
                    }).toList(),
                  ),
                  if (!isPremium) _buildPremiumLockedOverlay(context, 'Gender'),
                ],
              ),
              const SizedBox(height: 18),
              _buildFilterLabel('Partner Country', Iconsax.global),
              const SizedBox(height: 10),
              Stack(
                children: [
                  _buildCountryPickerButton(context, isDark),
                  if (!isElite)
                    _buildPremiumLockedOverlay(context, 'Country', tier: 'Elite'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildStartCard(isDark, pp, isPremium, isElite),
        ],
      ),
    );
  }

  Widget _buildHeroPanel(ProfileProvider pp) {
    final photo = pp.photoURL ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4D85), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D85).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Iconsax.video_tick,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify First Love For Real',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Don't act just be you for 60 seconds.",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? const Icon(Iconsax.user, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _heroChip(Iconsax.language_square, _selectedLanguage),
                    _heroChip(
                      Iconsax.calendar,
                      '${_ageRange.start.round()}-${_ageRange.end.round()}',
                    ),
                    _heroChip(Iconsax.global, _selectedCountry),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isDark, bool isPremium) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<int>(
            stream: _videoChatService.getActiveVideoUsersCountStream(),
            builder: (context, snapshot) {
              return _buildStatTile(
                isDark,
                Iconsax.people,
                '${snapshot.data ?? 0}',
                'chatting now',
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            isDark,
            isPremium ? Iconsax.crown5 : Iconsax.lock,
            isPremium ? 'Premium' : 'Basic',
            isPremium ? 'filters on' : 'filters limited',
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(
    bool isDark,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF4D85), size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel({
    required bool isDark,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStartCard(
    bool isDark,
    ProfileProvider pp,
    bool isPremium,
    bool isElite,
  ) {
    final String infoText = isElite
        ? 'Your selected filters will be applied.'
        : (isPremium
            ? 'Gender filter active. Country set to Any (Elite feature).'
            : 'Gender and country are set to Any on Basic.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFFFF3F7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF4D85).withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Iconsax.shield_tick, color: Color(0xFFFF4D85)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  infoText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _startMatchingFlow(pp),
              icon: const Icon(Iconsax.video_play),
              label: const Text(
                'Start Matching',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D85),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValuePill(String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D85).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFFFF4D85),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildFilterLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFFF4D85)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildGenderCard(String gender, bool isSelected, bool isDark) {
    IconData iconData;
    switch (gender) {
      case 'Male':
        iconData = Iconsax.man;
        break;
      case 'Female':
        iconData = Iconsax.woman;
        break;
      default:
        iconData = Iconsax.people;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF4D85).withValues(alpha: 0.1)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF4D85)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08)),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              size: 24,
              color: isSelected
                  ? const Color(0xFFFF4D85)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              gender,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFFF4D85)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLanguageFlag(String language) {
    switch (language) {
      case 'English':
        return '🇬🇧';
      case 'Kiswahili':
        return '🇹🇿';
      case 'Español':
        return '🇪🇸';
      case 'Français':
        return '🇫🇷';
      case 'Deutsch':
        return '🇩🇪';
      case 'Português':
        return '🇵🇹';
      case 'Hindi':
        return '🇮🇳';
      case 'Japanese':
        return '🇯🇵';
      case 'Italian':
        return '🇮🇹';
      case 'Chinese':
        return '🇨🇳';
      case 'Korean':
        return '🇰🇷';
      case 'Arabic':
        return '🇸🇦';
      case 'Russian':
        return '🇷🇺';
      default:
        return '🌐';
    }
  }

  Widget _buildLanguagePickerButton(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () => _showLanguageSelectorBottomSheet(context, isDark),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              _getLanguageFlag(_selectedLanguage),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedLanguage,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Iconsax.arrow_down_1, size: 18),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelectorBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredLanguages = _languages
                .where(
                  (l) => l.toLowerCase().contains(searchQuery.toLowerCase()),
                )
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141A) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Partner Language',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search language...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = filteredLanguages[index];
                        final isSelected = lang == _selectedLanguage;

                        return ListTile(
                          leading: Text(
                            _getLanguageFlag(lang),
                            style: const TextStyle(fontSize: 22),
                          ),
                          title: Text(
                            lang,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFFFF4D85)
                                  : null,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFFF4D85),
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedLanguage = lang;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getCountryFlag(String country) {
    switch (country) {
      case 'United States':
        return '🇺🇸';
      case 'Kenya':
        return '🇰🇪';
      case 'Tanzania':
        return '🇹🇿';
      case 'United Kingdom':
        return '🇬🇧';
      case 'Spain':
        return '🇪🇸';
      case 'France':
        return '🇫🇷';
      case 'Germany':
        return '🇩🇪';
      case 'Brazil':
        return '🇧🇷';
      case 'Canada':
        return '🇨🇦';
      case 'Australia':
        return '🇦🇺';
      case 'India':
        return '🇮🇳';
      case 'Japan':
        return '🇯🇵';
      case 'Italy':
        return '🇮🇹';
      case 'Mexico':
        return '🇲🇽';
      case 'South Africa':
        return '🇿🇦';
      case 'Nigeria':
        return '🇳🇬';
      case 'South Korea':
        return '🇰🇷';
      case 'China':
        return '🇨🇳';
      default:
        return '🌐';
    }
  }

  Widget _buildCountryPickerButton(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () => _showCountrySelectorBottomSheet(context, isDark),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              _getCountryFlag(_selectedCountry),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCountry,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Iconsax.arrow_down_1, size: 18),
          ],
        ),
      ),
    );
  }

  void _showCountrySelectorBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCountries = _countries
                .where(
                  (c) => c.toLowerCase().contains(searchQuery.toLowerCase()),
                )
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141A) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Partner Country',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search country...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: const Icon(Iconsax.search_normal, size: 18),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredCountries.length,
                      itemBuilder: (context, index) {
                        final country = filteredCountries[index];
                        final isSelected = _selectedCountry == country;
                        return ListTile(
                          leading: Text(
                            _getCountryFlag(country),
                            style: const TextStyle(fontSize: 22),
                          ),
                          title: Text(
                            country,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFFFF4D85)
                                  : null,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Iconsax.tick_circle,
                                  color: Color(0xFFFF4D85),
                                  size: 20,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedCountry = country;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMatchingRadar(ProfileProvider pp) {
    final photo = pp.photoURL ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glowing aura
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF4D85).withValues(alpha: 0.05),
                ),
              ),
              // Animated Radar Circles
              AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: List.generate(3, (index) {
                      final double delay = index * 0.33;
                      final double progress =
                          (_radarController.value + delay) % 1.0;
                      return Container(
                        width: 100 + (progress * 200),
                        height: 100 + (progress * 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFFFF4D85,
                          ).withValues(alpha: (1.0 - progress) * 0.15),
                          border: Border.all(
                            color: const Color(
                              0xFFFF4D85,
                            ).withValues(alpha: (1.0 - progress) * 0.4),
                            width: 1.5,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              // User Avatar with glowing ring
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D85).withValues(alpha: 0.5),
                      blurRadius: 25,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: photo.isNotEmpty
                      ? Image.network(photo, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFFFF4D85),
                          child: const Icon(
                            Iconsax.user,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          const Text(
            'Finding your Match...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          // Beautiful layout for search criteria tags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildCriteriaTag(
                  'Gender: $_selectedGender',
                  Iconsax.user,
                  isDark,
                ),
                _buildCriteriaTag(
                  'Lang: $_selectedLanguage',
                  Iconsax.language_square,
                  isDark,
                ),
                _buildCriteriaTag(
                  'Age: ${_ageRange.start.round()}-${_ageRange.end.round()}',
                  Iconsax.calendar,
                  isDark,
                ),
                _buildCriteriaTag(
                  'Country: $_selectedCountry',
                  Iconsax.global,
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 64),
          OutlinedButton.icon(
            onPressed: () => _cancelMatchingFlow(pp),
            icon: const Icon(Iconsax.close_circle, size: 18),
            label: const Text(
              'Cancel Search',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF4D85),
              side: const BorderSide(color: Color(0xFFFF4D85), width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaTag(String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFF4D85)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
