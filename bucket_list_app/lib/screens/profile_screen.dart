import 'dart:io';

import 'package:bucket_list_app/models/bucket_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bucket_list_app/screens/main_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/custom_home_bar.dart';
import 'package:bucket_list_app/models/user_profile.dart';
import 'package:intl/intl.dart';

const double maxStorageMb = 500.0;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fullNameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String _originalName = '';
  DateTime? _originalDob;
  bool _hasChanges = false;
  DateTime? _selectedDate;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile(); 
  }

  void _checkForChanges() {
    final nameChanged = _fullNameController.text != _originalName;
    final dobChanged = _selectedDate != _originalDob;

    setState(() {
      _hasChanges = nameChanged || dobChanged;
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _userProfile = UserProfile(
            userId: data['userId'],
            userName: data['userName'],
            dob: (data['dob'] as Timestamp).toDate(),
            spaceUsed: (data['spaceUsed'] ?? 0.0).toDouble(),
            pfpUrl: data['pfpUrl'] ?? '',
          );

          _originalName = _userProfile!.userName;
          _originalDob = _userProfile!.dob;
          _fullNameController.text = _originalName;
          _selectedDate = _originalDob;
          _birthdayController.text = DateFormat.yMMMd().format(_originalDob!);
        });

        // 👇 Add this block after setState:
        _fullNameController.addListener(_checkForChanges);
        _checkForChanges();
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }



  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000), // use existing value or default
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _birthdayController.text =
            "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
      });

      // ✅ Trigger change detection after state update
      _checkForChanges();
    }
  }


  Future<void> removePfp() async {
    final bool? shouldRemove = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Remove Profile Picture?'),
        content: Text('This will permanently delete your profile picture.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldRemove == true &&
        _userProfile != null &&
        _userProfile!.pfpUrl.isNotEmpty) {
      try {
        // 1. Delete from Firebase Storage (if the URL points to Firebase Storage)
        final ref = FirebaseStorage.instance.refFromURL(_userProfile!.pfpUrl);
        await ref.delete();

        // 2. Update Firestore: clear the `pfpUrl` field
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('user_profiles')
              .doc(user.uid)
              .update({'pfpUrl': ''});
        }

        // 3. Update local object and UI
        setState(() {
          _userProfile!.pfpUrl = '';
        });
      } catch (e) {
        print('Failed to remove profile picture: $e');
        // Optionally, show an error snackbar or alert here
      }
    }
  }

  Future<void> _pickImage() async {
    // Step 1: Ask user where to get the image
    final ImageSource? source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text('Select Profile Photo'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              child: Text('Take a Photo'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: Text('Choose from Gallery'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        );
      },
    );

    if (source == null) return;

    // Step 2: Request permissions
    final permission = source == ImageSource.camera
        ? await Permission.camera.request()
        : await Permission.photos.request();

    if (!permission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied for accessing media.')),
      );
      return;
    }

    // Step 3: Let user pick the image
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    try {
      // Step 4: Delete old image if it exists
      if (_userProfile != null && _userProfile!.pfpUrl.isNotEmpty) {
        try {
          final oldRef = FirebaseStorage.instance.refFromURL(_userProfile!.pfpUrl);
          await oldRef.delete();
        } catch (e) {
          print('Old profile picture not found or already deleted: $e');
        }
      }

      // Step 5: Upload new image
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${user.uid}.jpg');

      await ref.putFile(File(pickedFile.path));
      final newUrl = await ref.getDownloadURL();

      // Step 6: Update Firestore
      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .update({'pfpUrl': newUrl});

      // Step 7: Update local state
      setState(() {
        _userProfile!.pfpUrl = newUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
    } catch (e) {
      print('Error updating profile picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile picture.')),
      );
    }
  }


  Future<void> _confirmDeleteProfile() async {
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete Profile?'),
        content: Text(
          'This will permanently delete your account, bucket lists, media, and profile picture. This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid; // ✅ Save UID before deleting the user
    final firestore = FirebaseFirestore.instance;

    try {
      // 1️⃣ Delete all bucket lists and their media
      final bucketListsSnapshot = await firestore
          .collection('bucket_lists')
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in bucketListsSnapshot.docs) {
        final bucketList = BucketList.fromFirestore(doc);
        await bucketList.deleteData();
      }

      // 2️⃣ Delete profile picture if it exists
      if (_userProfile?.pfpUrl.isNotEmpty == true) {
        try {
          final pfpRef = FirebaseStorage.instance.refFromURL(_userProfile!.pfpUrl);
          await pfpRef.delete();
        } catch (e) {
          print('⚠️ Could not delete profile picture: $e');
        }
      }

      // 3️⃣ Delete Firestore user profile doc
      await firestore.collection('user_profiles').doc(uid).delete();

      // 4️⃣ Delete Firebase Auth user last
      await user.delete();

      // 5️⃣ Navigate away
      Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(builder: (_) => const MainPage()),
        (route) => false,
      );
    } catch (e) {
      print('❌ Error during profile deletion: $e');

      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        await showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: Text('Reauthentication Required'),
            content: Text('Please log out and log back in before trying to delete your account.'),
            actions: [
              CupertinoDialogAction(
                child: Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      } else {
        await showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: Text('Error'),
            content: Text('Something went wrong while deleting your profile.'),
            actions: [
              CupertinoDialogAction(
                child: Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }




  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.blue.shade200],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30.0),
                  child: Text(
                    "Profile Screen",
                    style: GoogleFonts.roboto(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Stack(
                  children: [
                    GestureDetector(
                      onTap:_pickImage,
                      onLongPress: () async {
                        if (_userProfile != null && _userProfile!.pfpUrl.isNotEmpty) {
                          await removePfp();
                        }
                      },
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: (_userProfile != null && _userProfile!.pfpUrl.isNotEmpty)
                            ? NetworkImage(_userProfile!.pfpUrl)
                            : null,
                        child: (_userProfile == null || _userProfile!.pfpUrl.isEmpty)
                            ? Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey[700],
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: TextField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: _userProfile?.userName ?? 'Enter your name',
                          hintStyle: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: TextField(
                        controller: _birthdayController,
                        readOnly: true,
                        onTap: _selectDate,
                        decoration: InputDecoration(
                          hintText: _userProfile?.dob != null
                              ? DateFormat.yMMMd().format(_userProfile!.dob!)
                              : 'Enter your birthday',
                          hintStyle: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          suffixIcon: Icon(Icons.calendar_today),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                //update profile button
                if (_userProfile != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: GestureDetector(
                      onTap: _hasChanges
                          ? () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await FirebaseFirestore.instance
                                    .collection('user_profiles')
                                    .doc(user.uid)
                                    .update({
                                  'userName': _fullNameController.text,
                                  'dob': _selectedDate,
                                });

                                setState(() {
                                  _originalName = _fullNameController.text;
                                  _originalDob = _selectedDate!;
                                  _hasChanges = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Profile updated.')),
                                );
                              }
                            }
                          : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _hasChanges ? Colors.purple : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Update Info',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                //sign out button
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: MaterialButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const MainPage()),
                        (route) => false,
                      );
                    },
                    color: const Color.fromARGB(255, 124, 58, 245),
                    child: const Text('Sign out'),
                  ),
                ),

                const SizedBox(height: 5),

                //delete user profile button
                if (_userProfile != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: GestureDetector(
                      onTap: _confirmDeleteProfile,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Delete Profile',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 5),

                //storage used bar
                if (_userProfile != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Storage Used: ${_userProfile!.spaceUsed.toStringAsFixed(1)} MB / $maxStorageMb MB',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (_userProfile!.spaceUsed / maxStorageMb).clamp(0.0, 1.0),
                          backgroundColor: Colors.white24,
                          color: Colors.purpleAccent,
                          minHeight: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      bottomNavigationBar: CustomHomeBar(
        currentIndex: 2,
        onAdd: () {
          print('nothing to do here');
        },
        isBucketListScreen: false,
      ),
    );
  }

}
