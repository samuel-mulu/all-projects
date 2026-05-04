import 'package:flutter/material.dart';

import '../../../core/utils/medication_status.dart';
import '../../../services/firebase_service.dart';
import '../../../services/app_settings_service.dart';

class InventoryController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> get medications => _medications;

  String _selectedFilter = 'All';
  String get selectedFilter => _selectedFilter;

  String _selectedSort = 'name';
  String get selectedSort => _selectedSort;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  InventoryController() {
    AppSettingsService.instance.addListener(_handleSettingsChanged);
    loadData();
  }

  @override
  void dispose() {
    AppSettingsService.instance.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  List<String> get filterTypes {
    final types = approvedMedications
        .map((medication) =>
            (medication['medicationType'] ?? '').toString().trim())
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ['All', ...types];
  }

  static const Map<String, String> sortOptions = {
    'name': 'Name',
    'stock': 'Stock',
    'expiry': 'Expiry',
  };

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    _medications = await _firebaseService.fetchMedications();
    if (!filterTypes.contains(_selectedFilter)) {
      _selectedFilter = 'All';
    }
    _isLoading = false;
    notifyListeners();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setSort(String sort) {
    _selectedSort = sort;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Map<String, dynamic>> get approvedMedications =>
      _medications.where(isApproved).toList();

  List<Map<String, dynamic>> get pendingMedications =>
      _medications.where(isPending).toList();

  int get approvedCount => approvedMedications.length;

  int get pendingCount => pendingMedications.length;

  int get lowStockCount =>
      approvedMedications.where(isMedicationStockAlert).length;

  int get expiryAlertCount =>
      approvedMedications.where(isMedicationExpiryAlert).length;

  bool isPending(Map<String, dynamic> medication) =>
      isMedicationPending(medication);

  bool isApproved(Map<String, dynamic> medication) =>
      isMedicationApproved(medication);

  Future<bool> approveMedication(String medicationId) async {
    return _updateMedicationStatus(medicationId, 'approved');
  }

  Future<bool> rejectMedication(String medicationId) async {
    return _updateMedicationStatus(medicationId, 'rejected');
  }

  Future<bool> _updateMedicationStatus(
      String medicationId, String status) async {
    final success =
        await _firebaseService.updateMedicationStatus(medicationId, status);
    if (!success) {
      return false;
    }

    final medicationIndex =
        _medications.indexWhere((item) => item['id'] == medicationId);
    if (medicationIndex != -1) {
      _medications[medicationIndex] = {
        ..._medications[medicationIndex],
        'status': status,
      };
    }
    notifyListeners();
    return true;
  }

  List<Map<String, dynamic>> get filteredMedications {
    final query = _searchQuery.trim().toLowerCase();
    final result = approvedMedications.where((medication) {
      final drug = (medication['drug'] ?? '').toString().toLowerCase();
      final brand = (medication['brandName'] ?? '').toString().toLowerCase();
      final type = (medication['medicationType'] ?? '').toString();

      final matchesFilter = _selectedFilter == 'All' ||
          type.toLowerCase() == _selectedFilter.toLowerCase();
      final matchesQuery =
          query.isEmpty || drug.contains(query) || brand.contains(query);

      return matchesFilter && matchesQuery;
    }).toList();

    switch (_selectedSort) {
      case 'stock':
        result.sort((a, b) =>
            parseMedicationQuantity(a).compareTo(parseMedicationQuantity(b)));
        break;
      case 'expiry':
        result.sort((a, b) {
          final first = parseMedicationExpiry(a) ?? DateTime(2999);
          final second = parseMedicationExpiry(b) ?? DateTime(2999);
          return first.compareTo(second);
        });
        break;
      case 'name':
      default:
        result.sort((a, b) => (a['drug'] ?? '')
            .toString()
            .compareTo((b['drug'] ?? '').toString()));
    }

    return result;
  }

  void _handleSettingsChanged() {
    notifyListeners();
  }
}
