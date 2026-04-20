import 'package:flutter/material.dart';
import '../../../services/firebase_service.dart';
import '../../../core/utils/medication_status.dart';

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

  final List<String> filterTypes = const [
    'All',
    'Tablets',
    'Syrup',
    'Cream',
    'Injectable',
  ];

  InventoryController() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    _medications = await _firebaseService.fetchMedications();
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

  List<Map<String, dynamic>> get filteredMedications {
    final query = _searchQuery.trim().toLowerCase();
    final result = _medications.where((medication) {
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
        result.sort((a, b) => parseMedicationQuantity(a).compareTo(parseMedicationQuantity(b)));
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
        result.sort((a, b) => (a['drug'] ?? '').toString().compareTo((b['drug'] ?? '').toString()));
    }

    return result;
  }
}
