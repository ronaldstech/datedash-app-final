import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class UserProfile {
  String? uid;
  // 🧾 Basic Profile (Required)
  String? firstName;
  DateTime? dob;
  String? gender;
  String? interestedIn;
  String? location;
  List<String> photos;
  String? bio;
  double? latitude;
  double? longitude;
  String? phoneNumber;
  String? countryCode;

  // ❤️ Personal Details
  String? height;
  String? bodyType;
  String? relationshipStatus;
  String? religion;
  List<String> languages;

  // 🎯 Lifestyle & Habits
  String? smoking;
  String? drinking;
  String? fitness;
  String? diet;
  String? sleepingHabits;
  String? pets;
  String? zodiac;

  // 💼 Work & Education
  String? occupation;
  String? industry;
  String? educationLevel;
  String? school;

  // 💕 Relationship Goals
  List<String> lookingFor;
  bool? openToLongDistance;
  String? wantKids;
  String? familyPlans;

  // 🎨 Interests & Hobbies
  List<String> hobbies;
  List<String> musicGenres;
  List<String> moviesShows;
  List<String> weekendActivities;

  // 🧠 Personality & Values
  String? introvertExtrovert;
  String? loveLanguage;
  String? communicationStyle;
  String? loveStyle;
  String? mbti;
  String? politicalViews;
  String? coreValues;

  // 📸 Media & Verification
  String? videoIntro;
  bool isVerified;
  bool isEmailVerified;
  bool isOnline;
  String? verificationStatus; // 'unverified', 'pending', 'verified'
  String? nationalId;
  String? nationalIdUrl;

  // 💬 Prompts
  String? promptPerfectDate;
  String? promptFallForYou;
  String? promptGreenFlag;
  String? promptTwoTruths;

  // 🔐 Privacy / Safety 
  bool showAge;
  bool showDistance;
  bool allowMessages;
  bool allowMeetupRequests;
  bool hideProfile;
  // 📅 Meetup Preferences (set by the user, shown to those who send requests)
  String? meetupLocation;
  String? meetupRate;
  String? meetupNotes;

  // 🎛️ Swiping Filters
  int? filterMinAge;
  int? filterMaxAge;
  double? filterMaxDistance;
  String? filterGender;
  bool filterAgeStrict;
  bool filterDistanceStrict;
  String? filterRelationshipStatus;
  String? filterReligion;
  String? filterSmoking;
  String? filterDrinking;
  String? filterZodiac;
  String? filterEducationLevel;
  bool filterVerifiedOnly;
  bool filterOnlineOnly;
  String? filterKids;
  String? filterPets;
  String? filterIntrovertExtrovert;
  String? filterLookingFor;
  int? filterMaxPhotos;
  bool filterHasBio;
  String? filterFamilyPlans;
  String? filterCommunicationStyle;
  String? filterLoveStyle;
  String? filterCountry;

  // 💰 Monetization
  bool isPremium;
  String? premiumType; // 'Pro', 'Premium', 'Elite'
  bool get isElite => isPremium && premiumType?.toUpperCase() == 'ELITE';
  DateTime? premiumExpiry;
  DateTime? boostExpiry;
  bool get isBoosted => boostExpiry != null && DateTime.now().isBefore(boostExpiry!);
  int sparks;
  int get credits => sparks;
  set credits(int v) => sparks = v;
  List<String> unlockedLikes;
  List<String> unlockedViewers;

  // 📈 Usage Tracking
  double dailyUsageDuration; // in seconds
  String? lastUsageResetDate; // YYYY-MM-DD
  String? lastDailyRewardDate; // YYYY-MM-DD
  int dailyMessageCount;
  String? lastMessageResetDate; // YYYY-MM-DD
  List<String> claimedRewards; // One-time reward IDs
  int lastSeenLikesCount;
  List<String> blockedUsers; // List of blocked user UIDs
  String? fcmToken;


  UserProfile({
    this.firstName,
    this.dob,
    this.gender,
    this.interestedIn,
    this.location,
    this.photos = const [],
    this.bio,
    this.height,
    this.bodyType,
    this.relationshipStatus,
    this.religion,
    this.languages = const [],
    this.smoking,
    this.drinking,
    this.fitness,
    this.diet,
    this.sleepingHabits,
    this.pets,
    this.zodiac,
    this.occupation,
    this.industry,
    this.educationLevel,
    this.school,
    this.lookingFor = const [],
    this.openToLongDistance,
    this.wantKids,
    this.familyPlans,
    this.hobbies = const [],
    this.musicGenres = const [],
    this.moviesShows = const [],
    this.weekendActivities = const [],
    this.introvertExtrovert,
    this.loveLanguage,
    this.communicationStyle,
    this.loveStyle,
    this.mbti,
    this.politicalViews,
    this.coreValues,
    this.videoIntro,
    this.isVerified = false,
    this.isEmailVerified = false,
    this.isOnline = false,
    this.verificationStatus = 'unverified',
    this.nationalId,
    this.nationalIdUrl,
    this.promptPerfectDate,
    this.promptFallForYou,
    this.promptGreenFlag,
    this.promptTwoTruths,
    this.showAge = true,
    this.showDistance = true,
    this.allowMessages = true,
    this.allowMeetupRequests = true,
    this.hideProfile = false,
    this.meetupLocation,
    this.meetupRate,
    this.meetupNotes,
    this.latitude,
    this.longitude,
    this.uid,
    this.phoneNumber,
    this.countryCode,
    this.filterMinAge = 18,
    this.filterMaxAge = 60,
    this.filterMaxDistance = 50.0,
    this.filterGender,
    this.filterAgeStrict = false,
    this.filterDistanceStrict = false,
    this.isPremium = false,
    this.premiumType,
    this.premiumExpiry,
    this.boostExpiry,
    this.sparks = 0,
    this.unlockedLikes = const [],
    this.unlockedViewers = const [],
    this.dailyUsageDuration = 0.0,
    this.lastUsageResetDate,
    this.lastDailyRewardDate,
    this.dailyMessageCount = 0,
    this.lastMessageResetDate,
    this.claimedRewards = const [],
    this.lastSeenLikesCount = 0,
    this.blockedUsers = const [],
    this.filterRelationshipStatus = 'Any',
    this.filterReligion = 'Any',
    this.filterSmoking = 'Any',
    this.filterDrinking = 'Any',
    this.filterZodiac = 'Any',
    this.filterEducationLevel = 'Any',
    this.filterVerifiedOnly = false,
    this.filterOnlineOnly = false,
    this.filterKids = 'Any',
    this.filterPets = 'Any',
    this.filterIntrovertExtrovert = 'Any',
    this.filterLookingFor = 'Any',
    this.filterMaxPhotos = 9,
    this.filterHasBio = false,
    this.filterFamilyPlans = 'Any',
    this.filterCommunicationStyle = 'Any',
    this.filterLoveStyle = 'Any',
    this.filterCountry = 'Any',
    this.fcmToken,
  });

  int? get age {
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob!.year;
    if (now.month < dob!.month || (now.month == dob!.month && now.day < dob!.day)) {
      age--;
    }
    return age;
  }

  /// Returns a human-readable distance between this profile and the current user.
  String getDistanceDisplay(UserProfile? currentUserProfile) {
    // If the swiped user has hidden their distance, OR if the viewer has hidden theirs, don't show it
    if (!showDistance || (currentUserProfile != null && !currentUserProfile.showDistance)) {
      return location ?? 'Somewhere';
    }

    if (currentUserProfile == null ||
        latitude == null ||
        longitude == null ||
        currentUserProfile.latitude == null ||
        currentUserProfile.longitude == null) {
      return location ?? 'Somewhere';
    }

    try {
      double distanceInMeters = Geolocator.distanceBetween(
        currentUserProfile.latitude!,
        currentUserProfile.longitude!,
        latitude!,
        longitude!,
      );

      double distanceInKm = distanceInMeters / 1000;

      if (distanceInKm < 1) {
        return 'Less than 1 km away';
      } else {
        return '${distanceInKm.toStringAsFixed(1)} km away';
      }
    } catch (e) {
      return location ?? 'Somewhere';
    }
  }

  /// Returns a list of shared interests between this profile and another.
  List<String> getCommonInterests(UserProfile other) {
    List<String> common = [];
    
    // Check Hobbies
    for (var h in hobbies) {
      if (other.hobbies.contains(h)) common.add(h);
    }
    
    // Check Music
    for (var m in musicGenres) {
      if (other.musicGenres.contains(m)) common.add(m);
    }
    
    // Check Movies
    for (var ms in moviesShows) {
      if (other.moviesShows.contains(ms)) common.add(ms);
    }
    
    // Check Weekend Activities
    for (var wa in weekendActivities) {
      if (other.weekendActivities.contains(wa)) common.add(wa);
    }
    
    return common;
  }

  factory UserProfile.empty() {
    return UserProfile();
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    try {
      return UserProfile(
        firstName: map['firstName']?.toString(),
        dob: _parseDate(map['dob']),
        gender: map['gender']?.toString(),
        interestedIn: map['interestedIn']?.toString(),
        location: map['location']?.toString(),
        photos: _parseList(map['photos']),
        bio: map['bio']?.toString(),
        height: map['height']?.toString(),
        bodyType: map['bodyType']?.toString(),
        relationshipStatus: map['relationshipStatus']?.toString(),
        religion: map['religion']?.toString(),
        languages: _parseList(map['languages']),
        smoking: map['smoking']?.toString(),
        drinking: map['drinking']?.toString(),
        fitness: map['fitness']?.toString(),
        diet: map['diet']?.toString(),
        sleepingHabits: map['sleepingHabits']?.toString(),
        pets: map['pets']?.toString(),
        zodiac: map['zodiac']?.toString(),
        occupation: map['occupation']?.toString(),
        industry: map['industry']?.toString(),
        educationLevel: map['educationLevel']?.toString(),
        school: map['school']?.toString(),
        lookingFor: _parseList(map['lookingFor']),
        openToLongDistance: map['openToLongDistance'] is bool ? map['openToLongDistance'] : null,
        wantKids: map['wantKids']?.toString(),
        familyPlans: map['familyPlans']?.toString(),
        hobbies: _parseList(map['hobbies']),
        musicGenres: _parseList(map['musicGenres']),
        moviesShows: _parseList(map['moviesShows']),
        weekendActivities: _parseList(map['weekendActivities']),
        introvertExtrovert: map['introvertExtrovert']?.toString(),
        loveLanguage: map['loveLanguage']?.toString(),
        communicationStyle: map['communicationStyle']?.toString(),
        loveStyle: map['loveStyle']?.toString(),
        mbti: map['mbti']?.toString(),
        politicalViews: map['politicalViews']?.toString(),
        coreValues: map['coreValues']?.toString(),
        videoIntro: map['videoIntro']?.toString(),
        isVerified: map['isVerified'] == true,
        isEmailVerified: map['isEmailVerified'] == true,
        isOnline: map['isOnline'] == true,
        verificationStatus: map['verificationStatus']?.toString() ?? 'unverified',
        nationalId: map['nationalId']?.toString(),
        nationalIdUrl: map['nationalIdUrl']?.toString(),
        blockedUsers: _parseList(map['blockedUsers']),
        promptPerfectDate: map['promptPerfectDate']?.toString(),
        promptFallForYou: map['promptFallForYou']?.toString(),
        promptGreenFlag: map['promptGreenFlag']?.toString(),
        promptTwoTruths: map['promptTwoTruths']?.toString(),
        showAge: map['showAge'] ?? true,
        showDistance: map['showDistance'] ?? true,
        allowMessages: map['allowMessages'] ?? true,
        allowMeetupRequests: map['allowMeetupRequests'] ?? true,
        hideProfile: map['hideProfile'] ?? false,
        meetupLocation: map['meetupLocation'],
        meetupRate: map['meetupRate'],
        meetupNotes: map['meetupNotes'],
        latitude: _parseDouble(map['latitude']),
        longitude: _parseDouble(map['longitude']),
        uid: map['uid']?.toString(),
        phoneNumber: map['phoneNumber']?.toString(),
        countryCode: map['countryCode']?.toString(),
        filterMinAge: map['filterMinAge'] ?? 18,
        filterMaxAge: map['filterMaxAge'] ?? 60,
        filterMaxDistance: _parseDouble(map['filterMaxDistance']) ?? 50.0,
        filterGender: map['filterGender']?.toString(),
        filterAgeStrict: map['filterAgeStrict'] ?? false,
        filterDistanceStrict: map['filterDistanceStrict'] ?? false,
        filterRelationshipStatus: map['filterRelationshipStatus']?.toString() ?? 'Any',
        filterReligion: map['filterReligion']?.toString() ?? 'Any',
        filterSmoking: map['filterSmoking']?.toString() ?? 'Any',
        filterDrinking: map['filterDrinking']?.toString() ?? 'Any',
        filterZodiac: map['filterZodiac']?.toString() ?? 'Any',
        filterEducationLevel: map['filterEducationLevel']?.toString() ?? 'Any',
        filterVerifiedOnly: map['filterVerifiedOnly'] ?? false,
        filterOnlineOnly: map['filterOnlineOnly'] ?? false,
        filterKids: map['filterKids']?.toString() ?? 'Any',
        filterPets: map['filterPets']?.toString() ?? 'Any',
        filterIntrovertExtrovert: map['filterIntrovertExtrovert']?.toString() ?? 'Any',
        filterLookingFor: map['filterLookingFor']?.toString() ?? 'Any',
        filterMaxPhotos: (map['filterMaxPhotos'] as num?)?.toInt() ?? 9,
        filterHasBio: map['filterHasBio'] == true,
        filterFamilyPlans: map['filterFamilyPlans']?.toString() ?? 'Any',
        filterCommunicationStyle: map['filterCommunicationStyle']?.toString() ?? 'Any',
        filterLoveStyle: map['filterLoveStyle']?.toString() ?? 'Any',
        filterCountry: map['filterCountry']?.toString() ?? 'Any',
        isPremium: map['isPremium'] == true,
        premiumType: map['premiumType']?.toString(),
        premiumExpiry: _parseDate(map['premiumExpiry']),
        boostExpiry: _parseDate(map['boostExpiry']),
        sparks: (map['credits'] as num?)?.toInt() ?? 0,
        unlockedLikes: _parseList(map['unlockedLikes']),
        unlockedViewers: _parseList(map['unlockedViewers']),
        dailyUsageDuration: (map['dailyUsageDuration'] as num?)?.toDouble() ?? 0.0,
        lastUsageResetDate: map['lastUsageResetDate']?.toString(),
        lastDailyRewardDate: map['lastDailyRewardDate']?.toString(),
        dailyMessageCount: (map['dailyMessageCount'] as num?)?.toInt() ?? 0,
        lastMessageResetDate: map['lastMessageResetDate']?.toString(),
        claimedRewards: _parseList(map['claimedRewards']),
        lastSeenLikesCount: (map['lastSeenLikesCount'] as num?)?.toInt() ?? 0,
        fcmToken: map['fcmToken']?.toString(),
      );
    } catch (e) {
      debugPrint('UserProfile error parsing map: $e');
      return UserProfile(); // Return empty profile rather than crashing
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<String> _parseList(dynamic value) {
    if (value == null || value is! List) return [];
    return value.map((e) => e.toString()).toList();
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'dob': dob != null ? Timestamp.fromDate(dob!) : null,
      'gender': gender,
      'interestedIn': interestedIn,
      'location': location,
      'photos': photos,
      'bio': bio,
      'height': height,
      'bodyType': bodyType,
      'relationshipStatus': relationshipStatus,
      'religion': religion,
      'languages': languages,
      'smoking': smoking,
      'drinking': drinking,
      'fitness': fitness,
      'diet': diet,
      'sleepingHabits': sleepingHabits,
      'pets': pets,
      'zodiac': zodiac,
      'occupation': occupation,
      'industry': industry,
      'educationLevel': educationLevel,
      'school': school,
      'lookingFor': lookingFor,
      'openToLongDistance': openToLongDistance,
      'wantKids': wantKids,
      'familyPlans': familyPlans,
      'hobbies': hobbies,
      'musicGenres': musicGenres,
      'moviesShows': moviesShows,
      'weekendActivities': weekendActivities,
      'introvertExtrovert': introvertExtrovert,
      'loveLanguage': loveLanguage,
      'communicationStyle': communicationStyle,
      'loveStyle': loveStyle,
      'mbti': mbti,
      'politicalViews': politicalViews,
      'coreValues': coreValues,
      'videoIntro': videoIntro,
      'isVerified': isVerified,
      'isEmailVerified': isEmailVerified,
      'isOnline': isOnline,
      'verificationStatus': verificationStatus,
      'nationalId': nationalId,
      'nationalIdUrl': nationalIdUrl,
      'blockedUsers': blockedUsers,
      'promptPerfectDate': promptPerfectDate,
      'promptFallForYou': promptFallForYou,
      'promptGreenFlag': promptGreenFlag,
      'promptTwoTruths': promptTwoTruths,
      'showAge': showAge,
      'showDistance': showDistance,
      'allowMessages': allowMessages,
      'allowMeetupRequests': allowMeetupRequests,
      'hideProfile': hideProfile,
      'meetupLocation': meetupLocation,
      'meetupRate': meetupRate,
      'meetupNotes': meetupNotes,
      'latitude': latitude,
      'longitude': longitude,
      'uid': uid,
      'phoneNumber': phoneNumber,
      'fcmToken': fcmToken,
      'countryCode': countryCode,
      'filterMinAge': filterMinAge,
      'filterMaxAge': filterMaxAge,
      'filterMaxDistance': filterMaxDistance,
      'filterGender': filterGender,
      'filterAgeStrict': filterAgeStrict,
      'filterDistanceStrict': filterDistanceStrict,
      'filterRelationshipStatus': filterRelationshipStatus,
      'filterReligion': filterReligion,
      'filterSmoking': filterSmoking,
      'filterDrinking': filterDrinking,
      'filterZodiac': filterZodiac,
      'filterEducationLevel': filterEducationLevel,
      'filterVerifiedOnly': filterVerifiedOnly,
      'filterOnlineOnly': filterOnlineOnly,
      'filterKids': filterKids,
      'filterPets': filterPets,
      'filterIntrovertExtrovert': filterIntrovertExtrovert,
      'filterLookingFor': filterLookingFor,
      'filterMaxPhotos': filterMaxPhotos,
      'filterHasBio': filterHasBio,
      'filterFamilyPlans': filterFamilyPlans,
      'filterCommunicationStyle': filterCommunicationStyle,
      'filterLoveStyle': filterLoveStyle,
      'filterCountry': filterCountry,
      'isPremium': isPremium,
      'premiumType': premiumType,
      'premiumExpiry': premiumExpiry != null ? Timestamp.fromDate(premiumExpiry!) : null,
      'boostExpiry': boostExpiry != null ? Timestamp.fromDate(boostExpiry!) : null,
      'credits': sparks,
      'unlockedLikes': unlockedLikes,
      'unlockedViewers': unlockedViewers,
      'dailyUsageDuration': dailyUsageDuration,
      'lastUsageResetDate': lastUsageResetDate,
      'lastDailyRewardDate': lastDailyRewardDate,
      'dailyMessageCount': dailyMessageCount,
      'lastMessageResetDate': lastMessageResetDate,
      'claimedRewards': claimedRewards,
      'lastSeenLikesCount': lastSeenLikesCount,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  int get completionPercentage {
    int filledFields = 0;

    if (firstName != null && firstName!.isNotEmpty) filledFields++;
    if (dob != null) filledFields++;
    if (gender != null && gender!.isNotEmpty) filledFields++;
    if (interestedIn != null && interestedIn!.isNotEmpty) filledFields++;
    if (location != null && location!.isNotEmpty) filledFields++;
    if (photos.isNotEmpty) filledFields++;
    if (bio != null && bio!.isNotEmpty) filledFields++;

    if (height != null && height!.isNotEmpty) filledFields++;
    if (bodyType != null && bodyType!.isNotEmpty) filledFields++;
    if (relationshipStatus != null && relationshipStatus!.isNotEmpty) filledFields++;
    if (religion != null && religion!.isNotEmpty) filledFields++;
    if (languages.isNotEmpty) filledFields++;

    if (smoking != null && smoking!.isNotEmpty) filledFields++;
    if (drinking != null && drinking!.isNotEmpty) filledFields++;
    if (fitness != null && fitness!.isNotEmpty) filledFields++;
    if (diet != null && diet!.isNotEmpty) filledFields++;
    if (sleepingHabits != null && sleepingHabits!.isNotEmpty) filledFields++;
    if (pets != null && pets!.isNotEmpty) filledFields++;
    if (zodiac != null && zodiac!.isNotEmpty) filledFields++;

    if (occupation != null && occupation!.isNotEmpty) filledFields++;
    if (industry != null && industry!.isNotEmpty) filledFields++;
    if (educationLevel != null && educationLevel!.isNotEmpty) filledFields++;
    if (school != null && school!.isNotEmpty) filledFields++;

    if (lookingFor.isNotEmpty) filledFields++;
    if (openToLongDistance != null) filledFields++;
    if (wantKids != null && wantKids!.isNotEmpty) filledFields++;
    if (familyPlans != null && familyPlans!.isNotEmpty) filledFields++;

    if (hobbies.isNotEmpty) filledFields++;
    if (musicGenres.isNotEmpty) filledFields++;
    if (moviesShows.isNotEmpty) filledFields++;
    if (weekendActivities.isNotEmpty) filledFields++;

    if (introvertExtrovert != null && introvertExtrovert!.isNotEmpty) filledFields++;
    if (loveLanguage != null && loveLanguage!.isNotEmpty) filledFields++;
    if (communicationStyle != null && communicationStyle!.isNotEmpty) filledFields++;
    if (loveStyle != null && loveStyle!.isNotEmpty) filledFields++;
    if (mbti != null && mbti!.isNotEmpty) filledFields++;
    if (politicalViews != null && politicalViews!.isNotEmpty) filledFields++;
    if (coreValues != null && coreValues!.isNotEmpty) filledFields++;

    if (promptPerfectDate != null && promptPerfectDate!.isNotEmpty) filledFields++;
    if (promptFallForYou != null && promptFallForYou!.isNotEmpty) filledFields++;
    if (promptGreenFlag != null && promptGreenFlag!.isNotEmpty) filledFields++;
    if (promptTwoTruths != null && promptTwoTruths!.isNotEmpty) filledFields++;

    const totalFields = 43;
    return ((filledFields / totalFields) * 100).round();
  }

  bool isCategoryComplete(String category) {
    switch (category.toLowerCase()) {
      case 'basic':
        // Page 1: Basic Profile
        return (firstName?.isNotEmpty ?? false) &&
            dob != null &&
            (gender?.isNotEmpty ?? false) &&
            (interestedIn?.isNotEmpty ?? false) &&
            (bio?.isNotEmpty ?? false);
      case 'personal':
        // Page 2: Personal Details
        return (height?.isNotEmpty ?? false) ||
            (bodyType?.isNotEmpty ?? false) ||
            (relationshipStatus?.isNotEmpty ?? false) ||
            (religion?.isNotEmpty ?? false) ||
            languages.isNotEmpty;
      case 'lifestyle':
        // Page 3: Lifestyle & Habits
        return (smoking?.isNotEmpty ?? false) &&
            (drinking?.isNotEmpty ?? false) &&
            (fitness?.isNotEmpty ?? false) &&
            (diet?.isNotEmpty ?? false) &&
            (sleepingHabits?.isNotEmpty ?? false);
      case 'work':
        // Page 4: Work & Education
        return (occupation?.isNotEmpty ?? false) &&
            (industry?.isNotEmpty ?? false) &&
            (educationLevel?.isNotEmpty ?? false) &&
            (school?.isNotEmpty ?? false);
      case 'goals':
        // Page 5: Relationship Goals
        return lookingFor.isNotEmpty &&
            openToLongDistance != null &&
            ((wantKids?.isNotEmpty ?? false) || (familyPlans?.isNotEmpty ?? false));
      case 'interests':
        // Page 6: Interests & Hobbies
        return hobbies.isNotEmpty ||
            musicGenres.isNotEmpty ||
            moviesShows.isNotEmpty ||
            weekendActivities.isNotEmpty;
      case 'personality':
        // Page 7: Personality & Values
        return (introvertExtrovert?.isNotEmpty ?? false) ||
            (loveLanguage?.isNotEmpty ?? false) ||
            (communicationStyle?.isNotEmpty ?? false) ||
            (loveStyle?.isNotEmpty ?? false) ||
            (mbti?.isNotEmpty ?? false) ||
            (politicalViews?.isNotEmpty ?? false) ||
            (coreValues?.isNotEmpty ?? false);
      case 'media':
        // Page 8: Media & Verification
        return photos.isNotEmpty; // Changed from 4 to 1
      case 'location':
        // Page 9: Location
        return (location?.isNotEmpty ?? false) && 
               latitude != null && 
               longitude != null;
      case 'prompts':
        // Page 10: Prompts
        // At least 2 prompts should be filled to be considered complete
        int filled = 0;
        if (promptPerfectDate?.isNotEmpty ?? false) filled++;
        if (promptFallForYou?.isNotEmpty ?? false) filled++;
        if (promptGreenFlag?.isNotEmpty ?? false) filled++;
        if (promptTwoTruths?.isNotEmpty ?? false) filled++;
        return filled >= 2;
      case 'verification':
        return isVerified; 
      default:
        return true;
    }
  }
}
