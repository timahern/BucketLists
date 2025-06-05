import 'package:bucket_list_app/screens/bucket_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bucket_list.dart';
import '../models/bucket_item.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/bucket_item_card.dart';
import 'package:bucket_list_app/widgets/custom_home_bar.dart';


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
  List<BucketItem> bucketItems = [];

  @override
  void initState() {
    super.initState();
    _loadBucketItems();
  }

  Future<void> _loadBucketItems() async {
    print('NOW USING LOADING BUCKET LISTS');
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bucket_items')
          .where('listId', isEqualTo: widget.bucketList.listId)
          .get();

      final items = querySnapshot.docs.map((doc) => BucketItem.fromFirestore(doc)).toList();

      setState(() {
        print('BUCKET LISTS HAVE BEEN UPDATED');
        bucketItems = items;
      });
    } catch (e) {
      print("Error loading bucket items: $e");
      setState(() {
        bucketItems = [];
      });
    }
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
              final itemName = controller.text.trim();
              if (itemName.isEmpty) return;

              final newBucketItem = BucketItem(
                itemName: itemName,
                listId: widget.bucketList.listId,
              );

              await FirebaseFirestore.instance
                  .collection('bucket_items')
                  .add(newBucketItem.toMap());

              Navigator.of(context).pop();
              await _loadBucketItems();
              widget.onUpdate();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editBucketItem(int index) async {
    final item = bucketItems[index];
    final controller = TextEditingController(text: item.itemName);

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
              await FirebaseFirestore.instance
                  .collection('bucket_items')
                  .doc(item.itemId)
                  .update({'itemName': controller.text.trim()});

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
    final item = bucketItems[index];

    try {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            content: Row(
              children: const [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Deleting...'),
              ],
            ),
          );
        },
      );

      await item.deleteData();

      await _loadBucketItems();
      widget.onUpdate();
    } catch (e) {
      print('❌ Failed to delete bucket item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete bucket item: $e')),
      );
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
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
                    key: ValueKey(item.itemId),
                    startActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) => _editBucketItem(index),
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
                                      onPressed: () => Navigator.of(context).pop(false),
                                    ),
                                    TextButton(
                                      child: const Text('Delete'),
                                      onPressed: () => Navigator.of(context).pop(true),
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
                      key: ValueKey(item.itemId), // or any other changing value
                      bucketItem: item,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BucketItemScreen(
                              bucketItem: item,
                              onUpdate: () async {
                                print('onUpdate called from BucketItemScreen');
                                //await Future.delayed(Duration(milliseconds: 300));
                                await _loadBucketItems(); // ✅
                                widget.onUpdate();         // ✅ notify home screen
                              },
                            ),
                          ),
                        );
                      },
                    ),




                    
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: CustomHomeBar(
          currentIndex: 0,
          onAdd: () {
            _addItem();
          },
          isBucketListScreen: true,
        ),
      ),
    );
  }
}
