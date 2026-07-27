import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile_model.dart';

class VideoChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _waitingCollection =>
      _firestore.collection('video_chat_waiting');

  /// Starts the matchmaking process by creating a ticket and searching for candidates.
  Future<Map<String, dynamic>?> startMatching({
    required UserProfile currentUser,
    required String filterLanguage,
    required String filterGender,
    required int filterMinAge,
    required int filterMaxAge,
    required String filterCountry,
  }) async {
    final String currentUserId = currentUser.uid!;

    // Create/update ticket for current user
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
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _waitingCollection.doc(currentUserId).set(myTicket);

      // Search for candidates already waiting (avoid requiring composite index)
      final querySnapshot = await _waitingCollection
          .where('status', isEqualTo: 'waiting')
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final String candidateId = data['uid'] ?? doc.id;
        if (candidateId == currentUserId) continue;
        if (data['status'] != 'waiting') continue;

        // Check if candidate matches current user's filters
        final candidateGender = (data['gender'] as String?) ?? 'Other';
        final candidateAge = (data['age'] as num?)?.toInt() ?? 25;
        final candidateCountry = (data['country'] as String?) ?? '';
        final candidateLanguages = List<String>.from(data['languages'] ?? []);

        final bool genderMatch =
            filterGender == 'Any' ||
            candidateGender.toLowerCase() == filterGender.toLowerCase();

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
                  lang.toLowerCase() == filterLanguage.toLowerCase() ||
                  filterLanguage.toLowerCase().contains(lang.toLowerCase()),
            );

        if (!genderMatch || !ageMatch || !countryMatch || !languageMatch)
          continue;

        // Check if current user matches candidate's filters
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
            myGender.toLowerCase() == candFilterGender.toLowerCase();

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
                  lang.toLowerCase() == candFilterLanguage.toLowerCase() ||
                  candFilterLanguage.toLowerCase().contains(lang.toLowerCase()),
            );

        if (candGenderMatch &&
            candAgeMatch &&
            candCountryMatch &&
            candLanguageMatch) {
          // We found a mutual match! Let's update both tickets.
          final String channelId = '${candidateId}_$currentUserId';

          // Write batch: update tickets + create a dedicated call session doc
          final batch = _firestore.batch();

          batch.update(_waitingCollection.doc(candidateId), {
            'status': 'matched',
            'matchedWith': currentUserId,
            'channelId': channelId,
            'isHost': false,
          });

          batch.update(_waitingCollection.doc(currentUserId), {
            'status': 'matched',
            'matchedWith': candidateId,
            'channelId': channelId,
            'isHost': true,
          });

          // Create call session document — this is the single source of truth
          // for the call lifecycle (replaces watching the waiting tickets)
          batch.set(_firestore.collection('video_chat_calls').doc(channelId), {
            'channelId': channelId,
            'hostId': currentUserId,
            'guestId': candidateId,
            'status': 'active',
            'startedAt': FieldValue.serverTimestamp(),
            'endedBy': null,
          });

          await batch.commit();

          return {
            'channelId': channelId,
            'matchedWith': candidateId,
            'partnerName': data['name'] ?? 'User',
            'partnerPhoto': data['photo'] ?? '',
            'isHost': true,
          };
        }
      }
    } catch (e, stack) {
      debugPrint('Error in startMatching: $e\n$stack');
    }

    return null;
  }

  /// Listens to the current user's ticket changes to detect if a match occurred.
  Stream<DocumentSnapshot> getTicketStream(String userId) {
    return _waitingCollection.doc(userId).snapshots();
  }

  /// Listens to the call session document for lifecycle events (ended, etc.)
  /// This is the source of truth during a live call — not the waiting tickets.
  Stream<DocumentSnapshot> getCallSessionStream(String channelId) {
    return _firestore.collection('video_chat_calls').doc(channelId).snapshots();
  }

  /// Cancels matchmaking and deletes the ticket.
  Future<void> cancelMatching(String userId) async {
    try {
      await _waitingCollection.doc(userId).delete();
    } catch (_) {}
  }

  /// Ends the call:
  /// - Marks call session doc as 'ended'
  /// - Deletes ONLY the current user's own waiting ticket
  /// - Does NOT delete partner's ticket (partner handles their own cleanup)
  Future<void> endCall(String userId, String channelId) async {
    // Mark call as ended in the session document
    try {
      await _firestore.collection('video_chat_calls').doc(channelId).update({
        'status': 'ended',
        'endedBy': userId,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    // Clean up own ticket only
    try {
      await _waitingCollection.doc(userId).delete();
    } catch (_) {}
  }

  /// Called by the partner when they receive the 'ended' signal — cleans up their own ticket.
  Future<void> cleanupOwnTicket(String userId) async {
    try {
      await _waitingCollection.doc(userId).delete();
    } catch (_) {}
  }
}
