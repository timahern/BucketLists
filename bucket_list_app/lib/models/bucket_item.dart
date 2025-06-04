import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';


class BucketItem {
  String itemId;
  String itemName;
  bool completed;
  String listId; // string ID of the parent bucket list
  String description;

  BucketItem({
    this.itemId = '',
    required this.itemName,
    required this.listId,
    this.completed = false,
    this.description = '',
  });

  // Convert BucketItem to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'completed': completed,
      'listId': listId,
      'description': description,
    };
  }

  // Convert Firestore doc to BucketItem object
  factory BucketItem.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;

    return BucketItem(
      itemId: doc.id,
      itemName: data['itemName'] ?? '',
      completed: data['completed'] ?? false,
      listId: data['listId'] ?? '',
      description: data['description'] ?? '',
    );
  }

  Future<void> deleteData() async {
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;

    try {
      // 1️⃣ Query all media associated with this item
      final mediaQuery = await firestore
          .collection('bucket_media')
          .where('itemId', isEqualTo: itemId)
          .get();

      for (final doc in mediaQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final mediaUrl = data['mediaUrl'] as String?;
        final thumbnailUrl = data['thumbnailUrl'] as String?;

        // 2️⃣ Delete media from Firebase Storage
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          try {
            await storage.refFromURL(mediaUrl).delete();
          } catch (e) {
            print('Error deleting media: $e');
          }
        }

        // 3️⃣ Delete thumbnail if it exists
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          try {
            await storage.refFromURL(thumbnailUrl).delete();
          } catch (e) {
            print('Error deleting thumbnail: $e');
          }
        }

        // 4️⃣ Delete the media document itself
        await doc.reference.delete();
      }

      // 5️⃣ Delete the bucket item document
      await firestore.collection('bucket_items').doc(itemId).delete();

    } catch (e) {
      print('Error deleting bucket item and its media: $e');
    }
  }
}
