import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/bucket_media.dart';
import 'package:http/http.dart' as http;

class ManageMediaScreen extends StatefulWidget {
  final String itemId;
  final Function(List<String>) onDelete;

  const ManageMediaScreen({
    super.key,
    required this.itemId,
    required this.onDelete,
  });

  @override
  State<ManageMediaScreen> createState() => _ManageMediaScreenState();
}


class _ManageMediaScreenState extends State<ManageMediaScreen> {
  Set<String> selectedUrls = {};
  List<String> mediaUrls = [];
  //Map<String, Uint8List?> _loadedThumbnails = {};

  @override
  void initState() {
    super.initState();
    _loadUrls();
  }

    Future<void> _loadUrls() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bucket_media')
        .where('itemId', isEqualTo: widget.itemId)
        .get();

    final urls = snapshot.docs.map((doc) {
      final data = doc.data();
      final isVideo = data['isVideo'] ?? false;
      final thumb = data['thumbnailUrl'];
      final url = data['mediaUrl'];

      return (isVideo && thumb != null && thumb.isNotEmpty) ? thumb : url;
    }).toList();

    setState(() {
      mediaUrls = urls.cast<String>();
    });
  }

  bool isVideo(String url) {
    return url.toLowerCase().contains('.mp4') ||
          url.toLowerCase().contains('.mov') ||
          url.toLowerCase().contains('.webm');
  }


  void toggleSelection(String url) {
    setState(() {
      if (selectedUrls.contains(url)) {
        selectedUrls.remove(url);
      } else {
        selectedUrls.add(url);
      }
    });
  }

  void deleteSelected() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete ${selectedUrls.length} item(s)?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      print("🗑️ Deleting ${selectedUrls.length} item(s)...");
      widget.onDelete(selectedUrls.toList()); // still handled by BucketItemScreen
      Navigator.pop(context);
    } else {
      print("❌ Deletion canceled by user.");
    }
  }

  void selectAllOrNone() {
    setState(() {
      if (selectedUrls.length == mediaUrls.length) {
        selectedUrls.clear(); // unselect all
      } else {
        selectedUrls = mediaUrls.toSet(); // select all
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Media"),
        actions: [
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (selectedUrls.length == mediaUrls.length) {
                    selectedUrls.clear();
                  } else {
                    selectedUrls = mediaUrls.toSet();
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  selectedUrls.length == mediaUrls.length ? 'Unselect All' : 'Select All',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: selectedUrls.isEmpty ? null : deleteSelected,
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: mediaUrls.length,
        itemBuilder: (context, index) {
          final url = mediaUrls[index];
          final isSelected = selectedUrls.contains(url);

          return GestureDetector(
            onTap: () => toggleSelection(url),
            child: Stack(
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: const Icon(Icons.check_circle, color: Colors.redAccent),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

}
