import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ProfitAnalyticsController extends ChangeNotifier {
  final DatabaseReference _salesRef = FirebaseDatabase.instance.ref('sales');
  final DatabaseReference _medicationsRef = FirebaseDatabase.instance.ref('medications');
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  double _grossProfit = 0.0;
  double get grossProfit => _grossProfit;
  
  double _netProfit = 0.0;
  double get netProfit => _netProfit;

  final List<TextEditingController> dynamicControllers = [];
  final List<String> dynamicLabels = [];

  ProfitAnalyticsController() {
    calculateProfit();
  }

  @override
  void dispose() {
    for (var controller in dynamicControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void addExtraCost() {
    dynamicControllers.add(TextEditingController());
    dynamicLabels.add('Extra Cost ${dynamicControllers.length}');
    calculateProfit();
    notifyListeners();
  }

  void removeExtraCost(int index) {
    dynamicControllers[index].dispose();
    dynamicControllers.removeAt(index);
    dynamicLabels.removeAt(index);
    calculateProfit();
    notifyListeners();
  }

  Future<void> calculateProfit() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    double totalSellingPrice = 0.0;
    double totalPurchasedPrice = 0.0;

    try {
      final salesSnapshot = await _salesRef.get();
      if (salesSnapshot.exists) {
        for (final sale in salesSnapshot.children) {
          final rawDrugName = sale.child('drugName').value;
          final drugName = rawDrugName?.toString();
          
          final rawQty = sale.child('quantitySold').value;
          final quantitySold = int.tryParse(rawQty?.toString() ?? '0') ?? 0;
          
          final sellingPrice = _toDouble(sale.child('sellingPrice').value) ?? 0.0;

          if (drugName == null || quantitySold <= 0) continue;

          totalSellingPrice += sellingPrice;

          // Fetch purchase price for this drug
          final medicationSnapshot = await _medicationsRef.orderByChild('drug').equalTo(drugName).get();
          if (medicationSnapshot.exists) {
            final medication = medicationSnapshot.children.first;
            final purchasedPrice = _toDouble(medication.child('purchasedPrice').value) ?? 0.0;
            totalPurchasedPrice += purchasedPrice * quantitySold;
          }
        }
      }

      _grossProfit = totalSellingPrice - totalPurchasedPrice;
      
      double totalExtraCosts = 0.0;
      for (final controller in dynamicControllers) {
        totalExtraCosts += double.tryParse(controller.text) ?? 0.0;
      }
      
      _netProfit = _grossProfit - totalExtraCosts;
    } catch (e) {
      _errorMessage = 'Failed to calculate profit analytics.';
      debugPrint('Profit Calculation Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
