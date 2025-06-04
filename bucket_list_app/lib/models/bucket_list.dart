import 'package:cloud_firestore/cloud_firestore.dart';
import 'bucket_item.dart';

class BucketList {
  String listId;          // Unique Firestore doc ID
  String title;       // Name of the bucket list
  String userId;      // Refers to the user who owns this list
  double completionRatio = 0.0; // Not stored in Firestore, only used in-app

  BucketList({
    this.listId = '',
    required this.title,
    required this.userId,
  });

  // Factory constructor to create a BucketList from a Firestore document
  factory BucketList.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return BucketList(
      listId: doc.id,
      title: data['title'] ?? '',
      userId: data['userId'] ?? '',
    );
  }

  // Convert a BucketList object into a Firestore-ready map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'userId': userId,
    };
  }

  // Update completion ratio based on associated bucket items
  Future<void> updateCompletionRatio() async {
    final itemsRef = FirebaseFirestore.instance.collection('bucket_items');

    // Get all items for this list
    final totalQuery = await itemsRef
        .where('listId', isEqualTo: listId)
        .get();

    final totalDocs = totalQuery.docs;
    final totalCount = totalDocs.length;

    // Filter completed items
    final completedCount = totalDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['completed'] == true;
    }).length;

    // Calculate ratio
    completionRatio = (totalCount == 0) ? 0.0 : completedCount / totalCount;
  }



  // Getter for UI use
  double getCompletionRate() {
    //await updateCompletionRatio();
    return completionRatio;
  }

  Future<void> deleteData() async {
    final firestore = FirebaseFirestore.instance;

    try {
      // 1️⃣ Query all bucket_items for this list
      final bucketItemsSnapshot = await firestore
          .collection('bucket_items')
          .where('listId', isEqualTo: listId)
          .get();

      // 2️⃣ Delete each bucket item and its associated media
      for (final doc in bucketItemsSnapshot.docs) {
        final item = BucketItem.fromFirestore(doc);
        await item.deleteData();
      }

      // 3️⃣ Delete the bucket list document itself
      await firestore.collection('bucket_lists').doc(listId).delete();
      print('✅ Bucket list and all associated items/media deleted');
    } catch (e) {
      print('❌ Error deleting bucket list: $e');
      rethrow;
    }
  }

}
