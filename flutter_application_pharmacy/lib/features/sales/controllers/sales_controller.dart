import 'package:flutter/material.dart';

import '../../../core/utils/medication_status.dart';
import '../../../services/app_settings_service.dart';
import '../../../services/firebase_service.dart';

class SalesController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> get sales => _sales;

  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> get medications => _medications;

  String _selectedFilter = 'All';
  String get selectedFilter => _selectedFilter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  SalesController() {
    AppSettingsService.instance.addListener(_handleSettingsChanged);
    loadData();
  }

  @override
  void dispose() {
    AppSettingsService.instance.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  List<String> get filterTypes {
    final types = _medications
        .map((medication) => (medication['medicationType'] ?? '').toString().trim())
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ['All', ...types];
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _sales = await _firebaseService.fetchSales();
    _medications = (await _firebaseService.fetchMedications()).where((medication) {
      final quantity = parseMedicationQuantity(medication);
      return isMedicationApproved(medication) &&
          !isMedicationExpired(medication) &&
          quantity > 0;
    }).toList();

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

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Map<String, dynamic>> get filteredMedications {
    final query = _searchQuery.trim().toLowerCase();
    final result = _medications.where((medication) {
      final drug = (medication['drug'] ?? '').toString().toLowerCase();
      final brand = (medication['brandName'] ?? '').toString().toLowerCase();
      final type = (medication['medicationType'] ?? '').toString().trim().toLowerCase();

      final matchesFilter =
          _selectedFilter == 'All' || type == _selectedFilter.toLowerCase();
      final matchesQuery =
          query.isEmpty || drug.contains(query) || brand.contains(query);

      return matchesFilter && matchesQuery;
    }).toList();

    result.sort((first, second) {
      return (first['drug'] ?? '').toString().compareTo(
            (second['drug'] ?? '').toString(),
          );
    });

    return result;
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

  void _handleSettingsChanged() {
    notifyListeners();
  }
}
