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
import 'video_call_screen.dart';
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

    setState(() {
      _isMatching = true;
    });
    _radarController.repeat();

    final currentUserId = currentUser.uid!;
    final bool isPremium = currentUser.isPremium;

    // Premium restriction: non-premium users are locked to 'Any'
    final String effectiveGender = isPremium ? _selectedGender : 'Any';
    final String effectiveCountry = isPremium ? _selectedCountry : 'Any';

    try {
      // 1. Try to match immediately
      final matchResult = await _videoChatService.startMatching(
        currentUser: currentUser,
        filterLanguage: _selectedLanguage,
        filterGender: effectiveGender,
        filterMinAge: _ageRange.start.round(),
        filterMaxAge: _ageRange.end.round(),
        filterCountry: effectiveCountry,
      );

      if (!mounted) return;

      if (matchResult != null) {
        // Direct match found!
        _radarController.stop();
        setState(() {
          _isMatching = false;
        });

        _navigateToCall(
          channelId: matchResult['channelId'],
          partnerId: matchResult['matchedWith'],
          partnerName: matchResult['partnerName'],
          partnerPhoto: matchResult['partnerPhoto'],
          isHost: true,
        );
      } else {
        // No immediate match. Start listening to current user's ticket updates
        _ticketSubscription?.cancel();
        _ticketSubscription = _videoChatService
            .getTicketStream(currentUserId)
            .listen((snapshot) {
              if (!snapshot.exists || !mounted) return;

              final data = snapshot.data() as Map<String, dynamic>?;
              if (data == null) return;

              final status = data['status'] as String?;
              if (status == 'matched') {
                _ticketSubscription?.cancel();
                _radarController.stop();
                setState(() {
                  _isMatching = false;
                });

                final String? channelId = data['channelId'];
                final String? partnerId = data['matchedWith'];

                if (channelId == null || partnerId == null) return;

                // Fetch partner details from ticket or Firestore
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(partnerId)
                    .get()
                    .then((userDoc) {
                      if (!mounted) return;
                      String partnerName = 'User';
                      String partnerPhoto = '';
                      if (userDoc.exists) {
                        partnerName = userDoc.data()?['firstName'] ?? 'User';
                        final photos = List<String>.from(
                          userDoc.data()?['photos'] ?? [],
                        );
                        if (photos.isNotEmpty) partnerPhoto = photos.first;
                      }

                      _navigateToCall(
                        channelId: channelId,
                        partnerId: partnerId,
                        partnerName: partnerName,
                        partnerPhoto: partnerPhoto,
                        isHost: false,
                      );
                    }).catchError((_) {
                      if (!mounted) return;
                      _navigateToCall(
                        channelId: channelId,
                        partnerId: partnerId,
                        partnerName: 'User',
                        partnerPhoto: '',
                        isHost: false,
                      );
                    });
              }
            });
      }
    } catch (e) {
      debugPrint('Error starting matching flow: $e');
      if (mounted) {
        _radarController.stop();
        setState(() {
          _isMatching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Matchmaking error: $e')),
        );
      }
    }
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

  void _navigateToCall({
    required String channelId,
    required String partnerId,
    required String partnerName,
    required String partnerPhoto,
    required bool isHost,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          channelId: channelId,
          partnerId: partnerId,
          partnerName: partnerName,
          partnerPhoto: partnerPhoto,
          isHost: isHost,
        ),
      ),
    );
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

  Widget _buildPremiumLockedOverlay(BuildContext context, String title) {
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
                              '$title Filter (Premium)',
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

    if (!_countryInitialized && pp.userProfile != null) {
      _setDefaultCountryFromGeo(pp);
      _countryInitialized = true;
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D11)
          : const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(
          lp.getString('video_chat'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4D85), Color(0xFFFF758F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4D85).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Iconsax.video_tick5, size: 48, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1-on-1 Video Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set your preferences and instantly match with someone online.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Partner Language
          _buildFilterLabel('Partner Language', Iconsax.language_square),
          const SizedBox(height: 12),
          _buildLanguagePickerButton(context, isDark),
          const SizedBox(height: 24),

          // Desired Gender
          _buildFilterLabel('Desired Gender', Iconsax.user),
          const SizedBox(height: 12),
          Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _genders.map((gender) {
                    final isSelected = _selectedGender == gender;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 80,
                        child: _buildGenderCard(gender, isSelected, isDark),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (pp.userProfile?.isPremium != true)
                _buildPremiumLockedOverlay(context, 'Gender'),
            ],
          ),
          const SizedBox(height: 24),

          // Age Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFilterLabel('Age Range', Iconsax.calendar),
              Text(
                '${_ageRange.start.round()} - ${_ageRange.end.round()}',
                style: const TextStyle(
                  color: Color(0xFFFF4D85),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
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
                : Colors.black.withValues(alpha: 0.05),
            labels: RangeLabels(
              _ageRange.start.round().toString(),
              _ageRange.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() => _ageRange = values);
            },
          ),
          const SizedBox(height: 24),

          // Partner Country
          _buildFilterLabel('Partner Country', Iconsax.global),
          const SizedBox(height: 12),
          Stack(
            children: [
              _buildCountryPickerButton(context, isDark),
              if (pp.userProfile?.isPremium != true)
                _buildPremiumLockedOverlay(context, 'Country'),
            ],
          ),
          const SizedBox(height: 48),

          // Start Match Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _startMatchingFlow(pp),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D85),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.video_play),
                  SizedBox(width: 8),
                  Text(
                    'Start Matching',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
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

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Iconsax.arrow_down_1, size: 18),
          dropdownColor: isDark ? const Color(0xFF14141A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
