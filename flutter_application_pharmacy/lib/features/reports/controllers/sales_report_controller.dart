import 'package:ethiopian_calendar/ethiopian_date_converter.dart';
import 'package:flutter/material.dart';
import '../../../services/firebase_service.dart';

class SalesReportController extends ChangeNotifier {
  final FirebaseService _firebaseService;
  
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _filteredSales = [];
  List<Map<String, dynamic>> get filteredSales => _filteredSales;
  
  String _selectedMonth = 'All';
  String get selectedMonth => _selectedMonth;

  static const Map<int, String> ethiopianMonths = {
    1: "Meskerem", 2: "Tikimt", 3: "Hidar", 4: "Tahsas", 5: "Tir", 
    6: "Yekatit", 7: "Megabit", 8: "Miyazya", 9: "Ginbot", 10: "Sene", 
    11: "Hamle", 12: "Nehase",
  };

  SalesReportController({FirebaseService? firebaseService})
      : _firebaseService = firebaseService ?? FirebaseService() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _allSales = await _firebaseService.fetchSales();
      _filterSales();
    } catch (e) {
      _errorMessage = 'Failed to load sales data.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setMonth(String month) {
    _selectedMonth = month;
    _filterSales();
    notifyListeners();
  }

  void _filterSales() {
    if (_selectedMonth == 'All') {
      _filteredSales = _allSales;
    } else {
      _filteredSales = _allSales.where((sale) {
        final dateStr = (sale['date'] ?? '').toString();
        if (dateStr.isEmpty) return false;
        final date = DateTime.tryParse(dateStr);
        if (date == null) return false;
        final ethDate = EthiopianDateConverter.convertToEthiopianDate(date);
        return ethiopianMonths[ethDate.month] == _selectedMonth;
      }).toList();
    }
  }

  double get totalRevenue => _filteredSales.fold(0.0, (sum, sale) {
    return sum + (double.tryParse(sale['sellingPrice']?.toString() ?? '0') ?? 0.0);
  });

  String formatToEthiopian(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return 'N/A';
    final ethDate = EthiopianDateConverter.convertToEthiopianDate(date);
    return '${ethDate.day} ${ethiopianMonths[ethDate.month]} ${ethDate.year}';
  }
}
