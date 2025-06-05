import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bucket_list_app/screens/main_page.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_home_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Profile')),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.blue.shade200],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          //mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.all(50.0),
              child: Text(
                "Profile Screen",
                style: GoogleFonts.roboto(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )
              ),
            ),

            const Spacer(),

            Center(
                child: MaterialButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const MainPage()),
                      (route) => false,
                    );
                  },
                  color: Colors.deepPurple[200],
                  child: const Text('Sign out'),
                ),
              ),
            
            const Spacer(),
          ],
        ),
      ),
      backgroundColor: Colors.transparent, // Make sure scaffold is transparent
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
