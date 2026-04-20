import 'package:flutter/material.dart';

import '../../../services/firebase_service.dart';
import '../../../core/utils/medication_status.dart';
import '../../../services/app_settings_service.dart';

class DashboardController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> get medications => _medications;

  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> get sales => _sales;

  DashboardController() {
    AppSettingsService.instance.addListener(_handleSettingsChanged);
    loadData();
  }

  @override
  void dispose() {
    AppSettingsService.instance.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final results = await Future.wait([
        _firebaseService.fetchMedications(),
        _firebaseService.fetchSales(),
      ]);
      
      _medications = results[0];
      _sales = results[1];
    } catch (e) {
      _errorMessage = 'Failed to load dashboard data.';
      debugPrint('Dashboard Load Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> get approvedMedications => _medications
      .where((medication) => isMedicationApproved(medication))
      .toList();

  List<Map<String, dynamic>> get stockAlertMedications => approvedMedications
      .where((medication) => isMedicationStockAlert(medication))
      .toList();

  List<Map<String, dynamic>> get expiryAlertMedications => approvedMedications
      .where((medication) => isMedicationExpiryAlert(medication))
      .toList();

  int get stockAlertCount => stockAlertMedications.length;

  int get expiryAlertCount => expiryAlertMedications.length;

  int get approvedInventoryCount => approvedMedications.length;

  int get stockAlertThreshold => AppSettingsService.instance.stockAlertThreshold;

  int get expiryAlertDays => AppSettingsService.instance.expiryAlertDays;

  int get todaySalesCount {
    final today = DateTime.now().toIso8601String().split('T').first;
    return _sales.where((sale) => (sale['date'] ?? '').toString().startsWith(today)).length;
  }

  List<Map<String, dynamic>> get recentActivity => _sales.take(5).toList();

  void _handleSettingsChanged() {
    notifyListeners();
  }
}
