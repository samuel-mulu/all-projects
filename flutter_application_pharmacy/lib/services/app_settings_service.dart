import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PharmacyAlertSettings {
  const PharmacyAlertSettings({
    required this.stockAlertThreshold,
    required this.expiryAlertDays,
  });

  final int stockAlertThreshold;
  final int expiryAlertDays;

  PharmacyAlertSettings copyWith({
    int? stockAlertThreshold,
    int? expiryAlertDays,
  }) {
    return PharmacyAlertSettings(
      stockAlertThreshold: stockAlertThreshold ?? this.stockAlertThreshold,
      expiryAlertDays: expiryAlertDays ?? this.expiryAlertDays,
    );
  }
}

class AppSettingsService extends ChangeNotifier {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  static const int recommendedStockAlertThreshold = 100;
  static const int recommendedExpiryAlertDays = 180;

  static const String _stockAlertThresholdKey = 'stock_alert_threshold';
  static const String _expiryAlertDaysKey = 'expiry_alert_days';

  PharmacyAlertSettings _settings = const PharmacyAlertSettings(
    stockAlertThreshold: recommendedStockAlertThreshold,
    expiryAlertDays: recommendedExpiryAlertDays,
  );

  SharedPreferences? _preferences;

  PharmacyAlertSettings get settings => _settings;
  int get stockAlertThreshold => _settings.stockAlertThreshold;
  int get expiryAlertDays => _settings.expiryAlertDays;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _settings = PharmacyAlertSettings(
      stockAlertThreshold: _preferences?.getInt(_stockAlertThresholdKey) ??
          recommendedStockAlertThreshold,
      expiryAlertDays:
          _preferences?.getInt(_expiryAlertDaysKey) ?? recommendedExpiryAlertDays,
    );
  }

  Future<void> saveAlertSettings({
    required int stockAlertThreshold,
    required int expiryAlertDays,
  }) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;

    await preferences.setInt(_stockAlertThresholdKey, stockAlertThreshold);
    await preferences.setInt(_expiryAlertDaysKey, expiryAlertDays);

    _settings = PharmacyAlertSettings(
      stockAlertThreshold: stockAlertThreshold,
      expiryAlertDays: expiryAlertDays,
    );
    notifyListeners();
  }

  Future<void> applyRecommendedSettings() async {
    await saveAlertSettings(
      stockAlertThreshold: recommendedStockAlertThreshold,
      expiryAlertDays: recommendedExpiryAlertDays,
    );
  }
}
