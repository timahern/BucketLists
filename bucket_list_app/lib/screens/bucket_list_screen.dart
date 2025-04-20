import 'package:bucket_list_app/screens/bucket_item_screen.dart';
import 'package:flutter/material.dart';
import '../models/bucket_list.dart';
import '../models/bucket_item.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

    // 1 Remove reference from bucket_list first
    await bucketListDocRef.update({
      'items': FieldValue.arrayRemove([itemDoc.reference])
    });

    // 2 THEN delete the actual bucket item
    await itemDoc.reference.delete();

    // 3 Refresh parent bucket list's reference array to avoid fetching a non-existent ref
    final updatedDoc = await bucketListDocRef.get();
    widget.bucketList.items = List<DocumentReference>.from(updatedDoc['items']);

    // 4 Reload bucket items now with fresh refs
    await _loadBucketItems();
    widget.onUpdate();
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
                        Text(
                          widget.bucketList.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                offset: Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
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
                          onPressed: (context) {
                            _deleteBucketItem(index);
                          },
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                        ),
                      ],
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        item['itemName'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: .5,
                        ),
                      ),
                      value: item['completed'],
                      //onChanged: (_) => _toggleComplete(index),
                      onChanged: (_) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BucketItemScreen(bucketItem: BucketItem.fromFirestore(item), onUpdate: _loadBucketItems),
                        ),
                      ),

                      //send user to the bucket item screen
                      //onTap: () => 
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