import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/firebase_service.dart';

class SellMedicationController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  List<Map<String, dynamic>> _availableMedications = [];
  List<Map<String, dynamic>> get availableMedications => _availableMedications;
  
  Map<String, dynamic>? _selectedMedication;
  Map<String, dynamic>? get selectedMedication => _selectedMedication;
  
  int? _quantityAvailable;
  int? get quantityAvailable => _quantityAvailable;
  
  String _paymentMethod = 'Cash';
  String get paymentMethod => _paymentMethod;
  
  String _searchQuery = '';

  SellMedicationController() {
    fetchAvailableMedications();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  List<Map<String, dynamic>> get filteredMedications {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _availableMedications;
    return _availableMedications.where((med) {
      final name = (med['drug'] ?? '').toString().toLowerCase();
      final brand = (med['brandName'] ?? '').toString().toLowerCase();
      return name.contains(query) || brand.contains(query);
    }).toList();
  }

  Future<void> fetchAvailableMedications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      var medications = await _firebaseService.fetchMedications();
      // Only show medications that are active or completed
      _availableMedications = medications.where((med) => 
        med['status'] == 'completed' || med['status'] == 'active'
      ).toList();
    } catch (e) {
      _errorMessage = 'Failed to load medications.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectMedication(Map<String, dynamic> medication) async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _selectedMedication = medication;
      _quantityAvailable = await _firebaseService.fetchDrugQuantity((medication['drug'] ?? '').toString());
    } catch (e) {
      _errorMessage = 'Failed to fetch stock for ${medication['drug']}.';
      _selectedMedication = null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void clearSelection() {
    _selectedMedication = null;
    _quantityAvailable = null;
    _paymentMethod = 'Cash';
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> sellMedication({
    required int quantityToSell,
    required String reason,
  }) async {
    if (_selectedMedication == null || _quantityAvailable == null) return false;
    if (quantityToSell > _quantityAvailable!) {
      _errorMessage = 'Not enough stock available.';
      notifyListeners();
      return false;
    }
    
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final drugName = (_selectedMedication!['drug'] ?? '').toString();
      final unitPrice = double.tryParse((_selectedMedication!['sellingPrice'] ?? 0).toString()) ?? 0;
      final totalSellingPrice = quantityToSell * unitPrice;
      final newQuantity = _quantityAvailable! - quantityToSell;

      await _firebaseService.updateDrugQuantity(drugName, newQuantity);
      await _firebaseService.recordSale(
        drugName,
        quantityToSell,
        totalSellingPrice,
        _paymentMethod,
        DateFormat('yyyy-MM-dd').format(DateTime.now()),
        reason: _paymentMethod == 'Credit' ? reason : '',
      );
      
      _quantityAvailable = newQuantity;
      return true;
    } catch (e) {
      _errorMessage = 'An error occurred while recording the sale.';
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
