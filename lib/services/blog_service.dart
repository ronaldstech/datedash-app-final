import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/blog_post_model.dart';

class BlogService {
  final FirebaseFirestore _firestore;

  BlogService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _blogs =>
      _firestore.collection('blogs');

  /// All published posts are public to signed-in Snellum users.
  Stream<List<BlogPost>> watchPublishedPosts() {
    return _blogs
        .orderBy('publishedAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((document) => document.data()['status'] == 'published')
              .map(BlogPost.fromDocument)
              .toList(),
        );
  }

  Future<void> publishPost({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String title,
    required String body,
    required String category,
  }) async {
    if (FirebaseAuth.instance.currentUser?.uid != authorId) {
      throw StateError('Sign in with the account that is publishing this story.');
    }

    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.length < 5 || cleanTitle.length > 120) {
      throw ArgumentError('The title must be between 5 and 120 characters.');
    }
    if (cleanBody.length < 30 || cleanBody.length > 12000) {
      throw ArgumentError(
        'The story must be between 30 and 12,000 characters.',
      );
    }

    await _blogs.add({
      'authorId': authorId,
      'authorName': authorName.trim().isEmpty
          ? 'Snellum member'
          : authorName.trim(),
      'authorPhotoUrl': authorPhotoUrl,
      'title': cleanTitle,
      'body': cleanBody,
      'category': category,
      'status': 'published',
      'publishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
