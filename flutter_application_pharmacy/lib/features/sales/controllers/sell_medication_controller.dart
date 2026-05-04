import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/sale_pricing.dart';
import '../../../core/utils/medication_status.dart';
import '../../../services/firebase_service.dart';

class SellMedicationController extends ChangeNotifier {
  SellMedicationController({Map<String, dynamic>? initialMedication})
      : _initialMedicationId = initialMedication?['id']?.toString(),
        _initialMedication = initialMedication {
    fetchAvailableMedications();
  }

  final FirebaseService _firebaseService = FirebaseService();
  final String? _initialMedicationId;
  final Map<String, dynamic>? _initialMedication;

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

  bool get hasLockedMedication => _initialMedicationId != null;

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
    if (query.isEmpty) {
      return _availableMedications;
    }

    return _availableMedications.where((medication) {
      final name = (medication['drug'] ?? '').toString().toLowerCase();
      final brand = (medication['brandName'] ?? '').toString().toLowerCase();
      return name.contains(query) || brand.contains(query);
    }).toList();
  }

  Future<void> fetchAvailableMedications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final medications = await _firebaseService.fetchMedications();
      _availableMedications = medications.where((medication) {
        final quantity = parseMedicationQuantity(medication);
        return isMedicationApproved(medication) &&
            !isMedicationExpired(medication) &&
            quantity > 0;
      }).toList();

      if (_initialMedicationId != null) {
        Map<String, dynamic>? selected;
        for (final medication in _availableMedications) {
          if (medication['id']?.toString() == _initialMedicationId) {
            selected = medication;
            break;
          }
        }

        final initialMedication = selected ?? _initialMedication;
        if (initialMedication != null) {
          _selectedMedication = initialMedication;
          _quantityAvailable = await _firebaseService.fetchMedicationQuantity(
            initialMedication['id'].toString(),
          );
        }
      }
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
      _quantityAvailable = await _firebaseService.fetchMedicationQuantity(
        medication['id'].toString(),
      );
    } catch (e) {
      _errorMessage = 'Failed to fetch stock for ${medication['drug']}.';
      _selectedMedication = null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void clearSelection() {
    if (hasLockedMedication) {
      return;
    }

    _selectedMedication = null;
    _quantityAvailable = null;
    _paymentMethod = 'Cash';
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> sellMedication({
    required int quantityToSell,
    required String reason,
    SalePriceAdjustmentType priceAdjustmentType = SalePriceAdjustmentType.none,
    double priceAdjustmentAmount = 0.0,
  }) async {
    if (_selectedMedication == null || _quantityAvailable == null) {
      return false;
    }

    final medicationId = (_selectedMedication!['id'] ?? '').toString();
    if (medicationId.isEmpty) {
      _errorMessage = 'This medication is missing its record ID.';
      notifyListeners();
      return false;
    }

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
      final baseUnitPrice =
          salePricingToDouble(_selectedMedication!['sellingPrice']);
      final purchaseUnitPrice =
          salePricingToDouble(_selectedMedication!['purchasedPrice']);
      final normalizedAdjustmentAmount =
          normalizeSaleAdjustmentAmount(priceAdjustmentAmount);
      final effectiveAdjustmentType = hasMeaningfulSaleAdjustment(
        adjustmentType: priceAdjustmentType,
        adjustmentAmount: normalizedAdjustmentAmount,
      )
          ? priceAdjustmentType
          : SalePriceAdjustmentType.none;
      final unitPrice = calculateSaleUnitPrice(
        baseUnitPrice: baseUnitPrice,
        adjustmentType: effectiveAdjustmentType,
        adjustmentAmount: normalizedAdjustmentAmount,
      );

      if (unitPrice < 0) {
        _errorMessage = 'Discount cannot reduce the selling price below zero.';
        return false;
      }

      final totalSellingPrice = quantityToSell * unitPrice;
      final newQuantity = _quantityAvailable! - quantityToSell;

      final quantityUpdated = await _firebaseService.updateMedicationQuantity(
        medicationId,
        newQuantity,
      );
      if (!quantityUpdated) {
        _errorMessage = 'Failed to update stock quantity.';
        return false;
      }

      final saleRecorded = await _firebaseService.recordSale(
        medicationId: medicationId,
        drugName: drugName,
        quantitySold: quantityToSell,
        baseUnitPrice: baseUnitPrice,
        purchaseUnitPrice: purchaseUnitPrice,
        unitPrice: unitPrice,
        totalSellingPrice: totalSellingPrice,
        priceAdjustmentType: effectiveAdjustmentType.storageValue,
        priceAdjustmentAmount: normalizedAdjustmentAmount,
        paymentMethod: _paymentMethod,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        reason: _paymentMethod == 'Credit' ? reason : '',
      );
      if (!saleRecorded) {
        _errorMessage = 'Failed to record the sale.';
        return false;
      }

      final updatedMedication = {
        ..._selectedMedication!,
        'quantity': newQuantity,
      };
      _selectedMedication = updatedMedication;
      _quantityAvailable = newQuantity;

      final medicationIndex = _availableMedications.indexWhere(
        (medication) => medication['id'] == medicationId,
      );
      if (medicationIndex != -1) {
        _availableMedications[medicationIndex] = updatedMedication;
      }

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
