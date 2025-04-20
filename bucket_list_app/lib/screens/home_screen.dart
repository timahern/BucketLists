import 'package:bucket_list_app/models/bucket_item.dart';
import 'package:bucket_list_app/screens/main_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bucket_list_screen.dart';
import '../models/bucket_list.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BucketList> bucketLists = [];
  final user = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _loadBucketLists();
  }

  // Load bucket lists from Firestore
  Future<void> _loadBucketLists() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final snapshot = await FirebaseFirestore.instance
      .collection('bucket_lists')
      .where('userId', isEqualTo: currentUser?.uid)
      .get();
    
    List<BucketList> lists = [];

    for (var doc in snapshot.docs) {
      final bucketList = BucketList.fromFirestore(doc);

      // Fetch all bucket items linked to this list
      List<BucketItem> fetchedItems = [];

      // Parallelize item fetches with Future.wait
      final futures = bucketList.items.map((ref) => ref.get()).toList();
      final itemDocs = await Future.wait(futures);

      for (var itemDoc in itemDocs) {
        fetchedItems.add(BucketItem.fromFirestore(itemDoc));
      }

      // Update ratio with fetched items
      bucketList.updateCompletionRatio(fetchedItems);

      lists.add(bucketList);
    }

    if (!mounted) return; // <- 🔐 important safeguard

    setState(() {
      bucketLists = lists;
    });
  }



  // Add new bucket list to Firestore
  void _addBucketList() {
    final controller = TextEditingController();
    final currentUser = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Bucket List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter list name'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return; // Prevent empty names

              // Create a new bucket list in Firestore with an empty 'items' array
              final docRef = await FirebaseFirestore.instance.collection('bucket_lists').add({
                'title': controller.text.trim(),
                'items': [],
                'userId': currentUser?.uid,  // Initialize with an empty list of references
              });

              _loadBucketLists(); // Reload lists after adding
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }


  // Edit bucket list name
  void _editBucketList(BucketList list) {
    final controller = TextEditingController(text: list.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bucket List Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('bucket_lists')
                  .doc(list.id)
                  .update({'title': controller.text}); // Update title
              _loadBucketLists(); // Reload lists after updating
              Navigator.of(context).pop(); // Close dialog
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog without saving
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Delete bucket list from Firestore
  Future<void> _deleteBucketList(BucketList list) async {
    final bucketListRef = FirebaseFirestore.instance.collection('bucket_lists').doc(list.id);

    // 1 Find all bucket items related to this list
    final itemsQuery = await FirebaseFirestore.instance
        .collection('bucket_items')
        .where('bucket_list_ref', isEqualTo: bucketListRef)
        .get();

    // 2 Delete each item
    for (var doc in itemsQuery.docs) {
      await doc.reference.delete();
    }

    // 3 Finally, delete the bucket list itself
    await bucketListRef.delete();

    // 4 Refresh
    _loadBucketLists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.purple],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 100.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'My Bucket Lists',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bucketLists.length} lists',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                centerTitle: true,
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final list = bucketLists[index];

                  return Slidable(
                    key: ValueKey(list.title),
                    startActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) {
                            _editBucketList(list);
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
                            _deleteBucketList(list);
                          },
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                        ),
                      ],
                    ),
                    child: ListTile(
                      title: Text(
                        list.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      trailing: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: list.getCompletionRate(),
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 5,
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BucketListScreen(bucketList: list, onUpdate: _loadBucketLists),
                        ),
                      ),
                    ),
                  );
                },
                childCount: bucketLists.length,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MaterialButton(
              onPressed: () async {
                FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => MainPage()),
                  (route) => false, // Remove all previous routes
                );
              },
              color: Colors.deepPurple[200],
              child: Text('sign out'),
            ),
            FloatingActionButton(
              onPressed: _addBucketList,
              child: const Icon(Icons.add),
            ),
            
          ],
        ),
      ),
      
    );
  }
}


