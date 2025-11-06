import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'login_page.dart';
import 'home_page.dart';
import 'screens/splash_screen.dart';
import 'utils/network_helper.dart';
import 'utils/device_compatibility.dart';

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
    
    // Enable auth persistence for web
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } else {
    await Firebase.initializeApp();
    
    // Enable database offline persistence for mobile
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000); // 10MB cache
  }
  
  // Initialize network monitoring
  NetworkHelper.initialize();
  
  // Initialize device compatibility
  await DeviceCompatibility.initialize();
  
  print('✅ Firebase initialized with persistence enabled');
  print('✅ Network monitoring initialized');
  print('✅ Device compatibility checked');
  
  // Log any compatibility issues
  final issues = DeviceCompatibility.getCompatibilityIssues();
  if (issues.isNotEmpty) {
    print('⚠️ Compatibility issues: ${issues.join(', ')}');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Golden GYM',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 188, 163, 230)),
        useMaterial3: true,
      ),
      home: const SplashScreenWrapper(), // Use wrapper to control splash display
    );
  }
}

// Wrapper to show splash only once
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Hide splash after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(nextPage: const AuthCheck());
    } else {
      return const AuthCheck();
    }
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('AuthCheck - Connection State: ${snapshot.connectionState}');
        print('AuthCheck - Has Data: ${snapshot.hasData}');
        print('AuthCheck - User: ${snapshot.data?.email}');
        print('AuthCheck - Has Error: ${snapshot.hasError}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading indicator while checking authentication status
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF6A5ACD),
                    Color(0xFF9370DB),
                    Color(0xFFBA55D3),
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Golden Gym',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Initializing...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          print('AuthCheck - Navigating to RoleBasedRouter for user: ${snapshot.data!.email}');
          return const RoleBasedRouter(); // User is signed in, check role and route
        } else {
          print('AuthCheck - No user data, showing LoginPage');
          return const LoginPage(); // User is not signed in, show login page
        }
      },
    );
  }
}

class RoleBasedRouter extends StatefulWidget {
  const RoleBasedRouter({super.key});

  @override
  _RoleBasedRouterState createState() => _RoleBasedRouterState();
}

class _RoleBasedRouterState extends State<RoleBasedRouter> {
  bool _isLoading = true;
  bool _isAdmin = false;
  String _userName = "";

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      print('RoleBasedRouter - Current user: ${user?.email}');
      
      if (user != null) {
        final userRef = FirebaseDatabase.instance
            .ref("users/${user.email!.replaceAll('.', '_')}");
        
        print('RoleBasedRouter - Fetching user data from: users/${user.email!.replaceAll('.', '_')}');

        // Use a timeout to prevent hanging
        final snapshot = await userRef.once().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Database request timed out', const Duration(seconds: 5));
          },
        );

        if (snapshot.snapshot.exists) {
          final name = snapshot.snapshot.child('name').value as String?;
          final role = snapshot.snapshot.child('role').value as String?;
          
          print('RoleBasedRouter - User data found - Name: $name, Role: $role');
          
          if (mounted) {
            setState(() {
              _userName = name ?? user.displayName ?? "User";
              _isAdmin = role == 'admin';
              _isLoading = false;
            });
            print('RoleBasedRouter - Navigation ready for user: $_userName (Admin: $_isAdmin)');
          }
        } else {
          // If user data doesn't exist, default to user role
          print('RoleBasedRouter - No user data found, using defaults');
          if (mounted) {
            setState(() {
              _userName = user.displayName ?? "User";
              _isAdmin = false;
              _isLoading = false;
            });
            print('RoleBasedRouter - Navigation ready with defaults for user: $_userName');
          }
        }
      } else {
        // No user, redirect to login
        print('RoleBasedRouter - No user found, redirecting to login');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      }
    } catch (e) {
      print('RoleBasedRouter - Error fetching user role: $e');
      // On error, default to user role but still navigate
      if (mounted) {
        setState(() {
          _userName = FirebaseAuth.instance.currentUser?.displayName ?? "User";
          _isAdmin = false;
          _isLoading = false;
        });
        print('RoleBasedRouter - Navigation ready with error fallback for user: $_userName');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF6A5ACD),
                Color(0xFF9370DB),
                Color(0xFFBA55D3),
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  'Loading your dashboard...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please wait',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Route to appropriate dashboard based on role
    return MyHomePage(
      title: 'Golden GYM',
      userRole: _isAdmin ? 'admin' : 'user',
      userName: _userName,
    );
  }
}
