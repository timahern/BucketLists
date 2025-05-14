import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';

class BucketItemCard extends StatefulWidget {
  final String title;
  final bool completed;
  final String? imageUrl;
  final VoidCallback onTap;

  const BucketItemCard({
    Key? key,
    required this.title,
    required this.completed,
    this.imageUrl,
    required this.onTap,
  }) : super(key: key);

  @override
  State<BucketItemCard> createState() => _BucketItemCardState();
}

class _BucketItemCardState extends State<BucketItemCard> {
  Uint8List? videoThumbnail;
  bool isVideo = false;

  @override
  void initState() {
    super.initState();
    _checkIfVideoAndGenerateThumb();
  }

  Future<void> _checkIfVideoAndGenerateThumb() async {
    final url = widget.imageUrl;
    if (url == null) return;

    final videoExtensions = ['.mp4', '.mov', '.webm'];
    final isLikelyVideo = videoExtensions.any((ext) => url.toLowerCase().contains(ext));

    if (mounted) {
      setState(() {
        isVideo = isLikelyVideo;
      });
    }
  }

  Widget _buildMedia() {
    final url = widget.imageUrl;

    if (url == null) {
      return Container(height: 150, color: Colors.grey[300]);
    }

    if (isVideo) {
      return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: url,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128,
          quality: 75,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 150,
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            );
          } else {
            return Container(
              height: 150,
              color: Colors.black26,
              child: const Center(child: Icon(Icons.videocam_off, color: Colors.white)),
            );
          }
        },
      );
    }

    // If not a video, just show the image
    return Image.network(
      url,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(height: 150, color: Colors.grey[300]),
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
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.completed)
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
