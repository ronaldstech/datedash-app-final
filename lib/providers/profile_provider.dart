import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import '../services/profile_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';

class ProfileProvider with ChangeNotifier, WidgetsBindingObserver {
  final ProfileService _profileService = ProfileService();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserProfile? _userProfile;
  User? _currentUser;
  StreamSubscription<User?>? _userSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;
  int _currentTabIndex = 0;
  int _likesCount = 0;
  int _visitorsCount = 0;
  int _matchesCount = 0;
  int _unreadMessageCount = 0;
  int _sentLikesCount = 0;
  int _swipesVersion = 0;
  int _initialPremiumTab = 0;
  StreamSubscription<int>? _likesCountSubscription;
  StreamSubscription<int>? _sentLikesCountSubscription;
  StreamSubscription<int>? _visitorsCountSubscription;
  StreamSubscription<int>? _matchesCountSubscription;
  StreamSubscription<int>? _unreadMessageCountSubscription;
  double _swipeOffset = 0.0;
  String? _lastSwipedUserId;
  String? _selectedExploreCategory;
  int _exploreSwipesVersion = 0;

  // Usage tracking
  DateTime? _sessionStartTime;

  ProfileProvider() {
    WidgetsBinding.instance.addObserver(this);
    _sessionStartTime = DateTime.now();

    _userSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      _currentUser = user;
      _profileSubscription?.cancel();

      if (user != null) {
        _profileSubscription = _profileService
            .getUserProfileStream(user.uid)
            .listen((profile) {
          _userProfile = profile;
          notifyListeners();
        });

        _likesCountSubscription?.cancel();
        _likesCountSubscription = _profileService
            .getLikesCountStream(user.uid)
            .listen((count) {
          _likesCount = count;
          notifyListeners();
        });

        _visitorsCountSubscription?.cancel();
        _visitorsCountSubscription = _profileService
            .getViewCountStream(user.uid)
            .listen((count) {
          _visitorsCount = count;
          notifyListeners();
        });

        _matchesCountSubscription?.cancel();
        _matchesCountSubscription = _profileService
            .getMatchesCountStream(user.uid)
            .listen((count) {
          _matchesCount = count;
          notifyListeners();
        });

        _unreadMessageCountSubscription?.cancel();
        _unreadMessageCountSubscription = _chatService
            .getUnreadMessageCountStream(user.uid)
            .listen((count) {
          _unreadMessageCount = count;
          notifyListeners();
        });

        _sentLikesCountSubscription?.cancel();
        _sentLikesCountSubscription = _profileService
            .getSentLikesCountStream(user.uid)
            .listen((count) {
          _sentLikesCount = count;
          notifyListeners();
        });
      } else {
        _userProfile = null;
        _likesCount = 0;
        _visitorsCount = 0;
        _matchesCount = 0;
        _unreadMessageCount = 0;
        _sentLikesCount = 0;
        _likesCountSubscription?.cancel();
        _sentLikesCountSubscription?.cancel();
        _visitorsCountSubscription?.cancel();
        _matchesCountSubscription?.cancel();
        _unreadMessageCountSubscription?.cancel();
        notifyListeners();
      }
    });
  }

  UserProfile? get userProfile => _userProfile;
  User? get currentUser => _currentUser;
  int get currentTabIndex => _currentTabIndex;
  int get likesCount => _likesCount;
  
  /// Returns the count for the Likes badge: New likes since last seen.
  int get newLikesCount {
    if (_userProfile == null) return 0;
    final count = _likesCount - _userProfile!.lastSeenLikesCount;
    return count > 0 ? count : 0;
  }

  /// Returns the count for the Likes badge: Total received likes.
  int get unlockedLikesCount => _likesCount;

  int get visitorsCount => _visitorsCount;
  int get matchesCount => _matchesCount;
  int get unreadMessageCount => _unreadMessageCount;
  int get sentLikesCount => _sentLikesCount;
  int get swipesVersion => _swipesVersion;
  double get swipeOffset => _swipeOffset;
  int get initialPremiumTab => _initialPremiumTab;
  String? get selectedExploreCategory => _selectedExploreCategory;
  int get exploreSwipesVersion => _exploreSwipesVersion;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    // If user visits the Likes screen (index 2), mark likes as seen
    if (index == 2) {
      markLikesAsSeen();
    }
    notifyListeners();
  }

  Future<void> markLikesAsSeen() async {
    final uid = _currentUser?.uid;
    final profile = _userProfile;
    if (uid == null || profile == null) return;

    if (profile.lastSeenLikesCount != _likesCount) {
      profile.lastSeenLikesCount = _likesCount;
      notifyListeners();
      try {
        await _profileService.saveUserProfile(uid, profile);
      } catch (e) {
        debugPrint('ProfileProvider: Error marking likes as seen: $e');
      }
    }
  }

  void setExploreCategory(String? category) {
    _selectedExploreCategory = category;
    _exploreSwipesVersion++;
    notifyListeners();
  }

  void navigateToPremium(int subTabIndex) {
    _currentTabIndex = 4; // Premium Tab
    _initialPremiumTab = subTabIndex;
    notifyListeners();
  }

  /// Resets swipe history in Firestore and signals SwipeView to reload.
  Future<void> resetSwipes() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    await _profileService.resetSwipes(uid);
    _swipesVersion++;
    notifyListeners();
  }

  void updateSwipeOffset(double offset) {
    _swipeOffset = offset;
    notifyListeners();
  }

  void resetSwipeOffset() {
    _swipeOffset = 0.0;
    notifyListeners();
  }

  /// Saves or updates a UserProfile in Firestore
  Future<void> saveUserProfile(String uid, UserProfile profile) async {
    try {
      await _profileService.saveUserProfile(uid, profile);
      // Local profile is updated via the stream listener in constructor
    } catch (e) {
      debugPrint('ProfileProvider: Error saving profile: $e');
      rethrow;
    }
  }

  /// Updates a specific field in the user profile
  Future<void> updateProfileField(String field, dynamic value) async {
    final uid = _currentUser?.uid;
    final profile = _userProfile;
    if (uid == null || profile == null) return;

    try {
      final map = profile.toMap();
      map[field] = value;
      final updatedProfile = UserProfile.fromMap(map);
      await saveUserProfile(uid, updatedProfile);
      // Local state updates via stream
    } catch (e) {
      debugPrint('ProfileProvider: Error updating $field: $e');
      rethrow;
    }
  }

  Future<void> updateFilters(
    int minAge, 
    int maxAge, 
    double maxDistance, 
    String gender, 
    bool ageStrict, 
    bool distanceStrict, {
    String filterRelationshipStatus = 'Any',
    String filterReligion = 'Any',
    String filterSmoking = 'Any',
    String filterDrinking = 'Any',
    String filterZodiac = 'Any',
    String filterEducationLevel = 'Any',
    bool filterVerifiedOnly = false,
    String filterKids = 'Any',
    String filterPets = 'Any',
    String filterIntrovertExtrovert = 'Any',
    String filterLookingFor = 'Any',
    int filterMaxPhotos = 9,
    bool filterHasBio = false,
    String filterFamilyPlans = 'Any',
    String filterCommunicationStyle = 'Any',
    String filterLoveStyle = 'Any',
  }) async {
    if (_userProfile == null || _currentUser == null) return;
    
    _userProfile!.filterMinAge = minAge;
    _userProfile!.filterMaxAge = maxAge;
    _userProfile!.filterMaxDistance = maxDistance;
    _userProfile!.filterGender = gender;
    _userProfile!.filterAgeStrict = ageStrict;
    _userProfile!.filterDistanceStrict = distanceStrict;
    _userProfile!.filterRelationshipStatus = filterRelationshipStatus;
    _userProfile!.filterReligion = filterReligion;
    _userProfile!.filterSmoking = filterSmoking;
    _userProfile!.filterDrinking = filterDrinking;
    _userProfile!.filterZodiac = filterZodiac;
    _userProfile!.filterEducationLevel = filterEducationLevel;
    _userProfile!.filterVerifiedOnly = filterVerifiedOnly;
    _userProfile!.filterKids = filterKids;
    _userProfile!.filterPets = filterPets;
    _userProfile!.filterIntrovertExtrovert = filterIntrovertExtrovert;
    _userProfile!.filterLookingFor = filterLookingFor;
    _userProfile!.filterMaxPhotos = filterMaxPhotos;
    _userProfile!.filterHasBio = filterHasBio;
    _userProfile!.filterFamilyPlans = filterFamilyPlans;
    _userProfile!.filterCommunicationStyle = filterCommunicationStyle;
    _userProfile!.filterLoveStyle = filterLoveStyle;
    
    notifyListeners();
    
    try {
      await saveUserProfile(_currentUser!.uid, _userProfile!);
      // Increment swipes version to force a reload of the swiping stack with new filters
      _swipesVersion++;
      _exploreSwipesVersion++;
      notifyListeners();
    } catch (e) {
      debugPrint('ProfileProvider: Error saving filters: $e');
      rethrow;
    }
  }

  /// Deducts credits from the current user
  Future<void> useCredits(int amount) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    try {
      await _profileService.deductCredits(uid, amount);
      // Local state will update via stream
    } catch (e) {
      debugPrint('ProfileProvider: Error using credits: $e');
      rethrow;
    }
  }

  /// Unlocks a specific profile for 20 credits
  Future<void> unlockProfile(String targetId) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    try {
      // 1. Deduct 20 credits
      await useCredits(20);
      
      // 2. Add to unlockedLikes in Firestore
      await _profileService.unlockProfile(uid, targetId);
      
      // 3. Update local state
      _userProfile?.unlockedLikes.add(targetId);
      notifyListeners();
    } catch (e) {
      debugPrint('ProfileProvider: Error unlocking profile: $e');
      rethrow;
    }
  }

  /// Unlocks a specific viewer for 20 credits
  Future<void> unlockViewer(String targetId) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    try {
      // 1. Deduct 20 credits
      await useCredits(20);
      
      // 2. Add to unlockedViewers in Firestore
      await _profileService.unlockViewer(uid, targetId);
      
      // 3. Update local state
      _userProfile?.unlockedViewers.add(targetId);
      notifyListeners();
    } catch (e) {
      debugPrint('ProfileProvider: Error unlocking viewer: $e');
      rethrow;
    }
  }

  /// Sets the last swiped user ID for potential rewind
  void setLastSwipedUserId(String? uid) {
    _lastSwipedUserId = uid;
    notifyListeners();
  }

  /// Performs the rewind action on the backend
  Future<void> rewindSwipe() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || _lastSwipedUserId == null) return;

    try {
      await _profileService.undoLastSwipe(myUid, _lastSwipedUserId!);
      _lastSwipedUserId = null;
      notifyListeners();
    } catch (e) {
      debugPrint('ProfileProvider: Error rewinding swipe: $e');
      rethrow;
    }
  }

  String? get lastSwipedUserId => _lastSwipedUserId;

  /// Returns the display name with fallback logic:
  /// Firestore firstName -> Google displayName -> 'Guest User'
  String get displayName {
    if (_userProfile?.firstName != null && _userProfile!.firstName!.isNotEmpty) {
      return _userProfile!.firstName!;
    }
    return _currentUser?.displayName ?? 'Guest User';
  }

  /// Returns the photo URL with fallback logic:
  /// Firestore first photo -> Google photoURL -> null
  String? get photoURL {
    if (_userProfile?.photos != null && _userProfile!.photos.isNotEmpty) {
      return _userProfile!.photos.first;
    }
    if (_currentUser?.photoURL != null && _currentUser!.photoURL!.isNotEmpty) {
      return _currentUser!.photoURL;
    }
    return null;
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _profileSubscription?.cancel();
    _likesCountSubscription?.cancel();
    _visitorsCountSubscription?.cancel();
    _matchesCountSubscription?.cancel();
    _unreadMessageCountSubscription?.cancel();
    _sentLikesCountSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionStartTime = DateTime.now();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _syncUsage();
    }
  }

  Future<void> _syncUsage() async {
    final uid = _currentUser?.uid;
    final profile = _userProfile;
    if (uid == null || profile == null || _sessionStartTime == null) return;

    final now = DateTime.now();
    final elapsedSeconds = now.difference(_sessionStartTime!).inSeconds.toDouble();
    _sessionStartTime = now;

    final today = now.toIso8601String().split('T')[0];
    
    // Reset daily duration if it's a new day
    if (profile.lastUsageResetDate != today) {
      profile.dailyUsageDuration = 0.0;
      profile.dailyMessageCount = 0;
      profile.lastMessageResetDate = today;
      // Clear daily rewards from claimed list
      profile.claimedRewards.removeWhere((id) => id.startsWith('daily_'));
      profile.lastUsageResetDate = today;
    }

    profile.dailyUsageDuration += elapsedSeconds;

    // Save usage update to Firestore
    await _profileService.saveUserProfile(uid, profile);

    // Check for activity reward
    // _checkActivityReward(uid, profile, today); // Removed automatic awarding - now manual claim in UI
  }

  /// Claims a specific reward and grants credits
  Future<void> claimReward(String rewardId, int amount) async {
    final uid = _currentUser?.uid;
    final profile = _userProfile;
    if (uid == null || profile == null) return;

    try {
      final now = DateTime.now();
      final today = now.toIso8601String().split('T')[0];
      final isDaily = rewardId == 'daily_explorer' || rewardId == 'daily_messenger';

      // 1. Unified Firestore Update via Service
      await _profileService.claimReward(
        uid: uid,
        rewardId: rewardId,
        amount: amount,
        isDaily: isDaily,
        todayDate: today,
      );

      // 2. Update local state for immediate UI reflection
      profile.credits += amount;
      if (isDaily) {
        profile.lastDailyRewardDate = today;
      } else {
        if (!profile.claimedRewards.contains(rewardId)) {
          profile.claimedRewards.add(rewardId);
        }
      }

      notifyListeners();

      // 3. Send Notification for history
      await NotificationService().sendNotification(
        recipientId: uid,
        senderId: 'system',
        senderName: 'Datedash',
        type: 'reward',
        message: '🎁 Challenge completed: $amount free credits added!',
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error claiming reward $rewardId: $e');
      rethrow;
    }
  }
}
