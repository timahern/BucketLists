import 'package:flutter/material.dart';

class BucketItemCard extends StatelessWidget {
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
            // Background Image or Placeholder
            imageUrl != null
                ? Image.network(
                    imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 150,
                    color: Colors.grey[300],
                  ),
            // Overlay for text and completion status
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
