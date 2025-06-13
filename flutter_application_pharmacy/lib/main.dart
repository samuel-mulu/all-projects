import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_pharmacy/models/medication.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'splash_screen.dart';
import 'login_page.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeFirebase(); // Initialize Firebase
  await Hive.initFlutter(); // Hive initialization
  Box<Medication> box = await Hive.openBox<Medication>('medication');

  runApp(const MyApp());
}

class Medications {}

Future<void> initializeFirebase() async {
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyC-fPhYrdHlnL7PKKadZmFBBb0IP5vjvnk",
          authDomain: "pharmacy-400dd.firebaseapp.com",
          projectId: "pharmacy-400dd",
          storageBucket: "pharmacy-400dd.appspot.com",
          messagingSenderId: "985890978569",
          appId: "1:985890978569:web:3e718f69c2f6b5000931d8",
          databaseURL: "https://pharmacy-400dd-default-rtdb.firebaseio.com",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    // Use a more user-friendly error reporting method
    print("Firebase Initialization Error: $e");
    // Example: Show a dialog or snackbar to inform the user
    // You can implement a SnackBar or AlertDialog to inform users of the issue
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharmacy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        } else if (snapshot.hasData) {
          return const MyHomePage(title: '');
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
