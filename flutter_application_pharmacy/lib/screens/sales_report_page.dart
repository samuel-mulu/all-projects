import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:ethiopian_calendar/ethiopian_date_converter.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({Key? key}) : super(key: key);

  @override
  _SalesReportPageState createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  List<Map<String, dynamic>> salesList = [];
  List<Map<String, dynamic>> filteredSalesList = [];
  bool _isLoading = true;
  double _totalSalesAmount = 0.0;
  String? _selectedMonth;

  static const Map<int, String> ethiopianMonths = {
    1: "መስከረም",
    2: "ጥቅምቲ",
    3: "ሕዳር",
    4: "ታሕሳስ",
    5: "ጥሪ",
    6: "ለካቲት",
    7: "መጋቢት",
    8: "ምያዝያ",
    9: "ግንቦት",
    10: "ሰነ",
    11: "ሓምለ",
    12: "ናሓሰ",
  };

  @override
  void initState() {
    super.initState();
    _fetchSalesData();
  }

  Future<void> _fetchSalesData() async {
    try {
      final DatabaseReference databaseRef =
          FirebaseDatabase.instance.ref('sales');
      final DatabaseEvent event = await databaseRef.once();

      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> firebaseSalesMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        salesList.clear();
        firebaseSalesMap.forEach((key, value) {
          if (value is Map) {
            Map<String, dynamic> sale = Map<String, dynamic>.from(value);
            String saleDate = sale['date'] ?? '';
            DateTime? parsedDate;

            if (saleDate.isNotEmpty) {
              try {
                parsedDate = DateTime.parse(saleDate);
              } catch (e) {
                parsedDate = null;
              }
            }

            sale['parsedDate'] = parsedDate;
            salesList.add(sale);
          }
        });

        salesList.sort((a, b) {
          DateTime? dateA = a['parsedDate'];
          DateTime? dateB = b['parsedDate'];
          if (dateA == null || dateB == null) return 0;
          return dateB.compareTo(dateA);
        });
      }

      setState(() {
        filteredSalesList = salesList;
        _calculateTotalSalesAmount();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching sales: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDateToEthiopian(String saleDate) {
    try {
      DateTime dateTime = DateTime.parse(saleDate);
      var ethiopianDateTime =
          EthiopianDateConverter.convertToEthiopianDate(dateTime);
      return "${ethiopianDateTime.day} ${ethiopianMonths[ethiopianDateTime.month]} ${ethiopianDateTime.year}";
    } catch (e) {
      return 'Invalid Date';
    }
  }

  void _calculateTotalSalesAmount() {
    setState(() {
      _totalSalesAmount = filteredSalesList.fold(0.0, (total, sale) {
        double sellingPrice =
            double.tryParse(sale['sellingPrice'].toString()) ?? 0.0;
        return total + sellingPrice;
      });
    });
  }

  void _filterSalesByMonth() {
    setState(() {
      if (_selectedMonth == null || _selectedMonth == "All") {
        filteredSalesList = salesList;
      } else {
        filteredSalesList = salesList.where((sale) {
          String saleDate = sale['date'] ?? '';
          if (saleDate.isEmpty) return false;

          try {
            DateTime date = DateTime.parse(saleDate);
            var ethiopianDateTime =
                EthiopianDateConverter.convertToEthiopianDate(date);
            String monthName =
                ethiopianMonths[ethiopianDateTime.month] ?? "Unknown";
            return monthName == _selectedMonth;
          } catch (e) {
            return false;
          }
        }).toList();
      }
      _calculateTotalSalesAmount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Sales Report', style: TextStyle(fontSize: 22)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.deepPurple.withOpacity(0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Sales Amount: ${_totalSalesAmount.toStringAsFixed(2)} Birr',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButton<String>(
                          value: _selectedMonth,
                          hint: const Text('Select Month'),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedMonth = newValue;
                            });
                            _filterSalesByMonth();
                          },
                          items: [
                            ...["All"].map((String month) {
                              return DropdownMenuItem<String>(
                                  value: month, child: Text(month));
                            }).toList(),
                            ...ethiopianMonths.values.map((String month) {
                              return DropdownMenuItem<String>(
                                  value: month, child: Text(month));
                            }).toList(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredSalesList.length,
                      itemBuilder: (context, index) {
                        final sale = filteredSalesList[index];
                        String saleDate = sale['date'] != null
                            ? _formatDateToEthiopian(sale['date'])
                            : 'No Date';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 4,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              "${index + 1}. Drug: ${sale['drugName']}",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Selling Price: ${sale['sellingPrice']} Birr"),
                                Text("Quantity Sold: ${sale['quantitySold']}"),
                                Text(
                                    "Payment Method: ${sale['paymentMethod']}"),
                                Text("Sale Date: $saleDate"),
                                if (sale['reason'] != null)
                                  Text("Reason: ${sale['reason']}"),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
