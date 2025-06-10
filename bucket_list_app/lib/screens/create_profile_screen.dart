import 'package:bucket_list_app/models/user_profile.dart';
import 'package:bucket_list_app/screens/home_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateProfile extends StatefulWidget {
  const CreateProfile({super.key});

  @override
  State<CreateProfile> createState() => _CreateProfileState();
}

class _CreateProfileState extends State<CreateProfile> {
  File? _selectedImage;
  String? _selectedImageUrl;
  DateTime? _selectedDate;
  final ImagePicker _picker = ImagePicker();
  final _fullNameController = TextEditingController();
  final _birthdayController = TextEditingController();


  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000), // default DOB
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _birthdayController.text = "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
      });
    }
  }

  Future<void> _pickImage() async {
    // Ask the user which source they prefer
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

    // If the user cancelled
    if (source == null) return;

    // Request the appropriate permission
    final permission = source == ImageSource.camera
        ? await Permission.camera.request()
        : await Permission.photos.request();

    if (!permission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied for accessing media.')),
      );
      return;
    }

    // Launch the picker with the chosen source
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> removePfp() async{
    //if(_selectedImage == null){
    //  return;
    //}

    final bool? shouldRemove = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Would you like to remove this profile picture?'),
        content: Text(''),
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

    if(shouldRemove == true){
      setState(() {
        _selectedImage = null;
      });
    }
  }

  Future<void> uploadImage() async{
    if (_selectedImage == null) return; // nothing to upload

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    final fileName = 'profile_pictures/${user.uid}.jpg';

    final ref = FirebaseStorage.instance.ref().child(fileName);

    final uploadTask = await ref.putFile(_selectedImage!);

    final url = await ref.getDownloadURL();

    setState(() {
      _selectedImageUrl = url;
    });
  }

  Future<void> createUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Handle this case appropriately if somehow the user isn't logged in
      throw Exception('No user is currently logged in.');
    }

    final userProfile = UserProfile(
      userId: user.uid,
      userName: _fullNameController.text.trim(),
      dob: _selectedDate!,
      pfpUrl: _selectedImageUrl ?? '', // use '' if no image was selected
    );

    await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .set(userProfile.toMap());
  }


  Future<void> finishProfile() async{
    if (_selectedDate== null || _fullNameController.text.trim().isEmpty){
      //show the error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You must enter a name and date of birth."),
          backgroundColor: Colors.red,
        ),
      );
    }else{
      // proceed with registration
      if(_selectedImage != null){
        await uploadImage();
      }
      await createUserProfile();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()), // or wherever you want to go after setup
      );
    }
  }


  @override
  void dispose(){
    _birthdayController.dispose();
    _fullNameController.dispose();
    super.dispose();
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
            Padding(
              padding: const EdgeInsets.all(50.0),
              child: Text(
                "Finish Setting Up\nYour Profile!",
                style: GoogleFonts.roboto(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )
              ),
            ),


            //Circle for user to input their profile picture
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Center(
                child: Stack(
                  children: [
                    // Big circular avatar
                    GestureDetector(
                      onTap: _pickImage,
                      onLongPress: removePfp,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            _selectedImage != null ? FileImage(_selectedImage!) : null,
                        child: _selectedImage == null
                            ? Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey[700],
                              )
                            : null,
                      ),
                    ),
              
                    // Small "+" button
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color.fromARGB(255, 62, 183, 58),
                          child: Icon(
                            Icons.add,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),



            //Full Name Textfield
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
                      hintText: 'Full Name',
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 30,),

            //Space to input date of birth
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
                      hintText: 'Date of Birth',
                      suffixIcon: Icon(Icons.calendar_today),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 30,),

            //Finish Setup Button
            //create account button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: GestureDetector(
                  onTap: finishProfile,
                  child: Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Center(
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 25,),

          ],
        ),
      ),
    );
  }
}