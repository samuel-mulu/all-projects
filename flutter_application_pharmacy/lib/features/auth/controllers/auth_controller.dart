import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signIn(email, password);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Login failed');
    } catch (e) {
      _setError('An unexpected error occurred');
    }
    _setLoading(false);
    return false;
  }

  Future<bool> createAccount(String name, String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final credential = await _authService.signUp(email, password);
      if (credential?.user != null) {
        await credential!.user!.updateDisplayName(name);
        // Additional user data can be saved here if needed
      }
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Account creation failed');
    } catch (e) {
      _setError('An unexpected error occurred');
    }
    _setLoading(false);
    return false;
  }

  Future<void> logout() async {
    await _authService.signOut();
  }
}
