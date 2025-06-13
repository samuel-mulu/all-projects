// login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // Import the database package
import 'home_page.dart'; // Import the home page

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

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Reset error message
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Navigate to the home page on successful sign-in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const MyHomePage(title: 'Alpha gym')),
      );
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      setState(() {
        _errorMessage = e.message; // Set the error message
      });
    } catch (e) {
      // Handle any other errors
      setState(() {
        _errorMessage = "An error occurred. Please try again.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Sign-up method
  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password.")),
      );
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // After user is created, prompt for additional information
      _showSignUpDialog(userCredential.user!.email);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message; // Set the error message
      });
    } catch (e) {
      setState(() {
        _errorMessage = "An error occurred. Please try again.";
      });
    }
  }

  // Show dialog for additional user information
  void _showSignUpDialog(String? email) {
    final TextEditingController _nameController = TextEditingController();
    String selectedRole = 'user'; // Default role

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Complete Registration"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Name",
                ),
              ),
              DropdownButton<String>(
                value: selectedRole,
                items: <String>['user', 'admin']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedRole = newValue!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                // Save user information to the Realtime Database
                await _saveUserToDatabase(
                    email!, _nameController.text, selectedRole);
                Navigator.of(context).pop();
              },
              child: const Text("Register"),
            ),
          ],
        );
      },
    );
  }

  // Save user information to the Realtime Database
  Future<void> _saveUserToDatabase(
      String email, String name, String role) async {
    final userRef =
        FirebaseDatabase.instance.ref("members/${email.replaceAll('.', '_')}");
    await userRef.set({
      'role': role,
      'name': name,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Registration successful!")),
    );
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
                      // Add sign-up button
                      TextButton(
                        onPressed: () {
                          _signUp(); // Call the sign-up function
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(color: Colors.deepPurpleAccent),
                        ),
                      ),
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
