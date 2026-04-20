import 'package:flutter/material.dart';
import '../../../services/firebase_service.dart';

class ReportsController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> get sales => _sales;

  ReportsController() {
    loadReports();
  }

  Future<void> loadReports() async {
    _isLoading = true;
    notifyListeners();
    _sales = await _firebaseService.fetchSales();
    _isLoading = false;
    notifyListeners();
  }

  double get totalRevenue => _sales.fold<double>(0, (total, sale) {
    final amount = double.tryParse((sale['sellingPrice'] ?? 0).toString()) ?? 0;
    return total + amount;
  });

  int get creditSalesCount => _sales.where((sale) => (sale['paymentMethod'] ?? '').toString() == 'Credit').length;
}
