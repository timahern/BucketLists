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
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
            break;
          case 1:
            onAdd(); 
            break;
          case 2:
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
              (route) => false,
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