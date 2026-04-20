import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/firebase_service.dart';

enum ReportPeriod { daily, monthly }

class SalesReportController extends ChangeNotifier {
  SalesReportController({FirebaseService? firebaseService})
      : _firebaseService = firebaseService ?? FirebaseService() {
    loadData();
  }

  final FirebaseService _firebaseService;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isRecordingExpense = false;
  bool get isRecordingExpense => _isRecordingExpense;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _filteredSales = [];
  List<Map<String, dynamic>> get filteredSales => _filteredSales;

  List<Map<String, dynamic>> _allExpenses = [];
  List<Map<String, dynamic>> _filteredExpenses = [];
  List<Map<String, dynamic>> get filteredExpenses => _filteredExpenses;

  ReportPeriod _selectedPeriod = ReportPeriod.daily;
  ReportPeriod get selectedPeriod => _selectedPeriod;

  DateTime _selectedDate = _dateOnly(DateTime.now());
  DateTime get selectedDate => _selectedDate;

  String _selectedPaymentFilter = 'All';
  String get selectedPaymentFilter => _selectedPaymentFilter;

  static const List<String> paymentFilters = [
    'All',
    'Cash',
    'Credit',
    'Mobile Banking',
  ];

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _firebaseService.fetchSales(),
        _firebaseService.fetchExpenses(),
      ]);
      _allSales = results[0];
      _allExpenses = results[1];
      _filterReportData();
    } catch (e) {
      _errorMessage = 'Failed to load report data.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setPeriod(ReportPeriod period) {
    if (_selectedPeriod == period) {
      return;
    }

    _selectedPeriod = period;
    _filterReportData();
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = _dateOnly(date);
    _filterReportData();
    notifyListeners();
  }

  void setPaymentFilter(String filter) {
    if (_selectedPaymentFilter == filter) {
      return;
    }

    _selectedPaymentFilter = filter;
    _filterReportData();
    notifyListeners();
  }

  Future<bool> recordExpense({
    required double amount,
    required String reason,
    required String paymentMethod,
    required DateTime date,
  }) async {
    _isRecordingExpense = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _firebaseService.recordExpense(
        amount: amount,
        reason: reason,
        paymentMethod: paymentMethod,
        date: DateFormat('yyyy-MM-dd').format(date),
      );

      if (!success) {
        _errorMessage = 'Failed to record expense.';
        return false;
      }

      await loadData();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to record expense.';
      return false;
    } finally {
      _isRecordingExpense = false;
      notifyListeners();
    }
  }

  void goToPreviousPeriod() {
    final previousDate = _selectedPeriod == ReportPeriod.daily
        ? _selectedDate.subtract(const Duration(days: 1))
        : DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    setSelectedDate(previousDate);
  }

  void goToNextPeriod() {
    if (!canMoveToNextPeriod) {
      return;
    }

    final nextDate = _selectedPeriod == ReportPeriod.daily
        ? _selectedDate.add(const Duration(days: 1))
        : DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    setSelectedDate(nextDate);
  }

  bool get canMoveToNextPeriod {
    final today = _dateOnly(DateTime.now());
    if (_selectedPeriod == ReportPeriod.daily) {
      return _selectedDate.isBefore(today);
    }

    return _selectedDate.year < today.year ||
        (_selectedDate.year == today.year &&
            _selectedDate.month < today.month);
  }

  String get selectedPeriodLabel {
    if (_selectedPeriod == ReportPeriod.daily) {
      return DateFormat('EEE, dd MMM yyyy').format(_selectedDate);
    }
    return DateFormat('MMMM yyyy').format(_selectedDate);
  }

  double get periodRevenue => _filteredSales.fold(0.0, (total, sale) {
        return total + _toDouble(sale['sellingPrice']);
      });

  double get periodExpense => _filteredExpenses.fold(0.0, (total, expense) {
        return total + _toDouble(expense['amount']);
      });

  int get periodTransactions => _filteredSales.length;

  int get creditSalesCount => _filteredSales.where((sale) {
        return (sale['paymentMethod'] ?? '').toString().toLowerCase() ==
            'credit';
      }).length;

  int get cashSalesCount => _filteredSales.where((sale) {
        return (sale['paymentMethod'] ?? '').toString().toLowerCase() ==
            'cash';
      }).length;

  double get averageTransactionValue {
    if (periodTransactions == 0) {
      return 0;
    }
    return periodRevenue / periodTransactions;
  }

  double get selectedMonthExpense {
    return _allExpenses.where((expense) {
      final expenseDate = _parseDateValue(expense['date']);
      if (expenseDate == null || !_matchesPaymentFilter(expense['paymentMethod'])) {
        return false;
      }
      return expenseDate.year == _selectedDate.year &&
          expenseDate.month == _selectedDate.month;
    }).fold(0.0, (total, expense) => total + _toDouble(expense['amount']));
  }

  String formatSaleDate(String dateValue) {
    final date = DateTime.tryParse(dateValue);
    if (date == null) {
      return 'Unknown date';
    }
    return DateFormat('dd MMM yyyy').format(date);
  }

  void _filterReportData() {
    _filteredSales = _allSales.where((sale) {
      final saleDate = _parseDateValue(sale['date']);
      if (saleDate == null) {
        return false;
      }

      return _matchesPeriod(saleDate) &&
          _matchesPaymentFilter(sale['paymentMethod']);
    }).toList()
      ..sort((first, second) {
        final firstDate = _parseDateValue(first['date']) ?? DateTime(1970);
        final secondDate = _parseDateValue(second['date']) ?? DateTime(1970);
        return secondDate.compareTo(firstDate);
      });

    _filteredExpenses = _allExpenses.where((expense) {
      final expenseDate = _parseDateValue(expense['date']);
      if (expenseDate == null) {
        return false;
      }

      return _matchesPeriod(expenseDate) &&
          _matchesPaymentFilter(expense['paymentMethod']);
    }).toList()
      ..sort((first, second) {
        final firstDate = _parseDateValue(first['date']) ?? DateTime(1970);
        final secondDate = _parseDateValue(second['date']) ?? DateTime(1970);
        return secondDate.compareTo(firstDate);
      });
  }

  bool _matchesPeriod(DateTime date) {
    if (_selectedPeriod == ReportPeriod.daily) {
      return date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
    }

    return date.year == _selectedDate.year && date.month == _selectedDate.month;
  }

  bool _matchesPaymentFilter(dynamic paymentMethod) {
    if (_selectedPaymentFilter == 'All') {
      return true;
    }

    return (paymentMethod ?? '').toString().trim().toLowerCase() ==
        _selectedPaymentFilter.toLowerCase();
  }

  DateTime? _parseDateValue(dynamic rawValue) {
    final dateValue = (rawValue ?? '').toString();
    final parsedDate = DateTime.tryParse(dateValue);
    if (parsedDate == null) {
      return null;
    }
    return _dateOnly(parsedDate);
  }

  double _toDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
