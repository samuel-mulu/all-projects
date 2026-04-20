import 'package:flutter/material.dart';
import '../../../services/firebase_service.dart';
import '../../../core/utils/medication_status.dart';

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
    loadData();
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

  int get lowStockCount => _medications
      .where((medication) => parseMedicationQuantity(medication) <= 5)
      .length;

  int get expiringSoonCount => _medications.where((medication) {
        final expiry = parseMedicationExpiry(medication);
        if (expiry == null) return false;
        final difference = expiry.difference(DateTime.now()).inDays;
        return difference >= 0 && difference <= 30;
      }).length;

  int get todaySalesCount {
    final today = DateTime.now().toIso8601String().split('T').first;
    return _sales.where((sale) => (sale['date'] ?? '').toString().startsWith(today)).length;
  }

  List<Map<String, dynamic>> get recentActivity => _sales.take(5).toList();
}
