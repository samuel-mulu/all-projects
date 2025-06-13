import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'screens/register_page.dart';
import 'screens/active_page.dart';
import 'screens/inactive_page.dart';
import 'login_page.dart';
import 'screens/sales_report_page.dart';
import 'screens/pending_tasks_page.dart';
import 'screens/seller_page.dart';
import 'screens/profit_checker_page.dart'; // Import the ProfitCheckerPage

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentImageIndex = 0;
  late Timer _timer;

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
    _checkAuthentication();
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
        title: Text(
          '2MS DEVELOPERS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color.fromARGB(255, 231, 118, 118),
            letterSpacing: 2, // Add some spacing for effect
            shadows: [
              // Neon Glow effect
              Shadow(
                  color: Colors.greenAccent,
                  offset: Offset(0, 0),
                  blurRadius: 10),
              Shadow(
                  color: Colors.blueAccent,
                  offset: Offset(0, 0),
                  blurRadius: 10),
              Shadow(
                  color: Colors.purpleAccent,
                  offset: Offset(0, 0),
                  blurRadius: 10),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ImageFiltered(
              // Applying a color filter to adjust the brightness of the image
              imageFilter: ImageFilter.blur(
                  sigmaX: 5, sigmaY: 5), // Adjust blur effect as needed
              child: Image.asset(
                _imagePaths[_currentImageIndex],
                fit: BoxFit.cover, // Ensures image covers the whole screen
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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

  // Build the horizontal scrolling pages
  Widget _buildHorizontalScrollPages() {
    return PageView(
      scrollDirection: Axis.horizontal,
      children: [
        _buildButtonRow(), // Button row with 4 buttons in the first slide
        _buildSecondSlide(), // Second slide with 4 buttons
      ],
    );
  }

  // Build the row of buttons (4 buttons per slide)
  Widget _buildButtonRow() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Adaptive spacing
          children: [
            _buildButtonCard('Add Medication', Icons.medical_services, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RegisterPage(medicationId: ''),
                ),
              );
            }),
            _buildButtonCard('Inventory Management', Icons.inventory, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PendingTasksPage(),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 10), // Spacing between rows
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildButtonCard('Active Prescriptions', Icons.assignment_turned_in,
                () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ActivePage(),
                ),
              );
            }),
            _buildButtonCard('Supplier Management', Icons.local_shipping, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SellerPage(),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondSlide() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildButtonCard('Inactive Prescriptions', Icons.assignment_late,
                () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const InactivePage(),
                ),
              );
            }),
            const SizedBox(width: 10),
            _buildButtonCard('Sales Overview', Icons.bar_chart, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SalesReportPage(),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildButtonCard('Profit Analytics', Icons.pie_chart, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfitCheckerPage(),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // Widget for the individual button cards
  Widget _buildButtonCard(String label, IconData icon, VoidCallback onPressed) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onPressed,
        splashColor: Colors.deepPurpleAccent,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          constraints: BoxConstraints(
            // Ensure width adapts dynamically to the label length
            minWidth: MediaQuery.of(context).size.width * 0.3,
            maxWidth: MediaQuery.of(context).size.width * 0.4,
          ),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16, // Ensure readability
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.visible, // Ensure full label display
              ),
            ],
          ),
        ),
      ),
    );
  }
}
