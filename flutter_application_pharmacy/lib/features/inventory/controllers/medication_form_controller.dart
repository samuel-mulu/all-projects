import 'package:flutter/material.dart';
import '../../../services/firebase_service.dart';

class MedicationFormController extends ChangeNotifier {
  final _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<bool> saveMedication({
    String? id,
    required Map<String, dynamic> data,
  }) async {
    _errorMessage = null;
    _setLoading(true);
    try {
      final success = await _firebaseService.saveMedication(id: id, data: data);
      if (!success) {
        _errorMessage = 'Failed to save medication. Please check your connection.';
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<Map<String, dynamic>?> loadMedication(String id) async {
    _errorMessage = null;
    _setLoading(true);
    try {
      final data = await _firebaseService.fetchMedicationById(id);
      _setLoading(false);
      return data;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return null;
    }
  }
}
