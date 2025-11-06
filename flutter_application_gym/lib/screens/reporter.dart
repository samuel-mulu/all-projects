import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/reliable_text_widget.dart';
import '../utils/reliable_state_mixin.dart';
import '../utils/duration_helper.dart';

class AmountDisplayWidget extends StatefulWidget {
  final bool showAmount;
  final String selectedFilter;
  final int totalPaidAmount;
  final int totalRemainingAmount;

  const AmountDisplayWidget({
    Key? key,
    required this.showAmount,
    required this.selectedFilter,
    required this.totalPaidAmount,
    required this.totalRemainingAmount,
  }) : super(key: key);

  @override
  _AmountDisplayWidgetState createState() => _AmountDisplayWidgetState();
}

class _AmountDisplayWidgetState extends State<AmountDisplayWidget> {
  @override
  Widget build(BuildContext context) {
    String displayText;
    if (widget.showAmount) {
      if (widget.selectedFilter == 'All') {
        displayText = 'Total Paid ${widget.totalPaidAmount}';
      } else if (widget.selectedFilter == 'Has Remaining') {
        displayText = 'Remain Paid ${widget.totalRemainingAmount}';
      } else if (widget.selectedFilter == 'Net Paid') {
        int netPaid = widget.totalPaidAmount - widget.totalRemainingAmount;
        displayText = 'Net Paid $netPaid';
      } else {
        displayText = 'Paid BIRR ${widget.totalPaidAmount}';
      }
    } else {
      if (widget.selectedFilter == 'All') {
        displayText = 'Total Paid ••••••';
      } else if (widget.selectedFilter == 'Has Remaining') {
        displayText = 'Remain Paid ••••••';
      } else if (widget.selectedFilter == 'Net Paid') {
        displayText = 'Net Paid ••••••';
      } else {
        displayText = 'Paid BIRR ••••••';
      }
    }
    
    // Responsive font size based on screen width
    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 400 ? 18 : (screenWidth < 600 ? 20 : 24);
    
    return Text(
      displayText,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

class ReporterPage extends StatefulWidget {
  @override
  _ReporterPageState createState() => _ReporterPageState();
}

class _ReporterPageState extends State<ReporterPage> with ReliableStateMixin {
  List<Map<String, dynamic>> membersList = [];
  List<Map<String, dynamic>> filteredList = [];
  bool _isLoading = true;
  int _totalPaidAmount = 0;
  int _totalRemainingAmount = 0;
  int _netPaidAmount = 0; // Total paid minus remaining
  Map<String, int> _paymentMethodStats = {};
  bool _showTotalAmount = false;
  // Removed membership prices - now using DurationHelper
  StreamSubscription<DatabaseEvent>? _reporteSubscription; // Live update listener
  bool _isRefreshing = false; // Refresh indicator

  // Pagination variables
  int _currentPage = 1;
  final int _itemsPerPage = 20; // Load 20 reports at a time
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Search variables
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;

  // Removed static membership prices - now using DurationHelper

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
  String? _selectedRemainingFilter = 'All'; // New filter for remaining amounts

  @override
  void initState() {
    super.initState();
    _setupLiveUpdates(); // Setup real-time listener
  }

  @override
  void dispose() {
    _reporteSubscription?.cancel(); // Cancel listener when page is disposed
    _searchController.dispose();
    super.dispose();
  }

  // Setup live updates using Firebase real-time listener
  void _setupLiveUpdates() {
    final DatabaseReference reporteRef = FirebaseDatabase.instance.ref('reporte');
    
    // Listen to changes in the reporte path
    _reporteSubscription = reporteRef.onValue.listen((DatabaseEvent event) {
      if (mounted) {
        _processReportsData(event);
      }
    }, onError: (error) {
      print('Error in live updates: $error');
      if (mounted) {
        forceReliableUpdate(() {
          _isLoading = false;
        });
      }
    });
  }

  // Process reports data from Firebase event
  void _processReportsData(DatabaseEvent event) {
    try {
      List<Map<String, dynamic>> reportsList = [];

      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> reportsMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        reportsMap.forEach((reportKey, reportValue) {
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
            reportData['memberId'] = reportKey; // Use reportKey as memberId (they should be the same)
            reportData['phoneNumber'] = reportData['phoneNumber'] ?? 'No Phone';
            reportData['paymentMethod'] = reportData['paymentMethod'] ?? 'Not Specified';
            reportData['paymentImageUrl'] = reportData['paymentImageUrl'] ?? '';
            reportData['remaining'] = reportData['remaining'] ?? 0;
            reportData['profileImageUrl'] = reportData['profileImageUrl'] ?? '';
            
            // Keep all reports including pending deletions
            reportsList.add(reportData);
          }
        });
      }

      reportsList.sort((a, b) {
        DateTime dateA = DateTime.parse(a['registerDate']);
        DateTime dateB = DateTime.parse(b['registerDate']);
        return dateB.compareTo(dateA);
      });

      forceReliableUpdate(() {
        membersList = reportsList;
        filteredList = reportsList;
        _totalPaidAmount = _calculateTotalExpectedRevenue(membersList);
        _totalRemainingAmount = _calculateTotalRemainingAmount(membersList);
        _netPaidAmount = _calculateNetPaidAmount(membersList);
        _paymentMethodStats = _calculatePaymentMethodStats(membersList);
        _isLoading = false;
        _isRefreshing = false;
      });
      
      // Apply current filters if any
      if (_selectedMonth != null && _selectedMonth != 'All') {
        _filterMembersByMonth();
      }
      if (_selectedRemainingFilter != null && _selectedRemainingFilter != 'All') {
        _filterMembersByRemaining();
      }
      
      print('Live update: ${membersList.length} members');
    } catch (e) {
      print('Error processing reports data: $e');
      forceReliableUpdate(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  // Manual refresh function
  Future<void> _manualRefresh() async {
    forceReliableUpdate(() {
      _isRefreshing = true;
    });
    
    // Trigger a re-fetch by reading the data once
    try {
      final DatabaseReference reporteRef = FirebaseDatabase.instance.ref('reporte');
      final DatabaseEvent event = await reporteRef.once();
      _processReportsData(event);
    } catch (e) {
      print('Error during manual refresh: $e');
      forceReliableUpdate(() {
        _isRefreshing = false;
      });
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data refreshed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fetchReportsData() async {
    try {
      List<Map<String, dynamic>> reportsList = [];

      // Removed members/reporte fetch - using only top-level reporte for cleaner data structure

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
            reportData['memberId'] = reportKey; // Use reportKey as memberId (they should be the same)
            
            // Fetch and store phone number if available
            reportData['phoneNumber'] = reportData['phoneNumber'] ?? 'No Phone';
            
            // Fetch and store payment method if available (may not exist in reporte path)
            reportData['paymentMethod'] = reportData['paymentMethod'] ?? 'Not Specified';
            
            // Fetch and store payment image URL if available (may not exist in reporte path)
            reportData['paymentImageUrl'] = reportData['paymentImageUrl'] ?? '';
            
            // Fetch and store remaining amount if available (ቀሪ)
            reportData['remaining'] = reportData['remaining'] ?? 0;
            
            // Fetch and store profile image URL if available
            reportData['profileImageUrl'] = reportData['profileImageUrl'] ?? '';
            
            // Keep all reports including pending deletions
            reportsList.add(reportData);
          }
        });
      }

      reportsList.sort((a, b) {
        DateTime dateA = DateTime.parse(a['registerDate']);
        DateTime dateB = DateTime.parse(b['registerDate']);
        return dateB.compareTo(dateA);
      });

      forceReliableUpdate(() {
        membersList = reportsList;
        filteredList = reportsList;
        // Initialize with "All" filter logic (total expected revenue)
        _totalPaidAmount = _calculateTotalExpectedRevenue(membersList);
        _totalRemainingAmount = _calculateTotalRemainingAmount(membersList);
        _netPaidAmount = _calculateNetPaidAmount(membersList);
        _paymentMethodStats = _calculatePaymentMethodStats(membersList);
        _isLoading = false;
      });
      
      print('Data loaded: ${membersList.length} members');
      print('Total paid: $_totalPaidAmount, Total remaining: $_totalRemainingAmount');
      print('Expected revenue: ${_calculateTotalExpectedRevenue(membersList)}');
    } catch (e) {
      print('Error fetching reports: $e');
      forceReliableUpdate(() {
        _isLoading = false;
      });
    }
  }

  int _calculateTotalPaidAmount(List<Map<String, dynamic>> members) {
    return members.fold(0, (sum, member) {
      int totalPrice = _calculateTotalPrice(member);
      int remaining = member['remaining'] ?? 0;
      int actualPaid = totalPrice - remaining;
      return sum + actualPaid;
    });
  }

  int _calculateTotalRemainingAmount(List<Map<String, dynamic>> members) {
    return members.fold(0, (sum, member) {
      return sum + ((member['remaining'] ?? 0) as int);
    });
  }

  int _calculateNetPaidAmount(List<Map<String, dynamic>> members) {
    // Net paid is the same as total paid since we already subtracted remaining
    return _calculateTotalPaidAmount(members);
  }

  int _calculateTotalExpectedRevenue(List<Map<String, dynamic>> members) {
    return members.fold(0, (sum, member) {
      return sum + _calculateTotalPrice(member);
    });
  }

  Map<String, int> _calculatePaymentMethodStats(List<Map<String, dynamic>> members) {
    Map<String, int> stats = {};
    for (var member in members) {
      String paymentMethod = member['paymentMethod'] ?? 'Not Specified';
      stats[paymentMethod] = (stats[paymentMethod] ?? 0) + 1;
    }
    return stats;
  }

  int _calculateTotalPrice(Map<String, dynamic> member) {
    // Prefer stored price if available (saved at registration/update time)
    final dynamic price = member['price'];
    if (price is int) return price;
    if (price is num) return price.toInt();

    // Fallback to duration-based pricing
    final String? durationString = member['duration'];
    if (durationString != null && durationString.isNotEmpty) {
      return DurationHelper.getDurationPrice(durationString);
    }
    return DurationHelper.getDurationPrice('1 Month');
  }

  String _convertToEthiopianDate(String registerDate) {
    DateTime date = DateTime.parse(registerDate);
    int ethMonth = date.month;
    int ethDay = date.day;
    String ethMonthName = ethiopianMonths[ethMonth] ?? "Unknown Month";
    return "${date.year} $ethMonthName $ethDay";
  }

  void _filterMembersByName(String query) {
    forceReliableUpdate(() {
      if (query.isEmpty) {
        filteredList = List.from(membersList);
      } else {
        filteredList = membersList.where((member) {
          String fullName = member['fullName'] ?? '';
          return fullName.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      // Reset pagination when filtering
      _currentPage = 1;
      _hasMore = filteredList.length > _itemsPerPage;
      print('Filtered by name: ${filteredList.length} members');
    });
  }

  void _filterMembersByMonth() {
    forceReliableUpdate(() {
      if (_selectedMonth == null || _selectedMonth == "All") {
        filteredList = List.from(membersList);
      } else {
        filteredList = membersList.where((member) {
          String registerDate = member['registerDate'];
          DateTime date = DateTime.parse(registerDate);
          String monthName = ethiopianMonths[date.month] ?? "Unknown";
          return monthName == _selectedMonth;
        }).toList();
      }
      _applyRemainingFilter();
      // Reset pagination when filtering
      _currentPage = 1;
      _hasMore = filteredList.length > _itemsPerPage;
      print('Filtered by month: ${filteredList.length} members');
    });
  }

  void _applyRemainingFilter() {
    if (_selectedRemainingFilter == null || _selectedRemainingFilter == "All") {
      // No additional filtering needed - keep current filteredList
    } else if (_selectedRemainingFilter == "Has Remaining") {
      filteredList = filteredList.where((member) {
        int remaining = member['remaining'] ?? 0;
        return remaining > 0;
      }).toList();
    } else if (_selectedRemainingFilter == "Net Paid") {
      // Don't filter members, show all but calculate net paid
      // No filtering needed - just change the calculation
    }
    
    // Recalculate amounts with filtered data based on filter type
    if (_selectedRemainingFilter == 'All') {
      // All: Show total expected revenue (total membership price)
      _totalPaidAmount = _calculateTotalExpectedRevenue(filteredList);
      _totalRemainingAmount = _calculateTotalRemainingAmount(filteredList);
    } else if (_selectedRemainingFilter == 'Has Remaining') {
      // Has Remaining: Show only remaining amounts
      _totalPaidAmount = 0; // Not relevant for this filter
      _totalRemainingAmount = _calculateTotalRemainingAmount(filteredList);
    } else if (_selectedRemainingFilter == 'Net Paid') {
      // Net Paid: Show total expected revenue and remaining separately
      // So the display can calculate: totalExpected - totalRemaining = netPaid
      _totalPaidAmount = _calculateTotalExpectedRevenue(filteredList);
      _totalRemainingAmount = _calculateTotalRemainingAmount(filteredList);
    } else {
      // Default: Show actual paid amounts
      _totalPaidAmount = _calculateTotalPaidAmount(filteredList);
    _totalRemainingAmount = _calculateTotalRemainingAmount(filteredList);
    }
    
    _netPaidAmount = _calculateNetPaidAmount(filteredList);
      _paymentMethodStats = _calculatePaymentMethodStats(filteredList);
    
    print('Applied remaining filter: ${filteredList.length} members');
    print('Filter: $_selectedRemainingFilter');
    print('Total paid: $_totalPaidAmount, Total remaining: $_totalRemainingAmount');
    print('Net paid: ${_totalPaidAmount - _totalRemainingAmount}');
    print('Expected revenue: ${_calculateTotalExpectedRevenue(filteredList)}');
  }

  void _filterMembersByRemaining() {
    forceReliableUpdate(() {
      // First reset to all members if "All" is selected
      if (_selectedRemainingFilter == 'All') {
        filteredList = List.from(membersList);
      }
      _applyRemainingFilter();
      // Reset pagination when filtering
      _currentPage = 1;
      _hasMore = filteredList.length > _itemsPerPage;
      print('Filtered by remaining: ${filteredList.length} members');
    });
  }

  // Get paginated reports for current page
  List<Map<String, dynamic>> _getPaginatedReports() {
    int endIndex = _currentPage * _itemsPerPage;
    if (endIndex > filteredList.length) {
      endIndex = filteredList.length;
      _hasMore = false;
    }
    return filteredList.sublist(0, endIndex);
  }

  // Load more reports (next page)
  void _loadMore() {
    if (!_isLoadingMore && _hasMore) {
      forceReliableUpdate(() {
        _isLoadingMore = true;
      });

      // Simulate loading delay for smooth UX
      Future.delayed(const Duration(milliseconds: 300), () {
        forceReliableUpdate(() {
          _currentPage++;
          _hasMore = (_currentPage * _itemsPerPage) < filteredList.length;
          _isLoadingMore = false;
        });
      });
    }
  }

  // Request deletion - Mark as pending for user approval
  Future<void> _requestDeletion(String reportId, String fullName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Request Deletion?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mark this report for deletion?'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                fullName,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This will be sent to User for approval before deletion.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Request Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Mark as pending deletion
        await FirebaseDatabase.instance.ref('reporte/$reportId').update({
          'deleteStatus': 'pending_delete',
          'deleteRequestedAt': DateTime.now().toIso8601String(),
          'deleteRequestedBy': 'Admin',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deletion request sent for approval'),
            backgroundColor: Colors.orange,
          ),
        );

        // Refresh to show pending status
        _fetchReportsData();
        print('✅ Requested deletion for: $fullName (ID: $reportId)');
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error requesting deletion: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Cancel deletion request - Remove pending status
  Future<void> _cancelDeletionRequest(String reportId, String fullName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.undo, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('Cancel Deletion?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cancel deletion request for:'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                fullName,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This will restore the report to normal status.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Cancel Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Remove pending deletion status
        await FirebaseDatabase.instance.ref('reporte/$reportId').update({
          'deleteStatus': null,
          'deleteRequestedAt': null,
          'deleteRequestedBy': null,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deletion request cancelled'),
            backgroundColor: Colors.blue,
          ),
        );

        // Refresh to show updated status
        _fetchReportsData();
        print('✅ Cancelled deletion request for: $fullName (ID: $reportId)');
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error cancelling request: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Function to update remaining amount for a member
  void _updateRemaining(String memberId, String fullName, int currentRemaining, Map<String, dynamic> memberData) async {
    TextEditingController remainingController =
        TextEditingController(text: currentRemaining.toString());
    
    int? _remaining = currentRemaining;
    bool _isUpdating = false; // Track update state
    
    // Calculate maximum allowed remaining amount
    int maxRemaining = 0;
    final dynamic storedPrice = memberData['price'];
    if (storedPrice is int) {
      maxRemaining = storedPrice;
    } else if (storedPrice is num) {
      maxRemaining = storedPrice.toInt();
    } else {
      String? durationString = memberData['duration'];
      if (durationString != null && durationString.isNotEmpty) {
      maxRemaining = DurationHelper.getDurationPrice(durationString);
    } else {
      maxRemaining = DurationHelper.getDurationPrice('1 Month'); // Default
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing during update
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
        return AlertDialog(
          title: Text('Update Remaining Amount'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Member: $fullName'),
                const SizedBox(height: 16),
                TextField(
                  controller: remainingController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'ቀሪ (Remaining)',
                    hintText: 'Enter remaining amount',
                    border: OutlineInputBorder(),
                    helperText: maxRemaining > 0 ? 'Max: $maxRemaining Birr' : null,
                    helperStyle: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
                  ),
                  onChanged: (value) {
                    _remaining = int.tryParse(value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                  onPressed: _isUpdating ? null : () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
                  onPressed: _isUpdating ? null : () {
                    // Set updating state
                    setState(() {
                      _isUpdating = true;
                    });
                    
                if (_remaining == null || _remaining! < 0) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid remaining amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                // Check if remaining amount exceeds duration price
                if (maxRemaining > 0 && _remaining! > maxRemaining) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Remaining amount cannot exceed duration price ($maxRemaining Birr)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Update the remaining amount in Firebase using the member ID
                // Update both member and report paths with the SAME ID
                FirebaseDatabase.instance.ref('members/$memberId').update({
                  'remaining': _remaining,
                  'lastUpdatedDate': DateTime.now().toIso8601String(),
                  'lastUpdateType': 'remaining_update',
                }).then((_) async {
                  print('✅ Updated member record with remaining: $_remaining (ID: $memberId)');
                  
                  // Also update in reporte path using the SAME memberId
                  try {
                    final DatabaseReference reporteRef = FirebaseDatabase.instance.ref('reporte');
                    
                    // Use the SAME memberId for synchronization
                    await reporteRef.child(memberId).update({
                      'remaining': _remaining,
                      'lastUpdatedDate': DateTime.now().toIso8601String(),
                      'lastUpdateType': 'remaining_update',
                    });
                    print('✅ Updated reporte record with remaining: $_remaining (ID: $memberId)');
                  } catch (e) {
                    print('Error updating reporte record: $e');
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Remaining amount updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop();
                  // Data will auto-refresh via live listener
                }).catchError((error) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating remaining amount: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                });
              },
                  child: _isUpdating
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Updating...'),
                        ],
                      )
                    : Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPaymentReceipt(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Receipt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.blue.shade800),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, color: Colors.red, size: 48),
                                SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Report'),
            if (_isRefreshing) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Search icon button
          IconButton(
            icon: Icon(
              Icons.search,
              color: Colors.amber,
              size: 28,
            ),
            onPressed: () {
              forceReliableUpdate(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  _searchQuery = '';
                  filteredList = List.from(membersList);
                  // Reset pagination
                  _currentPage = 1;
                  _hasMore = filteredList.length > _itemsPerPage;
                }
              });
            },
            tooltip: 'Search by Name',
          ),
          // Refresh icon button
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: _isRefreshing ? Colors.grey.shade400 : Colors.greenAccent.shade400,
              size: 28,
            ),
            onPressed: _isRefreshing ? null : _manualRefresh,
            tooltip: 'Refresh Data',
          ),
          // Live indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Amount Display Card - Full Width
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                              child: ReliableAmountDisplay(
                                showAmount: _showTotalAmount,
                                selectedFilter: _selectedRemainingFilter ?? 'All',
                                totalPaidAmount: _totalPaidAmount,
                                totalRemainingAmount: _totalRemainingAmount,
                                keySuffix: 'reporter_main',
                                          ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                forceReliableUpdate(() {
                                        _showTotalAmount = !_showTotalAmount;
                                  print('Toggle amount visibility: $_showTotalAmount');
                                  print('Total paid amount: $_totalPaidAmount');
                                  print('Total remaining amount: $_totalRemainingAmount');
                                  print('Selected filter: $_selectedRemainingFilter');
                                      });
                                    },
                                    icon: Icon(
                                      _showTotalAmount ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.white,
                                    ),
                                    tooltip: _showTotalAmount ? 'Hide Amount' : 'Show Amount',
                                  ),
                                ],
                              ),
                            ),
                      const SizedBox(height: 8),
                      // Search bar (shown when search icon clicked)
                      if (_showSearchBar) ...[
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            _filterMembersByName(value);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Filters Row - Responsive Layout
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // If screen is narrow, stack filters vertically
                          if (constraints.maxWidth < 600) {
                            return Column(
                              children: [
                                _buildFilterDropdown(
                                  value: _selectedMonth,
                                  hint: 'Filter by Month',
                                  onChanged: (String? newValue) {
                                    forceReliableUpdate(() {
                                      _selectedMonth = newValue;
                                      _filterMembersByMonth();
                                    });
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
                                const SizedBox(height: 8),
                                _buildFilterDropdown(
                                  value: _selectedRemainingFilter,
                                  hint: 'Filter by Remaining',
                                  onChanged: (String? newValue) {
                                    forceReliableUpdate(() {
                                      _selectedRemainingFilter = newValue;
                                      _filterMembersByRemaining();
                                    });
                                  },
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: 'All',
                                      child: Text('All'),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'Has Remaining',
                                      child: Text('Has Remaining'),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'Net Paid',
                                      child: Text('Net Paid'),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          } else {
                            // Wide screen - show filters side by side
                            return Row(
                              children: [
                           Expanded(
                                  child: _buildFilterDropdown(
                            value: _selectedMonth,
                                    hint: 'Filter by Month',
                            onChanged: (String? newValue) {
                                      forceReliableUpdate(() {
                                _selectedMonth = newValue;
                              _filterMembersByMonth();
                                      });
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
                           ),
                                const SizedBox(width: 8),
                           Expanded(
                                  child: _buildFilterDropdown(
                               value: _selectedRemainingFilter,
                                    hint: 'Filter by Remaining',
                               onChanged: (String? newValue) {
                                      forceReliableUpdate(() {
                                   _selectedRemainingFilter = newValue;
                                 _filterMembersByRemaining();
                                      });
                               },
                               items: [
                                 DropdownMenuItem<String>(
                                   value: 'All',
                                   child: Text('All'),
                                 ),
                                 DropdownMenuItem<String>(
                                   value: 'Has Remaining',
                                   child: Text('Has Remaining'),
                                 ),
                                      DropdownMenuItem<String>(
                                        value: 'Net Paid',
                                        child: Text('Net Paid'),
                                 ),
                               ],
                             ),
                          ),
                        ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _getPaginatedReports().length + (_hasMore ? 1 : 0), // +1 for Load More button
                    itemBuilder: (context, index) {
                      final paginatedList = _getPaginatedReports();
                      
                      // Show Load More button at the end
                      if (index == paginatedList.length) {
                        return Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Center(
                            child: _isLoadingMore
                                ? CircularProgressIndicator()
                                : ElevatedButton.icon(
                                    onPressed: _loadMore,
                                    icon: Icon(Icons.expand_more),
                                    label: Text('Load More (${filteredList.length - paginatedList.length} more)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                  ),
                          ),
                        );
                      }
                      
                      final member = paginatedList[index];
                      int totalPrice = _calculateTotalPrice(member);
                      int remaining = member['remaining'] ?? 0;
                      int actualPaid = totalPrice - remaining;
                      String ethiopianRegisterDate =
                          _convertToEthiopianDate(member['registerDate']);
                      
                      // Check if pending deletion
                      bool isPendingDelete = member['deleteStatus'] == 'pending_delete';

                      return Card(
                        margin: EdgeInsets.all(8),
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isPendingDelete 
                            ? BorderSide(color: Colors.orange, width: 3)
                            : BorderSide.none,
                        ),
                        color: isPendingDelete ? Colors.orange.shade50 : null,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile Avatar
                              _buildProfileAvatar(
                                member['profileImageUrl'],
                                member['fullName'],
                              ),
                              const SizedBox(width: 15),
                              // Member Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                  children: [
                                    Text(
                            "${index + 1}. ${member['fullName']}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                                        ),
                                        // Pending badge
                                        if (isPendingDelete) ...[
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.pending, size: 14, color: Colors.white),
                                                SizedBox(width: 4),
                                                Text(
                                                  'PENDING',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                          ),
                                    const SizedBox(height: 8),
                              Text("Phone: ${member['phoneNumber']}"),
                              Text("Duration: ${member['duration']}"),
                              Text("ቀሪ (Remaining): ${member['remaining']} Birr"),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: member['paymentMethod'] == 'MOBILE_BANKING' 
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: member['paymentMethod'] == 'MOBILE_BANKING' 
                                        ? Colors.green
                                        : Colors.blue,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  "Payment: ${member['paymentMethod']}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: member['paymentMethod'] == 'MOBILE_BANKING' 
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              if (member['paymentImageUrl'] != null && 
                                  member['paymentImageUrl'].toString().isNotEmpty)
                                Row(
                                  children: [
                                    Icon(Icons.receipt, size: 16, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text(
                                      "Receipt Available",
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              Text("Register Date: $ethiopianRegisterDate"),
                                    Text("Total Price: $totalPrice Birr"),
                                    Text("Amount Paid: $actualPaid Birr"),
                            ],
                          ),
                              ),
                              // Action buttons
                              Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Update remaining button
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.orange),
                                onPressed: () {
                                  _updateRemaining(
                                    member['memberId'] ?? member['reportId'], // Use memberId
                                    member['fullName'] ?? 'Unknown',
                                    member['remaining'] ?? 0,
                                    member, // Pass full member data
                                  );
                                },
                                tooltip: 'Update Remaining Amount',
                              ),
                              // Payment receipt button (if available)
                              if (member['paymentImageUrl'] != null && 
                                  member['paymentImageUrl'].toString().isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.visibility, color: Colors.blue),
                                  onPressed: () {
                                    _showPaymentReceipt(context, member['paymentImageUrl']);
                                  },
                                  tooltip: 'View Payment Receipt',
                                    ),
                              // Delete/Cancel button - Changes based on pending status
                              if (isPendingDelete)
                                // Cancel Request button (Blue) for pending deletions
                                IconButton(
                                  icon: Icon(Icons.undo, color: Colors.blue),
                                  onPressed: () {
                                    _cancelDeletionRequest(
                                      member['reportId'] ?? member['memberId'],
                                      member['fullName'] ?? 'Unknown',
                                    );
                                  },
                                  tooltip: 'Cancel Deletion Request',
                                )
                              else
                                // Delete button (Red) for normal reports
                                IconButton(
                                  icon: Icon(Icons.delete_forever, color: Colors.red),
                                  onPressed: () {
                                    _requestDeletion(
                                      member['reportId'] ?? member['memberId'],
                                      member['fullName'] ?? 'Unknown',
                                    );
                                  },
                                  tooltip: 'Request Deletion',
                                ),
                                ],
                                ),
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

  /// Build profile avatar widget with click to expand
  Widget _buildProfileAvatar(String? profileImageUrl, String fullName) {
    return GestureDetector(
      onTap: () {
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          _showExpandedProfileImage(profileImageUrl, fullName);
        }
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.deepPurple,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: profileImageUrl != null && profileImageUrl.isNotEmpty
              ? Image.network(
                  profileImageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.deepPurple.shade100,
                      child: const Icon(
                        Icons.person,
                        size: 35,
                        color: Colors.deepPurple,
                      ),
                    );
                  },
                )
              : Container(
                  color: Colors.deepPurple.shade100,
                  child: const Icon(
                    Icons.person,
                    size: 35,
                    color: Colors.deepPurple,
                  ),
                ),
        ),
      ),
    );
  }

  /// Build filter dropdown widget
  Widget _buildFilterDropdown({
    required String? value,
    required String hint,
    required ValueChanged<String?> onChanged,
    required List<DropdownMenuItem<String>> items,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint),
        isExpanded: true,
        underline: const SizedBox(),
        onChanged: onChanged,
        items: items,
      ),
    );
  }

  /// Show expanded profile image in a dialog
  void _showExpandedProfileImage(String imageUrl, String fullName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with name and close button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Profile image
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 300,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 48),
                                const SizedBox(height: 8),
                                const Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
