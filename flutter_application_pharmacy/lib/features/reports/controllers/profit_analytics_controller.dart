import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ProfitSaleLine {
  const ProfitSaleLine({
    required this.date,
    required this.medicineName,
    required this.quantitySold,
    required this.unitSellPrice,
    required this.revenue,
    required this.unitPurchasePrice,
    required this.cost,
    required this.profit,
  });

  final String date;
  final String medicineName;
  final int quantitySold;
  final double unitSellPrice;
  final double revenue;
  final double unitPurchasePrice;
  final double cost;
  final double profit;
}

class ProfitExpenseLine {
  const ProfitExpenseLine({
    required this.date,
    required this.description,
    required this.amount,
  });

  final String date;
  final String description;
  final double amount;
}

class ProfitAnalyticsController extends ChangeNotifier {
  final DatabaseReference _salesRef = FirebaseDatabase.instance.ref('sales');
  final DatabaseReference _medicationsRef = FirebaseDatabase.instance.ref(
    'medications',
  );
  final DatabaseReference _expensesRef = FirebaseDatabase.instance.ref(
    'expenses',
  );

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  double _totalRevenue = 0.0;
  double get totalRevenue => _totalRevenue;

  double _costOfGoodsSold = 0.0;
  double get costOfGoodsSold => _costOfGoodsSold;

  double _recordedExpenses = 0.0;
  double get recordedExpenses => _recordedExpenses;

  double get extraCostsTotal {
    var total = 0.0;
    for (final controller in dynamicControllers) {
      total += double.tryParse(controller.text.trim()) ?? 0.0;
    }
    return total;
  }

  double get totalExpenses => _recordedExpenses + extraCostsTotal;

  double _grossProfit = 0.0;
  double get grossProfit => _grossProfit;

  double _netProfit = 0.0;
  double get netProfit => _netProfit;

  List<ProfitSaleLine> _saleLines = const [];
  List<ProfitSaleLine> get saleLines => _saleLines;

  List<ProfitExpenseLine> _expenseLines = const [];
  List<ProfitExpenseLine> get expenseLines => _expenseLines;

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
  }

  void removeExtraCost(int index) {
    if (index < 0 || index >= dynamicControllers.length) {
      return;
    }
    dynamicControllers[index].dispose();
    dynamicControllers.removeAt(index);
    dynamicLabels.removeAt(index);
    calculateProfit();
  }

  Future<void> calculateProfit() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    var totalSellingPrice = 0.0;
    var totalPurchasedPrice = 0.0;
    var totalRecordedExpenses = 0.0;
    final parsedSaleLines = <ProfitSaleLine>[];
    final parsedExpenseLines = <ProfitExpenseLine>[];

    try {
      final salesSnapshot = await _salesRef.get();
      if (salesSnapshot.exists) {
        for (final sale in salesSnapshot.children) {
          final drugName =
              (sale.child('drugName').value ?? 'Unknown').toString();
          final medicationId = sale.child('medicationId').value?.toString();
          final date = (sale.child('date').value ?? 'Unknown').toString();
          final rawQty = sale.child('quantitySold').value;
          final quantitySold = int.tryParse(rawQty?.toString() ?? '0') ?? 0;
          final rawLineRevenue =
              _toDouble(sale.child('sellingPrice').value) ?? 0.0;
          final savedUnitSellPrice =
              _toDouble(sale.child('unitPrice').value) ?? 0.0;
          final saleRevenue = rawLineRevenue > 0
              ? rawLineRevenue
              : savedUnitSellPrice * quantitySold;
          final unitSellPrice = savedUnitSellPrice > 0 && quantitySold > 0
              ? savedUnitSellPrice
              : quantitySold > 0
                  ? saleRevenue / quantitySold
                  : 0.0;

          if (quantitySold <= 0) {
            continue;
          }

          totalSellingPrice += saleRevenue;

          final savedPurchaseUnitPrice =
              _toDouble(sale.child('purchaseUnitPrice').value);
          var purchasedPrice = savedPurchaseUnitPrice ?? 0.0;

          if (savedPurchaseUnitPrice == null) {
            final medicationSnapshot =
                medicationId != null && medicationId.isNotEmpty
                    ? await _medicationsRef.child(medicationId).get()
                    : await _medicationsRef
                        .orderByChild('drug')
                        .equalTo(drugName)
                        .limitToFirst(1)
                        .get();

            if (medicationSnapshot.exists) {
              final medicationNode =
                  medicationId != null && medicationId.isNotEmpty
                      ? medicationSnapshot
                      : medicationSnapshot.children.first;
              purchasedPrice =
                  _toDouble(medicationNode.child('purchasedPrice').value) ??
                      0.0;
            }
          }

          final lineCost = purchasedPrice * quantitySold;
          totalPurchasedPrice += lineCost;

          parsedSaleLines.add(
            ProfitSaleLine(
              date: date,
              medicineName: drugName,
              quantitySold: quantitySold,
              unitSellPrice: unitSellPrice,
              revenue: saleRevenue,
              unitPurchasePrice: purchasedPrice,
              cost: lineCost,
              profit: saleRevenue - lineCost,
            ),
          );
        }
      }

      final expensesSnapshot = await _expensesRef.get();
      if (expensesSnapshot.exists) {
        for (final expense in expensesSnapshot.children) {
          final amount = _toDouble(expense.child('amount').value) ?? 0.0;
          totalRecordedExpenses += amount;
          parsedExpenseLines.add(
            ProfitExpenseLine(
              date: (expense.child('date').value ?? 'Unknown').toString(),
              description:
                  (expense.child('reason').value ?? 'Expense').toString(),
              amount: amount,
            ),
          );
        }
      }

      _totalRevenue = totalSellingPrice;
      _costOfGoodsSold = totalPurchasedPrice;
      _recordedExpenses = totalRecordedExpenses;
      _grossProfit = _totalRevenue - _costOfGoodsSold;
      _netProfit = _grossProfit - totalExpenses;
      _saleLines = parsedSaleLines;
      _expenseLines = parsedExpenseLines;
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
