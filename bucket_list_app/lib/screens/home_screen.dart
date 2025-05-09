import 'package:bucket_list_app/models/bucket_item.dart';
import 'package:bucket_list_app/screens/main_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bucket_list_screen.dart';
import '../models/bucket_list.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:firebase_storage/firebase_storage.dart';


class HomeScreen extends StatefulWidget {
  final User? mockUser; // for testing purposes

  const HomeScreen({super.key, this.mockUser});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BucketList> bucketLists = [];
  late final User user;

  @override
  void initState() {
    super.initState();

    // Use injected mockUser in tests, or FirebaseAuth in real app
    user = widget.mockUser ?? FirebaseAuth.instance.currentUser!;

    if (widget.mockUser == null || !user.uid.startsWith('test')) {
      _loadBucketLists();
    }
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


  bool get isInTestMode {
    var inTest = false;
    assert(() {
      inTest = true;
      return true;
    }());
    return inTest;
  }


  // Add new bucket list to Firestore
  void _addBucketList() {
    final controller = TextEditingController();

    if (!isInTestMode && FirebaseAuth.instance.currentUser == null) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('New Bucket List'),
          content: Text('You must be signed in to add a list.'),
        ),
      );
      return;
    }

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
              if (controller.text.trim().isEmpty) return;

              if (!isInTestMode) {
                final currentUser = FirebaseAuth.instance.currentUser;

                await FirebaseFirestore.instance.collection('bucket_lists').add({
                  'title': controller.text.trim(),
                  'items': [],
                  'userId': currentUser?.uid,
                });

                _loadBucketLists();
              }

              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
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

  Future<void> showLoadingDialog(BuildContext dialogContext, {required String message}) async {
    showDialog(
      barrierDismissible: false,
      context: dialogContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Delete bucket list from Firestore
  Future<void> _deleteBucketList(BucketList list) async {
    final bucketListRef = FirebaseFirestore.instance.collection('bucket_lists').doc(list.id);

    //BuildContext dialogContext;
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


      // 1️⃣ Find all bucket items related to this list
      final itemsQuery = await FirebaseFirestore.instance
          .collection('bucket_items')
          .where('bucket_list_ref', isEqualTo: bucketListRef)
          .get();

      // 2️⃣ For each bucket item, delete associated media
      for (var doc in itemsQuery.docs) {
        List<dynamic> mediaUrls = doc['mediaUrls'] ?? [];
        for (String url in mediaUrls) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(url);
            await ref.delete();
            print('✅ Deleted media: $url');
          } catch (e) {
            print('❌ Failed to delete media: $url, error: $e');
          }
        }

        // 3️⃣ After deleting media, delete the bucket item itself
        await doc.reference.delete();
        print('✅ Deleted bucket item: ${doc.id}');
      }

      // 4️⃣ After all bucket items are deleted, delete the bucket list itself
      await bucketListRef.delete();
      print('✅ Deleted bucket list: ${list.id}');

      // 5️⃣ Refresh the home screen lists
      await _loadBucketLists();
    } catch (e) {
      print('❌ Failed to fully delete bucket list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete bucket list: $e')),
      );
    }finally {
      // 6️⃣ Dismiss the loading dialog
      Navigator.of(context, rootNavigator: true).pop();
    }
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
                          onPressed: (context) async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Confirm Deletion'),
                                  content: const Text('Are you sure you want to delete this bucket list?'),
                                  actions: [
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () {
                                        Navigator.of(context).pop(false);
                                      },
                                    ),
                                    TextButton(
                                      child: const Text('Delete'),
                                      onPressed: () {
                                        Navigator.of(context).pop(true);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );

                            if (shouldDelete == true) {
                              _deleteBucketList(list);
                            }
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


