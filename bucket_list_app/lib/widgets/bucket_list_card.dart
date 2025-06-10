import 'package:flutter/material.dart';

class BucketListPreviewCard extends StatelessWidget {
  final String title;
  final List<String> mediaUrls; // already preprocessed to include image URLs and video thumbnails
  final double completionRate;
  final VoidCallback onTap;

  const BucketListPreviewCard({
    Key? key,
    required this.title,
    required this.mediaUrls,
    required this.completionRate,
    required this.onTap,
  }) : super(key: key);

  Widget _buildMediaGrid() {
    if (mediaUrls.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.photo, size: 40, color: Colors.white70),
        ),
      );
    }

    final widgets = mediaUrls.take(4).map((url) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[400]),
      );
    }).toList();

    switch (widgets.length) {
      case 1:
        return widgets[0];
      case 2:
        return Row(
          children: [
            Expanded(child: widgets[0]),
            Expanded(child: widgets[1]),
          ],
        );
      case 3:
        return Row(
          children: [
            Expanded(child: widgets[0]),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: widgets[1]),
                  Expanded(child: widgets[2]),
                ],
              ),
            ),
          ],
        );
      case 4:
      default:
        return GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: widgets
              .map((widget) => Padding(padding: const EdgeInsets.all(1), child: widget))
              .toList(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: Stack(
            children: [
              Positioned.fill(child: _buildMediaGrid()),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  color: Colors.black45,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: completionRate,
                        strokeWidth: 5,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      ),
                      //Text(
                      //  '${(completionRate * 100).round()}%',
                      //  style: const TextStyle(
                      //    fontSize: 9,
                      //    fontWeight: FontWeight.bold,
                      //    color: Colors.white,
                      //  ),
                      //),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
