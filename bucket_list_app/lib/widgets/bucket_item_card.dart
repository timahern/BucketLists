import 'package:flutter/material.dart';

class BucketItemCard extends StatelessWidget {
  final String title;
  final bool completed;
  final String? imageUrl;
  final Map<String, String> videoThumbnails; // <videoUrl, thumbnailUrl>
  final VoidCallback onTap;

  const BucketItemCard({
    Key? key,
    required this.title,
    required this.completed,
    required this.imageUrl,
    required this.videoThumbnails,
    required this.onTap,
  }) : super(key: key);

  bool isVideo(String url) {
    return url.toLowerCase().contains('.mp4') ||
           url.toLowerCase().contains('.mov') ||
           url.toLowerCase().contains('.webm');
  }

  Widget _buildMedia() {
    final url = imageUrl;

    if (url == null) {
      return Container(height: 150, color: Colors.grey[300]);
    }

    if (isVideo(url)) {
      final thumbUrl = videoThumbnails[url];
      if (thumbUrl != null && thumbUrl.isNotEmpty) {
        return Image.network(
          thumbUrl,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            color: Colors.black26,
            child: const Center(child: Icon(Icons.videocam_off, color: Colors.white)),
          ),
        );
      } else {
        return Container(
          height: 150,
          color: Colors.black26,
          child: const Center(child: Icon(Icons.videocam_off, color: Colors.white)),
        );
      }
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
      onTap: onTap,
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
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (completed)
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
