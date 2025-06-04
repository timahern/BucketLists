import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/bucket_item.dart'; // Adjust this import as needed

class BucketItemCard extends StatefulWidget {
  final BucketItem bucketItem;
  final VoidCallback onTap;

  const BucketItemCard({
    Key? key,
    required this.bucketItem,
    required this.onTap,
  }) : super(key: key);

  @override
  State<BucketItemCard> createState() => _BucketItemCardState();
}

class _BucketItemCardState extends State<BucketItemCard> {
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    _loadPreviewImage();
  }

  @override
  void didUpdateWidget(covariant BucketItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload preview image if the item has changed
    if (oldWidget.bucketItem.itemId != widget.bucketItem.itemId ||
        oldWidget.bucketItem != widget.bucketItem) {
      _loadPreviewImage();
    }
  }

  Future<void> _loadPreviewImage() async {
    try {
      final mediaQuery = await FirebaseFirestore.instance
          .collection('bucket_media')
          .where('itemId', isEqualTo: widget.bucketItem.itemId)
          .limit(1)
          .get();

      if (mediaQuery.docs.isNotEmpty) {
        final data = mediaQuery.docs.first.data();
        final thumbnailUrl = data['thumbnailUrl'] as String?;
        final mediaUrl = data['mediaUrl'] as String?;

        setState(() {
          imageUrl = (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              ? thumbnailUrl
              : mediaUrl;
        });
      } else {
        setState(() {
          imageUrl = null;
        });
      }
    } catch (e) {
      print('❌ Error loading media for bucket item: $e');
    }
  }

  Widget _buildMedia() {
    if (imageUrl == null) {
      return Container(
        height: 150,
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.photo, color: Colors.white)),
      );
    }

    return Image.network(
      imageUrl!,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 150,
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.broken_image)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        child: Stack(
          children: [
            _buildMedia(),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.bucketItem.itemName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.bucketItem.completed)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
