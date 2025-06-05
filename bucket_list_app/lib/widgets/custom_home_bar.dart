import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';

class CustomHomeBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onAdd;
  final bool isBucketListScreen;

  const CustomHomeBar({
    super.key,
    required this.currentIndex,
    required this.onAdd,
    required this.isBucketListScreen,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex, // force safe value,
      onTap: (index) {
        if (index == currentIndex && !isBucketListScreen) return;

        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
            break;
          case 1:
            onAdd(); // 💥 Use the passed-in callback
            break;
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            break;
          
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle, size: 40, color: Colors.yellow),
          label: '',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}