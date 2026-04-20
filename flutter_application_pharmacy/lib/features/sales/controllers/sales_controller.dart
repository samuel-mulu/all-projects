import 'package:flutter/material.dart';
import '../../../services/firebase_service.dart';

class SalesController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> get sales => _sales;

  SalesController() {
    loadSales();
  }

  Future<void> loadSales() async {
    _isLoading = true;
    notifyListeners();
    _sales = await _firebaseService.fetchSales();
    _isLoading = false;
    notifyListeners();
  }

  double get todayRevenue {
    final today = DateTime.now().toIso8601String().split('T').first;
    return _sales.where((sale) => sale['date'] == today).fold<double>(0, (total, sale) {
      final amount = double.tryParse((sale['sellingPrice'] ?? 0).toString()) ?? 0;
      return total + amount;
    });
  }

  int get todayTransactions {
    final today = DateTime.now().toIso8601String().split('T').first;
    return _sales.where((sale) => sale['date'] == today).length;
  }
}
