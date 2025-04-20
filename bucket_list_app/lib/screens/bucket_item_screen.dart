import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../models/bucket_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

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

  final ImagePicker picker = ImagePicker();
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
   // _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> addPicture() async {
    try {
      // Ask user to choose photo source
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );

      if (source == null) {
        print("🟡 User canceled image source selection.");
        return;
      }

      print("🟡 User selected source: $source");

      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 75,
      );

      if (pickedFile == null) {
        print("🟡 No file selected.");
        return;
      }

      print("🟢 Image selected: ${pickedFile.name}");

      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('bucket_item_images')
          .child(widget.bucketItem.id)
          .child(fileName);

      try {
        print("🟡 Uploading to Firebase Storage...");
        await storageRef.putData(await pickedFile.readAsBytes());
        print("✅ Upload complete. Getting download URL...");
      } catch (uploadError) {
        print("❌ Firebase upload error: $uploadError");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $uploadError')),
        );
        return;
      }


      final downloadUrl = await storageRef.getDownloadURL();

      print("✅ Download URL: $downloadUrl");

      final itemRef = FirebaseFirestore.instance
          .collection('bucket_items')
          .doc(widget.bucketItem.id);

      await itemRef.update({
        'mediaUrls': FieldValue.arrayUnion([downloadUrl])
      });

      print("✅ Firestore updated.");

      setState(() {
        widget.bucketItem.mediaUrls.add(downloadUrl);
      });

      widget.onUpdate();
    } catch (e) {
      print("❌ Error during image upload: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  List<Widget> carousel() {
    return [
      Center(
        child: SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.bucketItem.mediaUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final imageUrl = widget.bucketItem.mediaUrls[index];
              final isActive = index == _currentPage;

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
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text('Image failed to load', style: TextStyle(color: Colors.white)),
                        );
                      },
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
          widget.bucketItem.mediaUrls.length,
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

        body: Column(
          children: [
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(top: 20.0),
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

            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () {
                    Navigator.pop(context);
                  },
              ),
              
            ),

            SizedBox(height: 20), 

            //CONDITIONAL STATEMENT image (placeholder, will later be a photo carousel)
            ...(widget.bucketItem.mediaUrls.isEmpty
            ? [
              Image(
                image: AssetImage('assets/images/italy-pisa-leaning-tower.jpg'),
                width: double.infinity, // Adjust size as needed
                height: 300,
              ),
            ]
            : carousel()),
            
            

            //Button for adding pictures to users mediaUrls list
            GestureDetector(
              onTap: addPicture,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: Text(
                    'Add Photos',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
            
          ],
            
        )

        
      ),

    );
  }
}