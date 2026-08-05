import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile_model.dart';

class VideoChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _waitingCollection =>
      _firestore.collection('video_chat_waiting');

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

        final bool genderMatch =
            filterGender == 'Any' ||
            _normalizeGender(candidateGender) == _normalizeGender(filterGender);

        final bool ageMatch =
            candidateAge >= filterMinAge && candidateAge <= filterMaxAge;

        final bool countryMatch =
            filterCountry == 'Any' ||
            candidateCountry.toLowerCase().contains(
              filterCountry.toLowerCase(),
            ) ||
            filterCountry.toLowerCase().contains(
              candidateCountry.toLowerCase(),
            );

        final bool languageMatch =
            filterLanguage == 'Any' ||
            candidateLanguages.isEmpty ||
            candidateLanguages.any(
              (lang) =>
                  _textMatches(lang, filterLanguage),
            );

        if (!genderMatch || !ageMatch || !countryMatch || !languageMatch) {
          continue;
        }

        final candFilterGender = (data['filterGender'] as String?) ?? 'Any';
        final candFilterMinAge = (data['filterMinAge'] as num?)?.toInt() ?? 18;
        final candFilterMaxAge = (data['filterMaxAge'] as num?)?.toInt() ?? 80;
        final candFilterCountry = (data['filterCountry'] as String?) ?? 'Any';
        final candFilterLanguage = (data['filterLanguage'] as String?) ?? 'Any';

        final myGender = currentUser.gender ?? 'Other';
        final myAge = currentUser.age ?? 25;
        final myCountry = currentUser.location ?? 'Unknown';
        final myLanguages = currentUser.languages.isNotEmpty
            ? currentUser.languages
            : ['English'];

        final bool candGenderMatch =
            candFilterGender == 'Any' ||
            _normalizeGender(myGender) == _normalizeGender(candFilterGender);

        final bool candAgeMatch =
            myAge >= candFilterMinAge && myAge <= candFilterMaxAge;

        final bool candCountryMatch =
            candFilterCountry == 'Any' ||
            myCountry.toLowerCase().contains(candFilterCountry.toLowerCase()) ||
            candFilterCountry.toLowerCase().contains(myCountry.toLowerCase());

        final bool candLanguageMatch =
            candFilterLanguage == 'Any' ||
            myLanguages.any(
              (lang) =>
                  _textMatches(lang, candFilterLanguage),
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

  String _normalizeGender(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'men' || normalized == 'man') return 'male';
    if (normalized == 'women' || normalized == 'woman') return 'female';
    return normalized;
  }

  bool _textMatches(String left, String right) {
    final a = left.trim().toLowerCase();
    final b = right.trim().toLowerCase();
    return a == b || a.contains(b) || b.contains(a);
  }
}
