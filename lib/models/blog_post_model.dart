import 'package:cloud_firestore/cloud_firestore.dart';

class BlogPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String title;
  final String body;
  final String category;
  final DateTime? publishedAt;

  const BlogPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.category,
    this.authorPhotoUrl,
    this.publishedAt,
  });

  factory BlogPost.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final publishedAt = data['publishedAt'];

    return BlogPost(
      id: document.id,
      authorId: data['authorId']?.toString() ?? '',
      authorName: data['authorName']?.toString() ?? 'Snellum member',
      authorPhotoUrl: data['authorPhotoUrl']?.toString(),
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      category: data['category']?.toString() ?? 'Stories',
      publishedAt: publishedAt is Timestamp ? publishedAt.toDate() : null,
    );
  }

  int get estimatedReadMinutes {
    final wordCount = body.trim().split(RegExp(r'\s+')).length;
    return (wordCount / 200).ceil().clamp(1, 99).toInt();
  }
}
