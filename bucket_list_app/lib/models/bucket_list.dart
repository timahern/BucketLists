import 'package:cloud_firestore/cloud_firestore.dart';
import 'bucket_item.dart';

class BucketList {
  String id;
  String title;
  List<DocumentReference> items; // Just refs now
  double completionRatio = 0.0;  // Keeps it like old times!
  String userId;

  BucketList({
    this.id = '',
    required this.title,
    required this.items,
    required this.userId,
  });

  factory BucketList.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return BucketList(
      id: doc.id,
      title: data['title'] ?? '',
      items: List<DocumentReference>.from(data['items'] ?? []),
      userId: data['userId']?? '', //<-- pull from firestore
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'items': items,
      'urserId': userId,
    };
  }

  // Here's the OG logic adapted:
  void updateCompletionRatio(List<BucketItem> itemObjects) {
    if (itemObjects.isEmpty) {
      completionRatio = 0.0;
    } else {
      int completedCount = itemObjects.where((item) => item.completed).length;
      completionRatio = completedCount / itemObjects.length;
    }
  }

  double getCompletionRate() {
    return completionRatio;
  }
}
