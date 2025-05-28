import 'package:bucket_list_app/screens/bucket_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bucket_list.dart';
import '../models/bucket_item.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/bucket_item_card.dart';



class BucketListScreen extends StatefulWidget {
  final BucketList bucketList;
  final VoidCallback onUpdate;

  const BucketListScreen({
    super.key,
    required this.bucketList,
    required this.onUpdate,
  });

  @override
  _BucketListScreenState createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen> {
  List<DocumentSnapshot> bucketItems = [];

  @override
  void initState() {
    super.initState();
    _loadBucketItems();
  }

  Future<void> _loadBucketItems() async {
    if (widget.bucketList.items.isEmpty) {
      setState(() {
        bucketItems = [];
      });
      return;
    }

    List<DocumentSnapshot> fetchedItems = await Future.wait(
      widget.bucketList.items.map((ref) => ref.get()).toList(),
    );

    setState(() {
      bucketItems = fetchedItems;
    });
  }

  Future<void> _addItem() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Bucket Item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter item name'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              final bucketListDocRef = FirebaseFirestore.instance
                  .collection('bucket_lists')
                  .doc(widget.bucketList.id);

              // 1️⃣ create new bucket item object and use bucket item's toMap() function to send it to firebase
              final newBucketItem = BucketItem(
                id: '', 
                itemName: controller.text.trim(),
                completed: false,
                bucketListRef: bucketListDocRef,
                mediaUrls: [], // default
                description: '', // default
              );

              DocumentReference newItemRef = await FirebaseFirestore.instance
                  .collection('bucket_items')
                  .add(newBucketItem.toMap());

              // 2️⃣ Add reference to the parent bucket list doc
              await bucketListDocRef.update({
                'items': FieldValue.arrayUnion([newItemRef])
              });

              // 3️⃣ Refresh the parent list's reference array
              final updatedDoc = await bucketListDocRef.get();
              widget.bucketList.items = List<DocumentReference>.from(updatedDoc['items']);

              // 4️⃣ Reload bucket items & close dialog
              Navigator.of(context).pop();
              await _loadBucketItems();
              widget.onUpdate();
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }


  Future<void> _toggleComplete(int index) async {
    final itemDoc = bucketItems[index];
    await itemDoc.reference.update({
      'completed': !(itemDoc['completed'] as bool),
    });
    await _loadBucketItems();
    widget.onUpdate();
  }

  Future<void> _editBucketItem(int index) async {
    final itemDoc = bucketItems[index];
    final controller = TextEditingController(text: itemDoc['itemName']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bucket Item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new item name'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await itemDoc.reference.update({
                'itemName': controller.text.trim(),
              });
              Navigator.of(context).pop();
              await _loadBucketItems();
              widget.onUpdate();
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBucketItem(int index) async {
    final itemDoc = bucketItems[index];
    final bucketListDocRef = FirebaseFirestore.instance
        .collection('bucket_lists')
        .doc(widget.bucketList.id);

    try {
      // 0️⃣ Show loading dialog
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                const Text('Deleting...'),
              ],
            ),
          );
        },
      );

      // 1️⃣ Delete all associated media files
      List<dynamic> mediaUrls = itemDoc['mediaUrls'] ?? [];
      Map<String, dynamic> videoThumbnailsRaw = itemDoc['videoThumbnails'] ?? {};
      Map<String, String> videoThumbnails = videoThumbnailsRaw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );

      for (String url in mediaUrls) {
        try {
          // Delete the media file
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
          print('✅ Deleted media: $url');
        } catch (e) {
          print('❌ Failed to delete media: $url, error: $e');
        }

        // Delete associated video thumbnail, if it's a video
        if (url.toLowerCase().contains('.mp4') && videoThumbnails.containsKey(url)) {
          final thumbUrl = videoThumbnails[url];
          if (thumbUrl != null) {
            try {
              print('🔍 Attempting to delete thumbnail: $thumbUrl');
              final thumbRef = FirebaseStorage.instance.refFromURL(thumbUrl);
              await thumbRef.delete();
              print('✅ Deleted thumbnail: $thumbUrl');
            } catch (e) {
              print('❌ Failed to delete thumbnail: $thumbUrl, error: $e');
            }
          }
        }
      }

      // 2️⃣ Remove reference from bucket_list document
      await bucketListDocRef.update({
        'items': FieldValue.arrayRemove([itemDoc.reference])
      });

      // 3️⃣ Delete the actual bucket item document
      await itemDoc.reference.delete();
      print('✅ Bucket item deleted');

      // 4️⃣ Refresh parent bucket list's reference array
      final updatedDoc = await bucketListDocRef.get();
      widget.bucketList.items = List<DocumentReference>.from(updatedDoc['items']);

      // 5️⃣ Reload bucket items
      await _loadBucketItems();
      widget.onUpdate();
    } catch (e) {
      print('❌ Failed to fully delete bucket item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete bucket item: $e')),
      );
    } finally {
      // 6️⃣ Always dismiss the loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.blue.shade200],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Text(
                            widget.bucketList.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                //Shadow(
                                //  color: Colors.black38,
                                //  offset: Offset(2, 2),
                                //  blurRadius: 4,
                                //),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${bucketItems.length} items',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: bucketItems.length,
                itemBuilder: (context, index) {
                  final item = bucketItems[index];
                  return Slidable(
                    key: ValueKey(item.id),
                    startActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) {
                            _editBucketItem(index);
                          },
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          icon: Icons.edit,
                          label: 'Edit',
                        ),
                      ],
                    ),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Confirm Deletion'),
                                  content: const Text('Are you sure you want to delete this item?'),
                                  actions: [
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () {
                                        Navigator.of(context).pop(false); // Don't delete
                                      },
                                    ),
                                    TextButton(
                                      child: const Text('Delete'),
                                      onPressed: () {
                                        Navigator.of(context).pop(true); // Confirm deletion
                                      },
                                    ),
                                  ],
                                );
                              },
                            );

                            if (shouldDelete == true) {
                              _deleteBucketItem(index);
                            }
                          },
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                        ),
                      ],
                    ),
                    child: BucketItemCard(
                      title: item['itemName'],
                      //passing images to build the bucket item card. This will have to be reworked
                      imageUrl: (item['mediaUrls'] != null && item['mediaUrls'].isNotEmpty)
                        ? item['mediaUrls'][0]
                        : null,
                      completed: item['completed'],
                      videoThumbnails: item['videoThumbnails'] != null
                        ? Map<String, String>.from(item['videoThumbnails'] as Map)
                        : {},
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BucketItemScreen(
                              bucketItem: BucketItem.fromFirestore(item),
                              onUpdate: widget.onUpdate,
                            ),
                          ),
                        );
                        await _loadBucketItems();
                      },
                    ),

                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addItem,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}