import 'package:bucket_list_app/models/bucket_list.dart';
import 'package:bucket_list_app/screens/bucket_list_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../models/bucket_item.dart';
import '../models/bucket_media.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_pickers/image_pickers.dart';
import 'dart:io';
import '../widgets/video_player_widget.dart';
import '../widgets/full_screen_image_view.dart';
import 'package:bucket_list_app/screens/media_management_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data'; // for Uint8List



class BucketItemScreen extends StatefulWidget {
  final BucketItem bucketItem;
  final VoidCallback onUpdate;

  const BucketItemScreen({
    super.key,
    required this.bucketItem,
    required this.onUpdate,
    });

  @override
  State<BucketItemScreen> createState() => _BucketItemScreenState();
}

class _BucketItemScreenState extends State<BucketItemScreen> {

  TextEditingController _descriptionController = TextEditingController();
  List<BucketMedia> _mediaList = [];
  bool _hasChanges = false;
  
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {

    super.initState();
    _descriptionController = TextEditingController(
      text: widget.bucketItem.description ?? '',
    );

    _pageController = PageController(viewportFraction: 0.85);

    _loadMedia();
    _hasChanges = true;
  }

  Future<void> _loadMedia() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bucket_media')
        .where('itemId', isEqualTo: widget.bucketItem.itemId)
        .get();

    setState(() {
      _mediaList = snapshot.docs.map((doc) => BucketMedia.fromFirestore(doc)).toList();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  //bool isVideo(String url) {
  //  final path = Uri.parse(url).path.toLowerCase();
  //  return path.endsWith('.mp4') || path.contains('.mp4');
  //}


  Future<void> addMedia() async {
    final imageStatus = await Permission.photos.request();
    final videoStatus = await Permission.videos.request();
    final cameraStatus = await Permission.camera.request();

    if (!imageStatus.isGranted || !videoStatus.isGranted || !cameraStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions required to access media.')),
      );
      return;
    }

    try {
      final List<Media>? picked = await ImagePickers.pickerPaths(
        galleryMode: GalleryMode.all,
        selectCount: 10,
        showGif: false,
        showCamera: true,
        compressSize: 500,
      );

      if (picked == null || picked.isEmpty) return;

      for (final media in picked) {
        final path = media.path;
        if (path == null || path.isEmpty) continue;

        final file = File(path);
        final int fileSize = await file.length();

        if (fileSize > 25 * 1024 * 1024) {
          final name = path.split('/').last;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name is over 25MB and was skipped')),
          );
          continue;
        }

        final fileName = DateTime.now().millisecondsSinceEpoch.toString() + "_" + path.split('/').last;
        final mediaRef = FirebaseStorage.instance
            .ref()
            .child('bucket_item_media')
            .child(widget.bucketItem.itemId)
            .child(fileName);

        try {
          // Upload the media file
          await mediaRef.putFile(file);
          final downloadUrl = await mediaRef.getDownloadURL();

          bool isVideo = downloadUrl.toLowerCase().contains('.mp4') ||
                        downloadUrl.toLowerCase().contains('.mov') ||
                        downloadUrl.toLowerCase().contains('.webm');

          String? thumbnailUrl;

          if (isVideo) {
            final thumbData = await getVideoThumbnail(downloadUrl);
            
            await VideoThumbnail.thumbnailData(
              video: downloadUrl,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 300,
              quality: 75,
            );

            if (thumbData != null) {
              final thumbRef = FirebaseStorage.instance
                  .ref()
                  .child('bucket_item_media')
                  .child(widget.bucketItem.itemId)
                  .child('thumb_$fileName.jpg');

              await thumbRef.putData(thumbData);
              thumbnailUrl = await thumbRef.getDownloadURL();
            }
          }

          // Save new bucket_media document
          await FirebaseFirestore.instance.collection('bucket_media').add({
            'itemId': widget.bucketItem.itemId,
            'mediaUrl': downloadUrl,
            'isVideo': isVideo,
            if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
          });

        } catch (e) {
          print("❌ Upload error for $fileName: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload $fileName')),
          );
        }
      }

      // Reload or refresh state as needed
      await _loadMedia(); 
      _hasChanges = true;
      widget.onUpdate();
      //Navigator.pop(context, true);

    } catch (e) {
      print("❌ Error in addMedia(): $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Media selection failed: $e')),
      );
    }
  }

  


  Future<Uint8List?> getVideoThumbnail(String videoUrl) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 75,
      );
    } catch (e) {
      print('❌ Failed to generate thumbnail: $e');
      return null;
    }
  }


  //final Map<String, Uint8List> _videoThumbnailCache = {};

  //Future<Uint8List?> _getCachedVideoThumbnail(String url) async {
  //  if (_videoThumbnailCache.containsKey(url)) {
  //    return _videoThumbnailCache[url];
  //  }

    //try {
      //final uint8list = await VideoThumbnail.thumbnailData(
        //video: url,
        //imageFormat: ImageFormat.JPEG,
        //maxWidth: 128,
        //quality: 75,
      //);
      //if (uint8list != null) {
        //_videoThumbnailCache[url] = uint8list;
      //}
      //return uint8list;
    //} catch (e) {
      //print("❌ Error generating thumbnail for $url: $e");
      //return null;
    //}
  //}


  List<Widget> carousel() {
    return [
      Center(
        child: SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _mediaList.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final media = _mediaList[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: media.isVideo
                        ? GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoPlayerWidget(videoUrl: media.mediaUrl),
                                ),
                              );
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.network(
                                  media.thumbnailUrl ?? '',
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.black26,
                                    child: const Center(
                                      child: Icon(Icons.play_circle_fill,
                                          size: 64, color: Colors.white),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.play_circle_fill,
                                    size: 64, color: Colors.white),
                              ],
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageView(imageUrl: media.mediaUrl),
                                ),
                              );
                            },
                            child: Image.network(
                              media.mediaUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Text('Image failed to load',
                                      style: TextStyle(color: Colors.white)),
                                );
                              },
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _mediaList.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 12 : 8,
            height: _currentPage == index ? 12 : 8,
            decoration: BoxDecoration(
              color: _currentPage == index ? Colors.white : Colors.white38,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ];
  }









  //saving the description function
  Future<void> saveDescription(String newDescription) async {
    try {
      final itemRef = FirebaseFirestore.instance
          .collection('bucket_items')
          .doc(widget.bucketItem.itemId);

      await itemRef.update({
        'description': newDescription,
      });

      print("✅ Description updated.");
      
      setState(() {
        widget.bucketItem.description = newDescription;
      });

      widget.onUpdate();
      //Navigator.pop(context, true);
    } catch (e) {
      print("❌ Failed to update description: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update description: $e')),
      );
    }
  }


  //updates the completed checkbox and boolean value for the bucket item
  Future<void> updateCompleted(bool completed) async {
    try {
      final itemRef = FirebaseFirestore.instance
          .collection('bucket_items')
          .doc(widget.bucketItem.itemId);

      await itemRef.update({
        'completed': completed,
      });

      print("✅ Completion status updated.");

      setState(() {
        widget.bucketItem.completed = completed;
      });

      widget.onUpdate();
      //Navigator.pop(context, true);
    } catch (e) {
      print("❌ Failed to update completed status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update completion status: $e')),
      );
    }
  }


  Future<void> deleteMedia(List<String> urlsToDelete) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Deleting..."),
          ],
        ),
      ),
    );

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bucket_media')
          .where('itemId', isEqualTo: widget.bucketItem.itemId)
          .get();

      int deletedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final mediaUrl = data['mediaUrl'] as String?;
        final thumbnailUrl = data['thumbnailUrl'] as String?;

        final shouldDelete = urlsToDelete.contains(mediaUrl) || 
                            (thumbnailUrl != null && urlsToDelete.contains(thumbnailUrl));

        if (!shouldDelete) continue;

        // Delete media file
        if (mediaUrl != null) {
          try {
            await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
            print('✅ Deleted media: $mediaUrl');
          } catch (e) {
            print('❌ Failed to delete media: $mediaUrl, error: $e');
          }
        }

        // Delete thumbnail file (if exists)
        if (thumbnailUrl != null) {
          try {
            await FirebaseStorage.instance.refFromURL(thumbnailUrl).delete();
            print('✅ Deleted thumbnail: $thumbnailUrl');
          } catch (e) {
            print('❌ Failed to delete thumbnail: $thumbnailUrl, error: $e');
          }
        }

        // Delete the Firestore document
        try {
          await doc.reference.delete();
          print('✅ Deleted bucket_media doc: ${doc.id}');
          deletedCount++;
        } catch (e) {
          print('❌ Failed to delete bucket_media doc: $e');
        }
      }

      await _loadMedia();
      _hasChanges = true; // Refresh the local media list
      widget.onUpdate();
      //Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Deleted $deletedCount item(s)')),
      );

    } catch (e) {
      print('❌ Error during media deletion: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete media')),
      );
    } finally {
      Navigator.of(context, rootNavigator: true).pop(); // Close dialog
    }
  }






  void _navigateToManageMedia() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManageMediaScreen(
          itemId: widget.bucketItem.itemId,
          onDelete: deleteMedia,
        ),
      ),
    );

    // Refresh media after possible deletions
    await _loadMedia();
    _hasChanges = true;
    widget.onUpdate();
    //Navigator.pop(context, true);
  }

  Future<BucketList?> fetchBucketListFromItem(BucketItem item) async {
    final doc = await FirebaseFirestore.instance
        .collection('bucket_lists')
        .doc(item.listId)
        .get();

    if (doc.exists) {
      return BucketList.fromFirestore(doc);
    } else {
      print('❌ BucketList not found for listId: ${item.listId}');
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.blue.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          )
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,

        body: SingleChildScrollView(
          child: Column(
            children: [
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: Text(
                    widget.bucketItem.itemName,
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
                ),
              ),
          
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                        
                    ),
                    Row(
                      children: [
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        Checkbox(
                          value: widget.bucketItem.completed,
                          activeColor: Colors.white,
                          checkColor: Colors.deepPurple,
                          onChanged: (bool? newValue) async {
                            if (newValue != null) {
                              await updateCompleted(newValue);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          
              SizedBox(height: 20), 
          
              //CONDITIONAL STATEMENT image (placeholder, will later be a photo carousel)
              ...(_mediaList.isEmpty
              ? [
                Image(
                  image: AssetImage('assets/images/italy-pisa-leaning-tower.jpg'),
                  width: double.infinity, // Adjust size as needed
                  height: 300,
                ),
              ]
              : carousel()),
              
              
          
              //Button for adding pictures to users mediaUrls list and button for managing media
              Padding(
                padding: const EdgeInsets.only(top: 15.0),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: addMedia,
                        child: Container(
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Add Photos and Videos',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12), // Space between buttons
                      GestureDetector(
                        onTap: _navigateToManageMedia,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Manage\nMedia',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              
              //Description box for the bucket item (might be moved above the photos later)
          
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: "Write about your trip...",
                          contentPadding: EdgeInsets.all(16),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          saveDescription(value);
                        }
                      ),
                    ),
                  ],
                ),
              ),
          
          
          
            ],
              
          ),
        )

        
      ),

    );
  }
}