import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ReporterPage extends StatefulWidget {
  @override
  _ReporterPageState createState() => _ReporterPageState();
}

class _ReporterPageState extends State<ReporterPage> {
  List<Map<String, dynamic>> membersList = [];
  List<Map<String, dynamic>> filteredList = [];
  bool _isLoading = true;
  int _totalPaidAmount = 0;

  static const Map<String, int> membershipPrices = {
    "Standard": 500,
    "Premium": 700,
    "VIP": 1500,
  };

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

  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _fetchReportsData();
  }

  Future<void> _fetchReportsData() async {
    try {
      List<Map<String, dynamic>> reportsList = [];

      final DatabaseReference membersReportsRef =
          FirebaseDatabase.instance.ref('members/reporte');
      final DatabaseEvent membersReportsEvent = await membersReportsRef.once();

      if (membersReportsEvent.snapshot.value != null) {
        final Map<dynamic, dynamic> membersReportsMap =
            membersReportsEvent.snapshot.value as Map<dynamic, dynamic>;

        membersReportsMap.forEach((reportKey, reportValue) {
          if (reportValue is Map) {
            Map<String, dynamic> reportData =
                Map<String, dynamic>.from(reportValue);
            if (reportData.containsKey('fullName')) {
              String fullName = reportData['fullName'] ?? 'Unknown';
              reportData['fullName'] = fullName;
              reportData['reportId'] = reportKey;
              // Fetch and store phone number if available
              reportData['phoneNumber'] =
                  reportData['phoneNumber'] ?? 'No Phone';
              reportsList.add(reportData);
            }
          }
        });
      }

      final DatabaseReference topLevelReportsRef =
          FirebaseDatabase.instance.ref('reporte');
      final DatabaseEvent topLevelReportsEvent =
          await topLevelReportsRef.once();

      if (topLevelReportsEvent.snapshot.value != null) {
        final Map<dynamic, dynamic> topLevelReportsMap =
            topLevelReportsEvent.snapshot.value as Map<dynamic, dynamic>;

        topLevelReportsMap.forEach((reportKey, reportValue) {
          if (reportValue is Map) {
            Map<String, dynamic> reportData =
                Map<String, dynamic>.from(reportValue);

            String firstName = reportData['firstName'] ?? '';
            String lastName = reportData['lastName'] ?? '';
            String fullName = '$firstName $lastName'.trim();

            if (fullName.isEmpty) {
              fullName = 'Unknown';
            }

            reportData['fullName'] = fullName;
            reportData['reportId'] = reportKey;
            // Fetch and store phone number if available
            reportData['phoneNumber'] = reportData['phoneNumber'] ?? 'No Phone';
            reportsList.add(reportData);
          }
        });
      }

      reportsList.sort((a, b) {
        DateTime dateA = DateTime.parse(a['registerDate']);
        DateTime dateB = DateTime.parse(b['registerDate']);
        return dateB.compareTo(dateA);
      });

      setState(() {
        membersList = reportsList;
        filteredList = reportsList;
        _totalPaidAmount = membersList.fold(0, (sum, member) {
          return sum + _calculateTotalPrice(member);
        });
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching reports: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _calculateTotalPaidAmount(List<Map<String, dynamic>> members) {
    return members.fold(0, (sum, member) {
      return sum + _calculateTotalPrice(member);
    });
  }

  int _calculateTotalPrice(Map<String, dynamic> member) {
    String membershipType = member['membership'] ?? "Unknown";
    int pricePerMonth = membershipPrices[membershipType] ?? 0;
    String? durationString = member['duration'];
    int durationMonths = 1;

    if (durationString != null && durationString.isNotEmpty) {
      int? extractedMonths = int.tryParse(durationString.split(' ')[0]);
      if (extractedMonths != null) {
        durationMonths = extractedMonths;
      }
    }

    return pricePerMonth * durationMonths;
  }

  String _convertToEthiopianDate(String registerDate) {
    DateTime date = DateTime.parse(registerDate);
    int ethMonth = date.month;
    int ethDay = date.day;
    String ethMonthName = ethiopianMonths[ethMonth] ?? "Unknown Month";
    return "${date.year} $ethMonthName $ethDay";
  }

  void _filterMembersByMonth() {
    setState(() {
      if (_selectedMonth == null || _selectedMonth == "All") {
        filteredList = membersList;
      } else {
        filteredList = membersList.where((member) {
          String registerDate = member['registerDate'];
          DateTime date = DateTime.parse(registerDate);
          String monthName = ethiopianMonths[date.month] ?? "Unknown";
          return monthName == _selectedMonth;
        }).toList();
      }
      _totalPaidAmount = _calculateTotalPaidAmount(filteredList);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registered Members Report'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Total Paid Amount: $_totalPaidAmount Birr',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _selectedMonth,
                        hint: Text('Select Month'),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedMonth = newValue;
                          });
                          _filterMembersByMonth();
                        },
                        items: [
                          ...["All"].map((String month) {
                            return DropdownMenuItem<String>(
                              value: month,
                              child: Text(month),
                            );
                          }).toList(),
                          ...ethiopianMonths.values.map((String month) {
                            return DropdownMenuItem<String>(
                              value: month,
                              child: Text(month),
                            );
                          }).toList(),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final member = filteredList[index];
                      int total = _calculateTotalPrice(member);
                      String ethiopianRegisterDate =
                          _convertToEthiopianDate(member['registerDate']);

                      return Card(
                        margin: EdgeInsets.all(8),
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          title: Text(
                            "${index + 1}. ${member['fullName']}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  "Phone: ${member['phoneNumber']}"), // Display phone number
                              Text("Membership: ${member['membership']}"),
                              Text("Duration: ${member['duration']}"),
                              Text("Register Date: $ethiopianRegisterDate"),
                              Text("Total Paid: $total Birr"),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
