import 'package:bucket_list_app/screens/create_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  Future<Widget> _resolveScreen(User? user) async {
    if (user == null) return LoginScreen();

    final doc = await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .get();

    final data = doc.data();
    final hasProfile = data != null &&
        (data['userName'] ?? '').toString().trim().isNotEmpty &&
        data['dob'] != null;

    if (hasProfile) {
      return HomeScreen();
    } else {
      return CreateProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          return FutureBuilder<Widget>(
            future: _resolveScreen(snapshot.data),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              } else {
                return snapshot.data!;
              }
            },
          );
        },
      ),
    );
  }
}