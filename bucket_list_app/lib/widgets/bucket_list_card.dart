import 'package:flutter/material.dart';

class BucketListPreviewCard extends StatelessWidget {
  final String title;
  final List<String> mediaUrls;
  final double completionRate; // from 0.0 to 1.0
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

    List<Widget> imageWidgets = mediaUrls.map((url) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[400]),
      );
    }).toList();

    switch (imageWidgets.length) {
      case 1:
        return imageWidgets[0];
      case 2:
        return Row(
          children: [
            Expanded(child: imageWidgets[0]),
            Expanded(child: imageWidgets[1]),
          ],
        );
      case 3:
        return Row(
          children: [
            Expanded(child: imageWidgets[0]),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: imageWidgets[1]),
                  Expanded(child: imageWidgets[2]),
                ],
              ),
            ),
          ],
        );
      case 4:
      default:
        return GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          children: imageWidgets
              .take(4)
              .map((img) => Padding(
                    padding: const EdgeInsets.all(1),
                    child: img,
                  ))
              .toList(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1, // Square
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
                bottom: 6,
                right: 6,
                child: SizedBox(
                  width: 25,
                  height: 25,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: completionRate,
                        strokeWidth: 3,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      ),
                      Text(
                        '${(completionRate * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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
