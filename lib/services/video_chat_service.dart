import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile_model.dart';

class VideoChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _waitingCollection =>
      _firestore.collection('video_chat_waiting');

  Stream<List<String>> getConfiguredCountriesStream() {
    return _firestore
        .collection('app_settings')
        .doc('video_chat')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return <String>[];
      final data = doc.data() as Map<String, dynamic>;
      final list = List<dynamic>.from(data['countries'] ?? []);
      return list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    });
  }

  Stream<List<String>> getConfiguredLanguagesStream() {
    return _firestore
        .collection('app_settings')
        .doc('video_chat')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return <String>[];
      final data = doc.data() as Map<String, dynamic>;
      final list = List<dynamic>.from(data['languages'] ?? []);
      return list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    });
  }

  Future<Map<String, dynamic>?> startMatching({
    required UserProfile currentUser,
    required String filterLanguage,
    required String filterGender,
    required int filterMinAge,
    required int filterMaxAge,
    required String filterCountry,
  }) async {
    final String currentUserId = currentUser.uid!;
    final existingTicket = await _waitingCollection.doc(currentUserId).get();
    final existingData = existingTicket.data() as Map<String, dynamic>?;
    final existingStatus = existingData?['status'] as String?;
    final existingPartnerId = existingData?['matchedWith'] as String?;
    final existingChannelId = existingData?['channelId'] as String?;

    if ((existingStatus == 'proposed' || existingStatus == 'matched') &&
        existingPartnerId != null &&
        existingChannelId != null) {
      return _callDataFromTicket(
        existingData!,
        existingPartnerId,
        existingChannelId,
      );
    }

    final skippedUserIds = List<String>.from(
      existingData?['skippedUserIds'] ?? [],
    );

    final Map<String, dynamic> myTicket = {
      'uid': currentUserId,
      'name': currentUser.firstName ?? 'User',
      'photo': currentUser.photos.isNotEmpty ? currentUser.photos.first : '',
      'gender': currentUser.gender ?? 'Other',
      'age': currentUser.age ?? 25,
      'country': currentUser.location ?? 'Unknown',
      'languages': currentUser.languages.isNotEmpty
          ? currentUser.languages
          : ['English'],
      'filterLanguage': filterLanguage,
      'filterGender': filterGender,
      'filterMinAge': filterMinAge,
      'filterMaxAge': filterMaxAge,
      'filterCountry': filterCountry,
      'status': 'waiting',
      'matchedWith': null,
      'channelId': null,
      'isHost': false,
      'accepted': false,
      'partnerName': null,
      'partnerPhoto': null,
      'partnerGender': null,
      'partnerAge': null,
      'partnerCountry': null,
      'skippedUserIds': skippedUserIds,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final docSnap = await _waitingCollection.doc(currentUserId).get();
      final currentDocData = docSnap.data() as Map<String, dynamic>?;
      final currentStatus = currentDocData?['status'] as String?;

      // If we were already proposed or matched by another user, don't reset to waiting!
      if (currentStatus == 'proposed' || currentStatus == 'matched') {
        final partnerId = currentDocData?['matchedWith'] as String?;
        final channelId = currentDocData?['channelId'] as String?;
        if (partnerId != null && channelId != null) {
          return _callDataFromTicket(currentDocData!, partnerId, channelId);
        }
      }

      await _waitingCollection
          .doc(currentUserId)
          .set(myTicket, SetOptions(merge: true));

      final querySnapshot = await _waitingCollection
          .where('status', isEqualTo: 'waiting')
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final String candidateId = data['uid'] ?? doc.id;
        if (candidateId == currentUserId) continue;
        if (data['status'] != 'waiting') continue;
        if (skippedUserIds.contains(candidateId)) continue;

        final candidateSkipped = List<String>.from(
          data['skippedUserIds'] ?? [],
        );
        if (candidateSkipped.contains(currentUserId)) continue;

        final candidateGender = (data['gender'] as String?) ?? 'Other';
        final candidateAge = (data['age'] as num?)?.toInt() ?? 25;
        final candidateCountry = (data['country'] as String?) ?? '';
        final candidateLanguages = List<String>.from(data['languages'] ?? []);

        // 1. My filter against candidate
        final bool genderMatch =
            filterGender == 'Any' ||
            filterGender.isEmpty ||
            _normalizeGender(candidateGender) == _normalizeGender(filterGender) ||
            _normalizeGender(candidateGender) == 'other' ||
            _normalizeGender(filterGender) == 'any';

        final bool ageMatch =
            candidateAge >= filterMinAge && candidateAge <= filterMaxAge;

        final bool countryMatch =
            _isCountryMatch(candidateCountry, filterCountry);

        final bool languageMatch =
            filterLanguage == 'Any' ||
            filterLanguage.isEmpty ||
            candidateLanguages.isEmpty ||
            candidateLanguages.any(
              (lang) => _textMatches(lang, filterLanguage),
            );

        if (!genderMatch || !ageMatch || !countryMatch || !languageMatch) {
          continue;
        }

        // 2. Candidate filter against me
        final candFilterGender = (data['filterGender'] as String?) ?? 'Any';
        final candFilterMinAge = (data['filterMinAge'] as num?)?.toInt() ?? 18;
        final candFilterMaxAge = (data['filterMaxAge'] as num?)?.toInt() ?? 99;
        final candFilterCountry = (data['filterCountry'] as String?) ?? 'Any';
        final candFilterLanguage = (data['filterLanguage'] as String?) ?? 'Any';

        final myGender = currentUser.gender ?? 'Other';
        final myAge = currentUser.age ?? 25;
        final myCountry = currentUser.countryCode ?? currentUser.location ?? 'Unknown';
        final myLanguages = currentUser.languages.isNotEmpty
            ? currentUser.languages
            : ['English'];

        final bool candGenderMatch =
            candFilterGender == 'Any' ||
            candFilterGender.isEmpty ||
            _normalizeGender(myGender) == _normalizeGender(candFilterGender) ||
            _normalizeGender(myGender) == 'other' ||
            _normalizeGender(candFilterGender) == 'any';

        final bool candAgeMatch =
            myAge >= candFilterMinAge && myAge <= candFilterMaxAge;

        final bool candCountryMatch =
            _isCountryMatch(myCountry, candFilterCountry);

        final bool candLanguageMatch =
            candFilterLanguage == 'Any' ||
            candFilterLanguage.isEmpty ||
            myLanguages.isEmpty ||
            myLanguages.any(
              (lang) => _textMatches(lang, candFilterLanguage),
            );

        if (!candGenderMatch ||
            !candAgeMatch ||
            !candCountryMatch ||
            !candLanguageMatch) {
          continue;
        }

        final String channelId = '${candidateId}_$currentUserId';
        bool proposed = false;

        await _firestore.runTransaction((transaction) async {
          final candidateRef = _waitingCollection.doc(candidateId);
          final currentRef = _waitingCollection.doc(currentUserId);
          final candidateSnap = await transaction.get(candidateRef);
          final currentSnap = await transaction.get(currentRef);

          final candidateData =
              candidateSnap.data() as Map<String, dynamic>?;
          final currentData = currentSnap.data() as Map<String, dynamic>?;

          if (candidateData?['status'] != 'waiting' ||
              currentData?['status'] != 'waiting') {
            return;
          }

          transaction.update(candidateRef, {
            'status': 'proposed',
            'matchedWith': currentUserId,
            'channelId': channelId,
            'isHost': false,
            'accepted': false,
            'partnerName': currentUser.firstName ?? 'User',
            'partnerPhoto':
                currentUser.photos.isNotEmpty ? currentUser.photos.first : '',
            'partnerGender': currentUser.gender ?? 'Other',
            'partnerAge': currentUser.age ?? 25,
            'partnerCountry': currentUser.location ?? 'Unknown',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          transaction.update(currentRef, {
            'status': 'proposed',
            'matchedWith': candidateId,
            'channelId': channelId,
            'isHost': true,
            'accepted': false,
            'partnerName': data['name'] ?? 'User',
            'partnerPhoto': data['photo'] ?? '',
            'partnerGender': data['gender'] ?? 'Other',
            'partnerAge': (data['age'] as num?)?.toInt() ?? 25,
            'partnerCountry': data['country'] ?? 'Unknown',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          proposed = true;
        });

        if (!proposed) continue;

        return {
          'channelId': channelId,
          'matchedWith': candidateId,
          'partnerName': data['name'] ?? 'User',
          'partnerPhoto': data['photo'] ?? '',
          'partnerGender': data['gender'] ?? 'Other',
          'partnerAge': (data['age'] as num?)?.toInt() ?? 25,
          'partnerCountry': data['country'] ?? 'Unknown',
          'isHost': true,
        };
      }
    } catch (e, stack) {
      debugPrint('Error in startMatching: $e\n$stack');
    }

    return null;
  }

  Stream<DocumentSnapshot> getTicketStream(String userId) {
    return _waitingCollection.doc(userId).snapshots();
  }

  Stream<DocumentSnapshot> getCallSessionStream(String channelId) {
    return _firestore.collection('video_chat_calls').doc(channelId).snapshots();
  }

  Stream<int> getActiveVideoUsersCountStream() {
    return _firestore
        .collection('video_chat_calls')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs.length * 2);
  }

  Stream<int> getOnlineUsersCountStream() {
    final controller = StreamController<int>();
    QuerySnapshot? waitingSnap;
    QuerySnapshot? callsSnap;

    void emit() {
      final uids = <String>{};
      if (waitingSnap != null) {
        for (final doc in waitingSnap!.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          final uid = data?['uid'] as String? ?? doc.id;
          if (uid.isNotEmpty) uids.add(uid);
        }
      }
      if (callsSnap != null) {
        for (final doc in callsSnap!.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          final host = data?['hostId'] as String?;
          final guest = data?['guestId'] as String?;
          if (host != null && host.isNotEmpty) uids.add(host);
          if (guest != null && guest.isNotEmpty) uids.add(guest);
        }
      }
      if (!controller.isClosed) {
        controller.add(uids.length);
      }
    }

    final sub1 = _firestore
        .collection('video_chat_waiting')
        .snapshots()
        .listen(
          (snap) {
            waitingSnap = snap;
            emit();
          },
          onError: (e) {
            debugPrint('Error listening to video_chat_waiting: $e');
            waitingSnap = null;
            emit();
          },
        );

    final sub2 = _firestore
        .collection('video_chat_calls')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
          (snap) {
            callsSnap = snap;
            emit();
          },
          onError: (e) {
            debugPrint('Error listening to video_chat_calls: $e');
            callsSnap = null;
            emit();
          },
        );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  Future<Map<String, dynamic>?> acceptMatch(String userId) async {
    Map<String, dynamic>? callData;

    await _firestore.runTransaction((transaction) async {
      final myRef = _waitingCollection.doc(userId);
      final mySnap = await transaction.get(myRef);
      final myData = mySnap.data() as Map<String, dynamic>?;

      if (myData == null || myData['status'] != 'proposed') return;

      final partnerId = myData['matchedWith'] as String?;
      final channelId = myData['channelId'] as String?;
      if (partnerId == null || channelId == null) return;

      final partnerRef = _waitingCollection.doc(partnerId);
      final partnerSnap = await transaction.get(partnerRef);
      final partnerData = partnerSnap.data() as Map<String, dynamic>?;

      transaction.update(myRef, {
        'accepted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (partnerData?['status'] == 'proposed' &&
          partnerData?['matchedWith'] == userId &&
          partnerData?['accepted'] == true) {
        transaction.update(myRef, {
          'status': 'matched',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(partnerRef, {
          'status': 'matched',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(
          _firestore.collection('video_chat_calls').doc(channelId),
          {
            'channelId': channelId,
            'hostId': myData['isHost'] == true ? userId : partnerId,
            'guestId': myData['isHost'] == true ? partnerId : userId,
            'status': 'active',
            'startedAt': FieldValue.serverTimestamp(),
            'endedBy': null,
          },
          SetOptions(merge: true),
        );

        callData = _callDataFromTicket(myData, partnerId, channelId);
      }
    });

    return callData;
  }

  Future<void> declineMatch(String userId) async {
    try {
      final mySnap = await _waitingCollection.doc(userId).get();
      final myData = mySnap.data() as Map<String, dynamic>?;
      final partnerId = myData?['matchedWith'] as String?;

      final batch = _firestore.batch();
      batch.set(
        _waitingCollection.doc(userId),
        _waitingResetData(partnerId),
        SetOptions(merge: true),
      );

      if (partnerId != null) {
        batch.set(
          _waitingCollection.doc(partnerId),
          _waitingResetData(userId),
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error declining video match: $e');
    }
  }

  Future<void> cancelMatching(String userId) async {
    try {
      await _waitingCollection.doc(userId).delete();
    } catch (_) {}
  }

  Future<void> endCall(String userId, String channelId) async {
    try {
      await _firestore.collection('video_chat_calls').doc(channelId).update({
        'status': 'ended',
        'endedBy': userId,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    try {
      await _waitingCollection.doc(userId).delete();
    } catch (_) {}
  }

  Future<void> setChatLocked(String channelId, bool isLocked, String lockedByUserId) async {
    try {
      await _firestore.collection('video_chat_calls').doc(channelId).set({
        'isChatLocked': isLocked,
        'chatLockedBy': isLocked ? lockedByUserId : null,
        'chatLockUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating chat lock state: $e');
    }
  }

  Future<void> cleanupOwnTicket(String userId) async {
    try {
      await _waitingCollection.doc(userId).delete();
    } catch (_) {}
  }

  Map<String, dynamic> _waitingResetData(String? skippedUserId) {
    return {
      'status': 'waiting',
      'matchedWith': FieldValue.delete(),
      'channelId': FieldValue.delete(),
      'isHost': false,
      'accepted': false,
      'partnerName': FieldValue.delete(),
      'partnerPhoto': FieldValue.delete(),
      'partnerGender': FieldValue.delete(),
      'partnerAge': FieldValue.delete(),
      'partnerCountry': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (skippedUserId != null)
        'skippedUserIds': FieldValue.arrayUnion([skippedUserId]),
    };
  }

  Map<String, dynamic> _callDataFromTicket(
    Map<String, dynamic> ticket,
    String partnerId,
    String channelId,
  ) {
    return {
      'channelId': channelId,
      'matchedWith': partnerId,
      'partnerName': ticket['partnerName'] ?? 'User',
      'partnerPhoto': ticket['partnerPhoto'] ?? '',
      'partnerGender': ticket['partnerGender'] ?? 'Other',
      'partnerAge': (ticket['partnerAge'] as num?)?.toInt() ?? 25,
      'partnerCountry': ticket['partnerCountry'] ?? 'Unknown',
      'isHost': ticket['isHost'] == true,
    };
  }

  String _normalizeGender(String? value) {
    if (value == null) return 'other';
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'any' || normalized == 'everyone' || normalized == 'all') return 'any';
    if (normalized == 'men' || normalized == 'man' || normalized == 'male' || normalized == 'guy' || normalized == 'boy') return 'male';
    if (normalized == 'women' || normalized == 'woman' || normalized == 'female' || normalized == 'girl' || normalized == 'lady') return 'female';
    return normalized;
  }

  bool _textMatches(String? left, String? right) {
    if (left == null || right == null) return false;
    final a = left.trim().toLowerCase();
    final b = right.trim().toLowerCase();
    if (a.isEmpty || b.isEmpty || a == 'any' || b == 'any') return true;
    return a == b || a.contains(b) || b.contains(a);
  }

  bool _isCountryMatch(String? userCountryOrLocation, String? filterCountry) {
    if (filterCountry == null || filterCountry.trim().isEmpty || filterCountry.trim().toLowerCase() == 'any') {
      return true;
    }
    if (userCountryOrLocation == null || userCountryOrLocation.trim().isEmpty || userCountryOrLocation.trim().toLowerCase() == 'unknown') {
      return true;
    }

    final loc = userCountryOrLocation.trim().toLowerCase();
    final filter = filterCountry.trim().toLowerCase();

    if (loc == filter || loc.contains(filter) || filter.contains(loc)) {
      return true;
    }

    // Common ISO-2 Code to Name Mappings
    final Map<String, List<String>> countryAliases = {
      'malawi': ['mw', 'malawi', 'lilongwe', 'blantyre', 'mzuzu', 'zomba'],
      'united states': ['us', 'usa', 'united states', 'america'],
      'kenya': ['ke', 'kenya', 'nairobi', 'mombasa'],
      'tanzania': ['tz', 'tanzania', 'dar es salaam', 'dodoma'],
      'united kingdom': ['uk', 'gb', 'united kingdom', 'england', 'britain', 'london'],
      'south africa': ['za', 'south africa', 'johannesburg', 'cape town'],
      'nigeria': ['ng', 'nigeria', 'lagos', 'abuja'],
      'canada': ['ca', 'canada', 'toronto', 'vancouver'],
    };

    for (final entry in countryAliases.entries) {
      final key = entry.key;
      final aliases = entry.value;

      final bool filterMatchesKeyOrAlias = filter == key || aliases.contains(filter);
      final bool locMatchesKeyOrAlias = loc == key || aliases.any((alias) => loc == alias || loc.contains(alias));

      if (filterMatchesKeyOrAlias && locMatchesKeyOrAlias) {
        return true;
      }
    }

    return false;
  }
}
