import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../../services/firebase_service.dart';
import 'screens/register_page.dart';
import 'screens/active_page.dart';
import 'screens/inactive_page.dart';
import 'login_page.dart'; // Import your login page
import 'screens/reporter.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int activeMemberCount = 0;
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentImageIndex = 0;
  late Timer _timer;
  String _userName = ""; // Variable to hold user's name
  bool isAdmin = false; // Variable to check if the user is an admin
  bool _isMounted = false;

  final List<String> _imagePaths = [
    'assets/image2.jpg',
    'assets/background.jpg',
    'assets/background1.jpg',
    'assets/background 2.jpg',
    'assets/image3.jpg',
    'assets/image.jpg',
    'assets/image2.jpg',
    'assets/image5.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _checkAuthentication();
    _fetchActiveMembersCount();
    _startSlideshow();
    _fetchUserName(); // Fetch the user's name and role
  }

  void _startSlideshow() {
    _timer = Timer.periodic(const Duration(seconds: 180), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _imagePaths.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _isMounted = false;
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    User? user = _auth.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Future<void> _fetchUserName() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final userRef = FirebaseDatabase.instance
          .ref("members/${user.email!.replaceAll('.', '_')}");

      final snapshot = await userRef.once();

      if (snapshot.snapshot.exists) {
        if (_isMounted) {
          // Check if still mounted
          setState(() {
            _userName = snapshot.snapshot.child('name').value as String;
            isAdmin =
                snapshot.snapshot.child('role').value as String == 'admin';
          });
        }
      } else {
        print("User data does not exist.");
      }
    } else {
      print("No user is currently signed in.");
    }
  }

  Future<void> _fetchActiveMembersCount() async {
    try {
      final DatabaseEvent event = await _firebaseService.getActiveMembers();
      if (event.snapshot.value != null) {
        final activeMembersMap = event.snapshot.value as Map<dynamic, dynamic>;
        if (_isMounted) {
          // Check if still mounted
          setState(() {
            activeMemberCount = activeMembersMap.length;
          });
        }
      } else {
        if (_isMounted) {
          // Check if still mounted
          setState(() {
            activeMemberCount = 0;
          });
        }
      }
    } catch (e) {
      print('Error fetching active members: $e');
      if (_isMounted) {
        // Check if still mounted
        setState(() {
          activeMemberCount = 0;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 40),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurpleAccent,
                shadows: [
                  Shadow(
                      color: Colors.red, offset: Offset(1, 1), blurRadius: 3),
                  Shadow(
                      color: Colors.blue,
                      offset: Offset(-1, -1),
                      blurRadius: 3),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Show user name at the top right
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _userName.isNotEmpty
                  ? _userName
                  : "User", // Fallback if user name is empty
              style: TextStyle(
                  color: const Color.fromARGB(255, 225, 68, 68),
                  fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchActiveMembersCount, // Refresh member count
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _imagePaths[_currentImageIndex],
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildMainCard(activeMemberCount),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildHorizontalScrollPages(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(int activeCount) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: const EdgeInsets.all(15),
        width: MediaQuery.of(context).size.width * 0.75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white.withOpacity(0.135),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Active Members',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              '$activeCount',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // Build the horizontal scrolling pages
  Widget _buildHorizontalScrollPages() {
    return PageView(
      scrollDirection: Axis.horizontal,
      children: [
        _buildButtonRow(),
        _buildReporterButton(), // Add the reporter button here
      ],
    );
  }

  Widget _buildButtonRow() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isAdmin)
              _buildButtonCard('Register', Icons.app_registration, () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RegisterPage(
                      memberId: '',
                      member: {},
                    ),
                  ),
                );
              }),
            const SizedBox(width: 10),
            _buildButtonCard(
              'Active Members ($activeMemberCount)',
              Icons.people,
              () {
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (context) => const ActivePage(),
                  ),
                )
                    .then((_) {
                  _fetchActiveMembersCount(); // Refresh count after returning
                });
              },
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.blue),
              onPressed: _fetchActiveMembersCount, // Immediate refresh
              tooltip: 'Refresh Active Members Count',
            ),
          ],
        ),
        const SizedBox(height: 10), // Add spacing between rows
        _buildButtonCard('Inactive Members', Icons.cancel, () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const InactivePage(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReporterButton() {
    return Center(
      child: _buildButtonCard('Reporter', Icons.report, () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReporterPage(),
          ),
        );
      }),
    );
  }

  Widget _buildButtonCard(String label, IconData icon, VoidCallback onPressed) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 8,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 150,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.blueAccent.withOpacity(0.8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
