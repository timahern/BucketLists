import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ManageMediaScreen extends StatefulWidget {
  final List<String> mediaUrls;
  final Function(List<String>) onDelete;

  const ManageMediaScreen({
    super.key,
    required this.mediaUrls,
    required this.onDelete,
  });

  @override
  State<ManageMediaScreen> createState() => _ManageMediaScreenState();
}

class _ManageMediaScreenState extends State<ManageMediaScreen> {
  Set<String> selectedUrls = {};
  Map<String, Uint8List?> videoThumbnails = {};

  @override
  void initState() {
    super.initState();
    _generateThumbnails();
  }

  bool isVideo(String url) {
    return url.toLowerCase().contains('.mp4'); // add other formats if needed
  }

  Future<void> _generateThumbnails() async {
    for (String url in widget.mediaUrls) {
      if (isVideo(url)) {
        final uint8list = await VideoThumbnail.thumbnailData(
          video: url,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128,
          quality: 75,
        );
        if (mounted) {
          setState(() {
            videoThumbnails[url] = uint8list;
          });
        }
      }
    }
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
      if (selectedUrls.length == widget.mediaUrls.length) {
        selectedUrls.clear(); // unselect all
      } else {
        selectedUrls = widget.mediaUrls.toSet(); // select all
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
                  if (selectedUrls.length == widget.mediaUrls.length) {
                    selectedUrls.clear();
                  } else {
                    selectedUrls = widget.mediaUrls.toSet();
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  selectedUrls.length == widget.mediaUrls.length ? 'Unselect All' : 'Select All',
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
        itemCount: widget.mediaUrls.length,
        itemBuilder: (context, index) {
          final url = widget.mediaUrls[index];
          final isSelected = selectedUrls.contains(url);
          final isVideoFile = isVideo(url);

          Widget thumbnailWidget;

          if (isVideoFile) {
            final thumbnail = videoThumbnails[url];
            thumbnailWidget = thumbnail != null
                ? Image.memory(thumbnail, fit: BoxFit.cover, width: double.infinity)
                : Container(color: Colors.black12);
          } else {
            thumbnailWidget = Image.network(url, fit: BoxFit.cover, width: double.infinity);
          }

          return GestureDetector(
            onTap: () => toggleSelection(url),
            //onLongPress: () => toggleSelection(url),
            child: Stack(
              children: [
                thumbnailWidget,
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.check_circle, color: Colors.redAccent),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
