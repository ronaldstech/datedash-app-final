import 'package:cloud_firestore/cloud_firestore.dart';
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
      'languages': currentUser.languages,
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

    await _waitingCollection.doc(currentUserId).set(myTicket);

    // Search for candidates already waiting
    final querySnapshot = await _waitingCollection
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: false)
        .get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String candidateId = data['uid'];
      if (candidateId == currentUserId) continue;

      // Check if candidate matches current user's filters
      final candidateGender = data['gender'] as String;
      final candidateAge = data['age'] as int;
      final candidateCountry = data['country'] as String;
      final candidateLanguages = List<String>.from(data['languages'] ?? []);

      final bool genderMatch = filterGender == 'Any' ||
          candidateGender.toLowerCase() == filterGender.toLowerCase();

      final bool ageMatch =
          candidateAge >= filterMinAge && candidateAge <= filterMaxAge;

      final bool countryMatch = filterCountry == 'Any' ||
          candidateCountry.toLowerCase().contains(filterCountry.toLowerCase());

      final bool languageMatch = filterLanguage == 'Any' ||
          candidateLanguages.any((lang) =>
              lang.toLowerCase() == filterLanguage.toLowerCase());

      if (!genderMatch || !ageMatch || !countryMatch || !languageMatch) continue;

      // Check if current user matches candidate's filters
      final candFilterGender = data['filterGender'] as String;
      final candFilterMinAge = data['filterMinAge'] as int;
      final candFilterMaxAge = data['filterMaxAge'] as int;
      final candFilterCountry = data['filterCountry'] as String;
      final candFilterLanguage = data['filterLanguage'] as String;

      final myGender = currentUser.gender ?? 'Other';
      final myAge = currentUser.age ?? 25;
      final myCountry = currentUser.location ?? 'Unknown';
      final myLanguages = currentUser.languages;

      final bool candGenderMatch = candFilterGender == 'Any' ||
          myGender.toLowerCase() == candFilterGender.toLowerCase();

      final bool candAgeMatch =
          myAge >= candFilterMinAge && myAge <= candFilterMaxAge;

      final bool candCountryMatch = candFilterCountry == 'Any' ||
          myCountry.toLowerCase().contains(candFilterCountry.toLowerCase());

      final bool candLanguageMatch = candFilterLanguage == 'Any' ||
          myLanguages.any((lang) =>
              lang.toLowerCase() == candFilterLanguage.toLowerCase());

      if (candGenderMatch && candAgeMatch && candCountryMatch && candLanguageMatch) {
        // We found a mutual match! Let's update both tickets.
        final String channelId = '${candidateId}_$currentUserId';

        // Write batch
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

        await batch.commit();

        return {
          'channelId': channelId,
          'matchedWith': candidateId,
          'partnerName': data['name'],
          'partnerPhoto': data['photo'],
          'isHost': true,
        };
      }
    }

    return null;
  }

  /// Listens to the current user's ticket changes to detect if a match occurred.
  Stream<DocumentSnapshot> getTicketStream(String userId) {
    return _waitingCollection.doc(userId).snapshots();
  }

  /// Cancels matchmaking and deletes the ticket.
  Future<void> cancelMatching(String userId) async {
    try {
      await _waitingCollection.doc(userId).delete();
    } catch (_) {}
  }

  /// Cleans up matching database state.
  Future<void> endCall(String userId, String? partnerId) async {
    try {
      await _waitingCollection.doc(userId).delete();
    } catch (_) {}
    if (partnerId != null) {
      try {
        await _waitingCollection.doc(partnerId).delete();
      } catch (_) {}
    }
  }
}
