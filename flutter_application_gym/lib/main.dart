import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'login_page.dart'; // Existing login page
import 'home_page.dart'; // Existing home page

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensure Flutter binding is initialized
  await initializeFirebase(); // Move Firebase initialization to an async function
  runApp(const MyApp()); // Run the app after initialization
}

Future<void> initializeFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDhUdogNHff4Vy-_qGMRJ5dJ1Gui_rKCcE",
        authDomain: "gym-3efc3.firebaseapp.com",
        projectId: "gym-3efc3",
        storageBucket: "gym-3efc3.appspot.com",
        messagingSenderId: "944325716762",
        appId: "1:944325716762:android:8489937fe506b9b7b81aa3",
        databaseURL: "https://gym-3efc3-default-rtdb.firebaseio.com",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alpha Gym',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 188, 163, 230)),
        useMaterial3: true,
      ),
      home: const AuthCheck(), // Check authentication status
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
          // Show a loading indicator while checking authentication status
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          return const MyHomePage(
              title: 'Alpha Gym'); // User is signed in, navigate to home page
        } else {
          return const LoginPage(); // User is not signed in, show login page
        }
      },
    );
  }
}
