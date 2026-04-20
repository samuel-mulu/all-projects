import 'package:flutter/material.dart';

import '../../../services/app_settings_service.dart';
import '../../../services/auth_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController() {
    AppSettingsService.instance.addListener(_handleSettingsChanged);
  }

  final AuthService _authService = AuthService();

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isSendingPasswordReset = false;
  bool get isSendingPasswordReset => _isSendingPasswordReset;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  PharmacyAlertSettings get settings => AppSettingsService.instance.settings;
  String get currentUserEmail => _authService.currentUser?.email ?? '';

  @override
  void dispose() {
    AppSettingsService.instance.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  Future<bool> saveAlertSettings({
    required int stockAlertThreshold,
    required int expiryAlertDays,
  }) async {
    if (stockAlertThreshold < 0 || expiryAlertDays < 0) {
      _errorMessage = 'Alert values must be zero or greater.';
      notifyListeners();
      return false;
    }

    _setSaving(true);
    _errorMessage = null;
    try {
      await AppSettingsService.instance.saveAlertSettings(
        stockAlertThreshold: stockAlertThreshold,
        expiryAlertDays: expiryAlertDays,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save settings.';
      notifyListeners();
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> applyRecommendedSettings() async {
    _setSaving(true);
    _errorMessage = null;
    try {
      await AppSettingsService.instance.applyRecommendedSettings();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to apply recommended settings.';
      notifyListeners();
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> sendPasswordResetEmail() async {
    if (currentUserEmail.isEmpty) {
      _errorMessage = 'No signed-in email was found for password reset.';
      notifyListeners();
      return false;
    }

    _isSendingPasswordReset = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.resetPassword(currentUserEmail);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send the password reset email.';
      notifyListeners();
      return false;
    } finally {
      _isSendingPasswordReset = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _handleSettingsChanged() {
    notifyListeners();
  }
}
