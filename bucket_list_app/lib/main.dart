import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async{

  WidgetsFlutterBinding.ensureInitialized();
  if(kIsWeb){
    await Firebase.initializeApp(options: const FirebaseOptions(
      apiKey: "AIzaSyAsmdvDpPIOKkm06jJwOUWtzEWDkp2el3Y",
      authDomain: "bucketapp-ecc03.firebaseapp.com",
      projectId: "bucketapp-ecc03",
      storageBucket: "bucketapp-ecc03.firebasestorage.app",
      messagingSenderId: "273351697779",
      appId: "1:273351697779:web:a49a7888097211d27a9106"));
  }else{
    await Firebase.initializeApp();
  }
  

  runApp(const BucketListApp());
}

class BucketListApp extends StatelessWidget {
  const BucketListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bucket List App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
    );
  }
}