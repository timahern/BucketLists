import 'package:cloud_firestore/cloud_firestore.dart';


class BucketMedia {
  String mediaId;           // Unique Firestore document ID
  String itemId;            // ID of the parent bucket item
  String mediaUrl;          // Firebase Storage URL
  bool isVideo;             // True if media is a video
  String? thumbnailUrl;     // Nullable: used only for video thumbnails

  BucketMedia({
    this.mediaId = '',
    required this.itemId,
    required this.mediaUrl,
    required this.isVideo,
    this.thumbnailUrl,
  });

  // Convert Firestore document to BucketMedia object
  factory BucketMedia.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return BucketMedia(
      mediaId: doc.id,
      itemId: data['itemId'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      isVideo: data['isVideo'] ?? false,
      thumbnailUrl: data['thumbnailUrl'], // Can be null
    );
  }

  // Convert BucketMedia object to a Firestore-ready map
  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'mediaUrl': mediaUrl,
      'isVideo': isVideo,
      'thumbnailUrl': thumbnailUrl, // Stored as null for images
    };
  }
}
