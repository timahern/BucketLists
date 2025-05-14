import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async{

  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  if(kIsWeb){
    await Firebase.initializeApp(options: FirebaseOptions(
      apiKey: dotenv.env['apiKey']!,
      authDomain: dotenv.env['authDomain']!,
      projectId: dotenv.env['projectId']!,
      storageBucket: dotenv.env['storageBucket']!,
      messagingSenderId: dotenv.env['messagingSenderId']!,
      appId: dotenv.env['appId']!));
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