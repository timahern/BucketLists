import 'package:cloud_firestore/cloud_firestore.dart';

class BucketItem {
  String id; //unique id for the item
  String itemName;
  bool completed;
  DocumentReference bucketListRef; // Reference back to its parent bucket list
  List<String> mediaUrls; //list of urls for the photos or videos associated with each bucket item
  String description;
  Map<String, String> videoThumbnails;


  BucketItem({
    required this.id,
    required this.itemName,
    required this.bucketListRef,
    this.completed = false,
    this.mediaUrls = const [],
    this.description = '',
    this.videoThumbnails = const {},
  });

  // Convert BucketItem to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'completed': completed,
      'bucket_list_ref': bucketListRef,
      'mediaUrls': mediaUrls,
      'description': description,
      'videoThumbnails': videoThumbnails,
    };
  }

  // Convert Firestore doc to BucketItem object
  factory BucketItem.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;

    // Safely cast the videoThumbnails map
    final rawThumbnails = data['videoThumbnails'];
    final videoThumbnails = rawThumbnails is Map<String, dynamic>
        ? Map<String, String>.from(rawThumbnails)
        : <String, String>{};

    return BucketItem(
      id: doc.id,
      itemName: data['itemName'] ?? '',
      completed: data['completed'] ?? false,
      bucketListRef: data['bucket_list_ref'],
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      description: data['description'] ?? '',
      videoThumbnails: videoThumbnails,
    );
  }
}
