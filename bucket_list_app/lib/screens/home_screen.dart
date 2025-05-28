import 'package:bucket_list_app/models/bucket_item.dart';
import 'package:bucket_list_app/screens/main_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bucket_list_screen.dart';
import '../models/bucket_list.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/bucket_list_card.dart';


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
              final trimmedTitle = controller.text.trim();
              if (trimmedTitle.isEmpty) return;

              final uid = widget.mockUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No user signed in.")),
                );
                return;
              }

              await FirebaseFirestore.instance.collection('bucket_lists').add({
                'title': trimmedTitle,
                'items': [],
                'userId': uid,
              });

              await _loadBucketLists();
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  bool isVideo(String url) {
    final path = Uri.parse(url).path.toLowerCase();
    return path.endsWith('.mp4') || path.contains('.mp4');
  }

  Future<List<String>> getPreviewMediaUrls(List<DocumentReference> itemRefs) async {
    List<String> previewUrls = [];

    for (final ref in itemRefs) {
      final doc = await ref.get();
      final data = doc.data() as Map<String, dynamic>?;

      if (data == null) continue;

      final mediaUrls = List<String>.from(data['mediaUrls'] ?? []);
      final Map<String, dynamic> videoThumbsRaw = data['videoThumbnails'] ?? {};
      final Map<String, String> videoThumbnails = videoThumbsRaw.map((key, value) => MapEntry(key.toString(), value.toString()));

      if (mediaUrls.isNotEmpty) {
        final firstUrl = mediaUrls.first;

        if (isVideo(firstUrl)) {
          final thumbUrl = videoThumbnails[firstUrl];
          if (thumbUrl != null) {
            previewUrls.add(thumbUrl);
          } else {
            // fallback to the video itself if thumbnail is missing
            previewUrls.add(firstUrl);
          }
        } else {
          previewUrls.add(firstUrl);
        }
      }

      if (previewUrls.length == 4) break;
    }

    return previewUrls;
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

      // 2️⃣ For each bucket item, delete associated media and thumbnails
      for (var doc in itemsQuery.docs) {
        List<dynamic> mediaUrls = doc['mediaUrls'] ?? [];

        Map<String, dynamic> videoThumbnailsRaw = doc['videoThumbnails'] ?? {};
        Map<String, String> videoThumbnails = videoThumbnailsRaw.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );

        for (String url in mediaUrls) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(url);
            await ref.delete();
            print('✅ Deleted media: $url');
          } catch (e) {
            print('❌ Failed to delete media: $url, error: $e');
          }

          // Delete thumbnail if this is a video
          if (url.toLowerCase().contains('.mp4') && videoThumbnails.containsKey(url)) {
            final thumbUrl = videoThumbnails[url];
            if (thumbUrl != null) {
              try {
                final thumbRef = FirebaseStorage.instance.refFromURL(thumbUrl);
                await thumbRef.delete();
                print('✅ Deleted thumbnail: $thumbUrl');
              } catch (e) {
                print('❌ Failed to delete thumbnail: $thumbUrl, error: $e');
              }
            }
          }
        }

        // 3️⃣ Delete the bucket item document
        await doc.reference.delete();
        print('✅ Deleted bucket item: ${doc.id}');
      }

      // 4️⃣ Delete the bucket list itself
      await bucketListRef.delete();
      print('✅ Deleted bucket list: ${list.id}');

      // 5️⃣ Refresh home screen list
      await _loadBucketLists();
    } catch (e) {
      print('❌ Failed to fully delete bucket list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete bucket list: $e')),
      );
    } finally {
      // 6️⃣ Dismiss the loading dialog
      Navigator.of(context, rootNavigator: true).pop();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.blue.shade200],
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
                    Text(
                      'My Bucket Lists',
                      style: GoogleFonts.roboto(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final list = bucketLists[index];

                    return FutureBuilder<List<String>>(
                      future: getPreviewMediaUrls(list.items),
                      builder: (context, snapshot) {
                        final mediaUrls = snapshot.data ?? [];

                        return GestureDetector(
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              builder: (context) {
                                return Wrap(
                                  children: [
                                    ListTile(
                                      leading: Icon(Icons.edit),
                                      title: Text('Edit'),
                                      onTap: () {
                                        Navigator.of(context).pop(); // close sheet
                                        _editBucketList(list);
                                      },
                                    ),
                                    ListTile(
                                      leading: Icon(Icons.delete),
                                      title: Text('Delete'),
                                      onTap: () async {
                                        Navigator.of(context).pop(); // close sheet
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Confirm Deletion'),
                                            content: const Text('Are you sure you want to delete this bucket list?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed == true) {
                                          _deleteBucketList(list);
                                        }
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: BucketListPreviewCard(
                            title: list.title,
                            mediaUrls: mediaUrls,
                            completionRate: list.getCompletionRate(),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BucketListScreen(
                                  bucketList: list,
                                  onUpdate: _loadBucketLists,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );

                  },
                  childCount: bucketLists.length,
                ),
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
                  (route) => false,
                );
              },
              color: Colors.deepPurple[200],
              child: const Text('sign out'),
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


