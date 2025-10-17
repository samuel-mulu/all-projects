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
import 'screens/signup_page.dart'; // Import the signup page
import 'screens/membership_management_page.dart'; // Import membership management page
import 'utils/reliable_text_widget.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key, 
    required this.title,
    required this.userRole,
    required this.userName,
  });

  final String title;
  final String userRole;
  final String userName;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int activeMemberCount = 0;
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentImageIndex = 0;
  late Timer _timer;
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
    _fetchActiveMembersCount();
    _startSlideshow();
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


  // Getter methods for role and user name
  bool get isAdmin => widget.userRole == 'admin';
  String get _userName => widget.userName;

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
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: isMobile ? 30 : 40),
            SizedBox(width: isMobile ? 4 : 8),
            Flexible(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 24,
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
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Show user name at the top right (hide on very small screens)
          if (screenWidth > 400)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8.0 : 16.0),
              child: Center(
                child: Text(
                  _userName.isNotEmpty
                      ? _userName
                      : "User", // Fallback if user name is empty
                  style: TextStyle(
                      color: const Color.fromARGB(255, 225, 68, 68),
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 12 : 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          // Only show signup button for non-admin users
          if (!isAdmin)
            IconButton(
              icon: Icon(Icons.person_add, size: isMobile ? 20 : 24),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SignupPage(),
                  ),
                );
              },
              tooltip: 'Create New Account',
            ),
          // Only show membership management for non-admin users
          if (!isAdmin)
            IconButton(
              icon: Icon(Icons.settings, size: isMobile ? 20 : 24),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MembershipManagementPage(),
                  ),
                );
              },
              tooltip: 'Manage Memberships',
            ),
          IconButton(
            icon: Icon(Icons.refresh, size: isMobile ? 20 : 24),
            onPressed: _fetchActiveMembersCount, // Refresh member count
          ),
          IconButton(
            icon: Icon(Icons.logout, size: isMobile ? 20 : 24),
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
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 15),
        width: MediaQuery.of(context).size.width * (isMobile ? 0.85 : 0.75),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white.withOpacity(0.135),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Active Members',
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isMobile ? 3 : 5),
            Text(
              '$activeCount',
              style: TextStyle(
                fontSize: isMobile ? 28 : 36,
                fontWeight: FontWeight.w600,
              ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildButtonCard('Inactive Members', Icons.cancel, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const InactivePage(),
                ),
              );
            }),
            // Only show Create Account button for non-admin users
            if (!isAdmin) ...[
              const SizedBox(width: 10),
              _buildButtonCard('Create Account', Icons.person_add, () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SignupPage(),
                  ),
                );
              }),
            ],
          ],
        ),
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
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    
    // Calculate responsive sizes
    double cardWidth = isMobile ? (screenWidth * 0.4) : 150;
    double cardHeight = isMobile ? 100 : 120;
    double iconSize = isMobile ? 35 : 50;
    double fontSize = isMobile ? 12 : 16;
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 8,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.blueAccent.withOpacity(0.8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: Colors.white),
              SizedBox(height: isMobile ? 5 : 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
