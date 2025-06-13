import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ProfitCheckerPage extends StatefulWidget {
  const ProfitCheckerPage({super.key});

  @override
  _ProfitCheckerPageState createState() => _ProfitCheckerPageState();
}

class _ProfitCheckerPageState extends State<ProfitCheckerPage> {
  final List<TextEditingController> dynamicControllers = [];
  final List<String> dynamicLabels = [];

  double grossProfit = 0.0;
  double netProfit = 0.0;

  bool isLoading = false;

  final DatabaseReference salesRef =
      FirebaseDatabase.instance.ref().child('sales');
  final DatabaseReference medicationsRef =
      FirebaseDatabase.instance.ref().child('medications');

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
    });

    double totalSellingPrice = 0.0;
    double totalPurchasedPrice = 0.0;

    try {
      // Fetch all sales data
      DataSnapshot salesSnapshot = await salesRef.get();
      if (!salesSnapshot.exists) {
        _showErrorAlert('No sales data found.');
        return;
      }

      // Loop through each sale to calculate the total selling price and purchased price
      for (var sale in salesSnapshot.children) {
        try {
          // Extract sale details
          String? drugName = sale.child('drugName').value as String?;
          int? quantitySold = sale.child('quantitySold').value as int?;
          double? sellingPrice = _toDouble(sale.child('sellingPrice').value);

          if (drugName == null ||
              quantitySold == null ||
              sellingPrice == null) {
            _showErrorAlert('Invalid sales data: $sale');
            continue;
          }

          // Add to total selling price
          totalSellingPrice += sellingPrice;

          // Fetch the corresponding medication's purchased price
          Query medicationQuery =
              medicationsRef.orderByChild('drug').equalTo(drugName);
          DataSnapshot medicationSnapshot = await medicationQuery.get();

          if (!medicationSnapshot.exists) {
            _showErrorAlert('No medication data found for drug: $drugName');
            continue;
          }

          // Assume the first match for the drug is valid
          var med = medicationSnapshot.children.first;
          double? purchasedPrice = _toDouble(med.child('purchasedPrice').value);

          if (purchasedPrice == null) {
            _showErrorAlert('Invalid medication data for drug: $drugName');
            continue;
          }

          // Update total purchased price
          totalPurchasedPrice += purchasedPrice * quantitySold;
        } catch (e) {
          _showErrorAlert('Error processing sale: $e');
        }
      }

      // Calculate gross profit
      grossProfit = totalSellingPrice - totalPurchasedPrice;

      // Calculate dynamic costs entered by the user
      double totalDynamicCosts = 0.0;
      for (var controller in dynamicControllers) {
        totalDynamicCosts += double.tryParse(controller.text) ?? 0.0;
      }

      // Calculate net profit
      netProfit = grossProfit - totalDynamicCosts;

      if (mounted) {
        setState(() {}); // Update the UI with the results
      }
    } catch (e) {
      _showErrorAlert('Error fetching data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Safely convert dynamic values to `double`
  double? _toDouble(dynamic value) {
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    }
    return null;
  }

  void _showErrorAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _addCustomField() {
    setState(() {
      dynamicControllers.add(TextEditingController());
      dynamicLabels.add('Custom Input ${dynamicControllers.length}');
    });
  }

  void _removeCustomField() {
    if (dynamicControllers.isNotEmpty) {
      setState(() {
        dynamicControllers.removeLast();
        dynamicLabels.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text('Profit Checker'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gross Profit: \$${grossProfit.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Net Profit: \$${netProfit.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 20),
                  ...List.generate(
                    dynamicControllers.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dynamicControllers[index],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: dynamicLabels[index],
                                filled: true,
                                fillColor: Colors.grey[200],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _removeCustomField(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _addCustomField,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Add New Field',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _fetchData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Calculate Profit',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
