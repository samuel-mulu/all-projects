// login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // Import the database package
import 'home_page.dart'; // Import the home page
import 'main.dart'; // Import main to access RoleBasedRouter
import 'utils/reliable_text_widget.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false; // Show loading while signing in
  String? _errorMessage; // To hold error messages
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Reset error message
    });

    try {
      // Ensure persistence is enabled (should already be set in main.dart)
      if (!kIsWeb) {
        // For mobile, persistence is automatic
        print('Mobile platform - Auth persistence is automatic');
      }
      
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Verify the user is actually signed in
      if (userCredential.user != null) {
        print('Login successful for user: ${userCredential.user!.email}');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Login successful! Redirecting..."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
          
          // Clear the form
          _emailController.clear();
          _passwordController.clear();
          
          // Force a small delay to ensure the auth state is updated
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // Always force navigation after successful login to ensure it works
          if (mounted) {
            print('Login - Navigating to dashboard');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const RoleBasedRouter(),
              ),
            );
          }
        }
      } else {
        throw Exception('User credential is null after successful login');
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      // Handle specific Firebase Auth errors
      if (mounted) {
      setState(() {
          _errorMessage = _getFirebaseErrorMessage(e.code);
      });
      }
    } catch (e) {
      print('General Error: $e');
      // Handle any other errors
      if (mounted) {
      setState(() {
        _errorMessage = "An error occurred. Please try again.";
      });
      }
    } finally {
      if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  }

  String _getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Login failed. Please try again.';
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/background1.jpg', // Path to your background image
              fit: BoxFit.cover,
            ),
          ),
          // Overlay content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.8), // Semi-transparent background
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.email, color: Colors.deepPurpleAccent),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.lock, color: Colors.deepPurpleAccent),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 10),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ScaleTransition(
                              scale: _animation,
                              child: ElevatedButton(
                                onPressed: () {
                                  _animationController.forward().then((_) {
                                    _animationController.reverse();
                                    _signIn();
                                  });
                                },
                                child: const Text('Sign In'),
                                style: ElevatedButton.styleFrom(
                                  elevation: 5,
                                  backgroundColor: Colors.deepPurpleAccent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => _resetPassword(),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: Colors.deepPurpleAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    String email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email address.")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send reset email: $e")),
      );
    }
  }
}
