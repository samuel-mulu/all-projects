import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:ethiopian_calendar/ethiopian_date_converter.dart';
import 'package:ethiopian_calendar/model/ethiopian_date.dart';
import '../../services/cloudinary_service.dart';
import '../../services/cloudinary_service_unsigned.dart';
import '../../services/cloudinary_service_web.dart';
import '../../services/image_picker_service.dart';
import '../../utils/permission_checker.dart';

class InactivePage extends StatefulWidget {
  const InactivePage({super.key});

  @override
  _InactivePageState createState() => _InactivePageState();
}

class _InactivePageState extends State<InactivePage> {
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref('members');
  List<Map<String, dynamic>> inactiveMembers = [];
  List<Map<String, dynamic>> filteredMembers = [];
  bool _isLoading = true;
  String _currentUserRole = 'user'; // Default to 'user'
  // ignore: unused_field
  String _userName = ''; // Store the user's name
  bool isAdmin = false; // Default to 'user'
  TextEditingController searchController = TextEditingController();
  StreamSubscription<DatabaseEvent>? _membersSubscription; // Live update listener
  
  // Pagination variables
  int _currentPage = 1;
  final int _itemsPerPage = 20; // Load 20 members at a time
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Selection mode variables
  bool _isSelectionMode = false;
  Set<String> _selectedMemberIds = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
    _setupLiveUpdates(); // Setup real-time listener
  }

  @override
  void dispose() {
    _membersSubscription?.cancel(); // Cancel listener when page is disposed
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserRole() async {
    var _auth = FirebaseAuth.instance; // Initialize Firebase Auth
    User? user = _auth.currentUser; // Get current user
    if (user != null) {
      final userRef = FirebaseDatabase.instance
          .ref("users/${user.email!.replaceAll('.', '_')}");

      final snapshot = await userRef.once();
      if (snapshot.snapshot.exists) {
        setState(() {
          _userName = snapshot.snapshot.child('name').value as String;
          isAdmin = snapshot.snapshot.child('role').value as String == 'admin';
          _currentUserRole = isAdmin ? 'admin' : 'user'; // Set user role
        });
      } else {
        print("User data does not exist.");
      }
    } else {
      print("No user is currently signed in.");
    }
  }

  // Setup live updates using Firebase real-time listener
  void _setupLiveUpdates() {
    final DatabaseReference membersRef = FirebaseDatabase.instance.ref('members');
    
    // Listen to changes in the members path
    _membersSubscription = membersRef.onValue.listen((DatabaseEvent event) {
      if (mounted) {
        _processInactiveMembersData(event);
      }
    }, onError: (error) {
      print('Error in live updates: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // Process inactive members data from Firebase event
  void _processInactiveMembersData(DatabaseEvent event) {
    try {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> members =
            event.snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> loadedMembers = [];
        for (var entry in members.entries) {
          final memberData = entry.value;

          // Fetch only members marked as inactive
          if (memberData['status'] == 'inactive') {
            loadedMembers.add({
              'id': entry.key, // Store the member ID
              ...Map<String, dynamic>.from(memberData)
            });
          }
        }

        setState(() {
          inactiveMembers = loadedMembers;
          filteredMembers = inactiveMembers;
          _isLoading = false;
        });
      } else {
        setState(() {
          inactiveMembers = [];
          filteredMembers = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error processing inactive members data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Manual refresh function
  Future<void> _fetchInactiveMembers() async {
    try {
      final DatabaseReference membersRef = FirebaseDatabase.instance.ref('members');
      final DatabaseEvent event = await membersRef.once();
      _processInactiveMembersData(event);
    } catch (e) {
      print('Error during manual refresh: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to filter members based on search query
  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredMembers = inactiveMembers;
      } else {
        filteredMembers = inactiveMembers.where((member) {
          final fullName =
              '${member['firstName'] ?? ''} ${member['lastName'] ?? ''}'
                  .toLowerCase();
          return fullName.contains(query.toLowerCase());
        }).toList();
      }
      // Reset pagination when filtering
      _currentPage = 1;
      _hasMore = filteredMembers.length > _itemsPerPage;
    });
  }

  // Get paginated members for current page
  List<Map<String, dynamic>> _getPaginatedMembers() {
    int endIndex = _currentPage * _itemsPerPage;
    if (endIndex > filteredMembers.length) {
      endIndex = filteredMembers.length;
      _hasMore = false;
    }
    return filteredMembers.sublist(0, endIndex);
  }

  // Load more members (next page)
  void _loadMore() {
    if (!_isLoadingMore && _hasMore) {
      setState(() {
        _isLoadingMore = true;
      });

      // Simulate loading delay for smooth UX
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() {
          _currentPage++;
          _hasMore = (_currentPage * _itemsPerPage) < filteredMembers.length;
          _isLoadingMore = false;
        });
      });
    }
  }

  // Map legacy duration values to current valid options
  String _mapLegacyDuration(String duration) {
    // Normalize the duration string for comparison
    String normalizedDuration = duration.toLowerCase().trim();
    
    // Handle legacy duration formats
    if (normalizedDuration.contains('0.5 month') || normalizedDuration.contains('0.5month')) {
      return '2 Weeks';
    }
    if (normalizedDuration.contains('30 days') || normalizedDuration.contains('30days')) {
      return '1 Month';
    }
    if (normalizedDuration.contains('60 days') || normalizedDuration.contains('60days')) {
      return '2 Months';
    }
    if (normalizedDuration.contains('90 days') || normalizedDuration.contains('90days')) {
      return '3 Months';
    }
    if (normalizedDuration.contains('180 days') || normalizedDuration.contains('180days')) {
      return '6 Months';
    }
    if (normalizedDuration.contains('365 days') || normalizedDuration.contains('365days')) {
      return '1 Year';
    }
    if (normalizedDuration.contains('14 days') || normalizedDuration.contains('14days')) {
      return '2 Weeks';
    }
    
    // Handle exact matches (case insensitive)
    if (normalizedDuration == '2 weeks' || normalizedDuration == '2weeks') {
      return '2 Weeks';
    }
    if (normalizedDuration == '1 month' || normalizedDuration == '1month') {
      return '1 Month';
    }
    if (normalizedDuration == '2 months' || normalizedDuration == '2months') {
      return '2 Months';
    }
    if (normalizedDuration == '3 months' || normalizedDuration == '3months') {
      return '3 Months';
    }
    if (normalizedDuration == '6 months' || normalizedDuration == '6months') {
      return '6 Months';
    }
    if (normalizedDuration == '1 year' || normalizedDuration == '1year') {
      return '1 Year';
    }
    
    // If it's already a valid duration, return as is
    const validDurations = ['2 Weeks', '1 Month', '2 Months', '3 Months', '6 Months', '1 Year'];
    if (validDurations.contains(duration)) {
      return duration;
    }
    
    // Default fallback
    return '1 Month';
  }

  // Parse duration string to days
  int _parseDurationToDays(String duration) {
    final durationPattern = RegExp(r'(\d+)\s*(\w+)');
    final match = durationPattern.firstMatch(duration);

    if (match == null) {
      return 30; // Default to 30 days if parsing fails
    }

    final value = int.parse(match.group(1)!);
    final unit = match.group(2)!.toLowerCase();

    switch (unit) {
      case 'day':
      case 'days':
        return value;
      case 'week':
      case 'weeks':
        return value * 7;
      case 'month':
      case 'months':
        return value * 30;
      case 'year':
      case 'years':
        return value * 365;
      default:
        return 30; // Default to 30 days
    }
  }

  // Convert Ethiopian date string (YYYY-MM-DD) to Gregorian DateTime
  DateTime _ethiopianToGregorian(String ethiopianDateStr) {
    // Remove time component if present
    if (ethiopianDateStr.contains('T')) {
      ethiopianDateStr = ethiopianDateStr.split('T')[0];
    } else if (ethiopianDateStr.contains(' ')) {
      ethiopianDateStr = ethiopianDateStr.split(' ')[0];
    }

    final parts = ethiopianDateStr.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid date format: $ethiopianDateStr');
    }

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    final ethiopianDate = EthiopianDateTime(year, month, day);
    final gregorianDate = EthiopianDateConverter.convertToGregorianDate(ethiopianDate);
    return gregorianDate;
  }

  // Format date string to display only date part (YYYY-MM-DD)
  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    
    String dateStr = dateValue.toString();
    
    // Remove time component if present
    if (dateStr.contains('T')) {
      dateStr = dateStr.split('T')[0];
    } else if (dateStr.contains(' ')) {
      dateStr = dateStr.split(' ')[0];
    }
    
    return dateStr;
  }

  // Toggle selection mode
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedMemberIds.clear();
      }
    });
  }

  // Toggle member selection
  void _toggleMemberSelection(String memberId) {
    setState(() {
      if (_selectedMemberIds.contains(memberId)) {
        _selectedMemberIds.remove(memberId);
      } else {
        _selectedMemberIds.add(memberId);
      }
    });
  }

  // Bulk delete selected members
  Future<void> _bulkDeleteMembers() async {
    if (_selectedMemberIds.isEmpty) return;

    final count = _selectedMemberIds.length;
    
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete $count Member${count > 1 ? 's' : ''}?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete $count selected member${count > 1 ? 's' : ''}?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected: $count member${count > 1 ? 's' : ''}',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              '⚠️ This action cannot be undone!',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Note: This only deletes from the members path. Report history will be preserved.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
    });

    int successCount = 0;
    int failCount = 0;
    List<String> failedMembers = [];
    final totalCount = _selectedMemberIds.length;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Deleting Members...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting $totalCount member(s)...\nPlease wait...'),
          ],
        ),
      ),
    );

    try {
      // Delete each selected member
      int currentIndex = 0;
      for (String memberId in _selectedMemberIds) {
        currentIndex++;

        try {
          // Get member name for error reporting
          final member = inactiveMembers.firstWhere(
            (m) => m['id'] == memberId,
            orElse: () => {'firstName': 'Unknown', 'lastName': ''},
          );
          final memberName = '${member['firstName']} ${member['lastName']}';

          await _databaseRef.child(memberId).remove();
          successCount++;
          print('✅ Deleted member: $memberName (ID: $memberId)');
        } catch (error) {
          failCount++;
          final member = inactiveMembers.firstWhere(
            (m) => m['id'] == memberId,
            orElse: () => {'firstName': 'Unknown', 'lastName': ''},
          );
          failedMembers.add('${member['firstName']} ${member['lastName']}');
          print('❌ Error deleting member $memberId: $error');
        }
      }

      // Close progress dialog
      Navigator.of(context).pop();

      // Show result
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully deleted $successCount member${successCount > 1 ? 's' : ''}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Deletion Results'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Successfully deleted: $successCount'),
                SizedBox(height: 8),
                Text('❌ Failed: $failCount'),
                if (failedMembers.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text('Failed members:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...failedMembers.map((name) => Text('  • $name')),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }

      // Exit selection mode and refresh
      setState(() {
        _isSelectionMode = false;
        _selectedMemberIds.clear();
        _isDeleting = false;
      });

      _fetchInactiveMembers();
    } catch (error) {
      Navigator.of(context).pop(); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error during bulk deletion: $error'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      setState(() {
        _isDeleting = false;
      });
    }
  }

  // Delete member from database
  Future<void> _deleteMember(String memberId, String fullName) async {
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Member?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete this member?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Member: $fullName', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('ID: $memberId', style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              '⚠️ This action cannot be undone!',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Note: This only deletes from the members path. Report history will be preserved.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete member from members path
        await _databaseRef.child(memberId).remove();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Member deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Refresh the list
        _fetchInactiveMembers();
        
        print('✅ Deleted member: $fullName (ID: $memberId)');
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting member: $error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        print('❌ Error deleting member: $error');
      }
    }
  }

  Future<void> _reRegister(
      String memberId,
      String fullName,
      String currentWeight,
      String currentDuration,
      String currentRegisterDate,
      Map<String, dynamic> member) async {
    // Load durations dynamically from DB
    List<Map<String, dynamic>> durationsList = [];
    try {
      final DatabaseReference durationsRef = FirebaseDatabase.instance.ref('durations');
      final DatabaseEvent event = await durationsRef.once();
      if (event.snapshot.value != null) {
        final durationsMap = event.snapshot.value as Map<dynamic, dynamic>;
        durationsMap.forEach((key, value) {
          if (value is Map) {
            durationsList.add({
              'id': key,
              'name': value['name'],
              'price': value['price'],
              'days': value['days'],
            });
          }
        });
      }
      durationsList.sort((a, b) => (a['days'] ?? 0).compareTo(b['days'] ?? 0));
    } catch (e) {}
    TextEditingController weightController =
        TextEditingController(text: currentWeight);
    TextEditingController registerDateController =
        TextEditingController(text: _formatDate(currentRegisterDate));
    TextEditingController remainingController =
        TextEditingController(text: member['remaining']?.toString() ?? '0');

    // Map legacy duration values to current valid options
    String? _duration = _mapLegacyDuration(currentDuration); // Preselect current duration
    int? _remaining = member['remaining'];
    String _paymentMethod = member['paymentMethod'] ?? 'CASH';
    File? _paymentImage;
    String? _paymentImageUrl = member['paymentImageUrl'];
    bool _isUploadingImage = false;
    double _uploadProgress = 0.0;
    bool _useUnsignedUpload = false;
    bool _isRegistering = false; // Track registration state

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing during registration
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
        return AlertDialog(
          title: Text('Re-register Member: $fullName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display member details
                Text('Member ID: $memberId'),
                Text('Full Name: $fullName'),
                SizedBox(height: 16.0),

                // Weight input
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Weight (kg)'),
                ),

                // Remaining input
                TextField(
                  controller: remainingController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'ቀሪ (Remaining)'),
                  onChanged: (value) {
                    _remaining = int.tryParse(value);
                  },
                ),

                // Register Date input
                TextField(
                  controller: registerDateController,
                  decoration: InputDecoration(
                    labelText: 'Register Date (YYYY-MM-DD)',
                    hintText: 'YYYY-MM-DD',
                  ),
                ),

                // Duration dropdown
                DropdownButtonFormField<String>(
                  value: _duration,
                  hint: Text('Choose duration'),
                  onChanged: (newValue) {
                    setState(() {
                      _duration = newValue ?? _duration;
                    });
                  },
                  validator: (value) => (value == null || value.isEmpty) ? 'Please choose a duration' : null,
                  items: durationsList.isNotEmpty
                      ? durationsList
                          .map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(
                                value: (d['name'] as String?) ?? '',
                                child: Text((d['name'] as String?) ?? ''),
                              ))
                          .toList()
                      : [
                          DropdownMenuItem<String>(value: '', child: Text('No durations available')),
                  ],
                  decoration: InputDecoration(labelText: 'Duration'),
                ),

                // Payment Method dropdown
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  onChanged: (newValue) {
                    setState(() {
                      _paymentMethod = newValue!;
                    });
                  },
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('CASH')),
                    DropdownMenuItem(value: 'MOBILE_BANKING', child: Text('MOBILE_BANKING')),
                  ],
                  decoration: InputDecoration(labelText: 'Payment Method'),
                ),

                // Payment image upload section (only show if MOBILE_BANKING is selected)
                if (_paymentMethod == 'MOBILE_BANKING') ...[
                  SizedBox(height: 16),
                  _buildPaymentImageSection(context, _paymentImage, _paymentImageUrl, _isUploadingImage, _uploadProgress, _useUnsignedUpload, (image) => _paymentImage = image, (url) => _paymentImageUrl = url, (uploading) => _isUploadingImage = uploading, (progress) => _uploadProgress = progress, (unsigned) => _useUnsignedUpload = unsigned),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                  onPressed: _isRegistering ? null : () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
                  onPressed: _isRegistering ? null : () async {
                    // Set registering state
                    setState(() {
                      _isRegistering = true;
                    });
                    
                String newWeightStr = weightController.text;
                String newRegisterDateStr = registerDateController.text.trim();

                // Simple date validation - only check essential issues
                if (newRegisterDateStr.isEmpty) {
                  setState(() {
                    _isRegistering = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Please enter a registration date.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                // Check for MM-DD-YYYY format (wrong order)
                RegExp wrongOrderPattern = RegExp(r'^\d{2}-\d{2}-\d{4}$');
                if (wrongOrderPattern.hasMatch(newRegisterDateStr)) {
                  setState(() {
                    _isRegistering = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Wrong date order. Use YYYY-MM-DD format, not MM-DD-YYYY.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                DateTime? newRegisterDate;

                // Parse and validate the date
                try {
                  newRegisterDate = DateTime.parse(newRegisterDateStr);
                  
                  // Check for invalid month
                  if (newRegisterDate.month < 1 || newRegisterDate.month > 12) {
                    setState(() {
                      _isRegistering = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Invalid month. Month must be between 01 and 12.'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }
                  
                  // Check if date is too old
                  DateTime minDate = DateTime(2000, 1, 1);
                  if (newRegisterDate.isBefore(minDate)) {
                    setState(() {
                      _isRegistering = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Date is too old. Use dates from 2000 onwards.'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }
                  
                  // Check if date is in the future
                  if (newRegisterDate.isAfter(DateTime.now())) {
                    setState(() {
                      _isRegistering = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Registration date cannot be in the future.'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }
                  
                } catch (e) {
                  setState(() {
                    _isRegistering = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Invalid date format. Please use YYYY-MM-DD (e.g., 2024-01-15).'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                // Validate payment method
                if (_paymentMethod == 'MOBILE_BANKING' && _paymentImageUrl == null) {
                  setState(() {
                    _isRegistering = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please upload payment receipt for mobile banking'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validate duration selected
                if (_duration == null || _duration!.isEmpty) {
                  setState(() {
                    _isRegistering = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please choose a duration.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validate that the membership won't be expired immediately
                // The date entered is in Ethiopian calendar format YYYY-MM-DD
                // Calculate expiry date using Ethiopian calendar
                final parts = newRegisterDateStr.split('-');
                if (parts.length != 3) {
                  setState(() {
                    _isRegistering = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Invalid Ethiopian date format. Please use YYYY-MM-DD.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                
                final year = int.parse(parts[0]);
                final month = int.parse(parts[1]);
                final day = int.parse(parts[2]);
                
                // Validate Ethiopian date ranges
                if (year < 2000) {
                  setState(() {
                    _isRegistering = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Year must be 2000 or later.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                
                if (month < 1 || month > 13) {
                  setState(() {
                    _isRegistering = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Month must be between 01 and 13 (Ethiopian calendar).'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                
                if (day < 1 || day > 30) {
                  setState(() {
                    _isRegistering = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Day must be between 01 and 30.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                
                // Create Ethiopian date for registration
                final ethiopianRegisterDate = EthiopianDateTime(year, month, day);
                
                // Calculate expiry date in Ethiopian calendar
                int durationDays = _parseDurationToDays(_duration!);
                int remainingDays = durationDays;
                
                EthiopianDateTime ethiopianExpiryDate = ethiopianRegisterDate;
                
                // Add days to Ethiopian date
                while (remainingDays > 0) {
                  // Ethiopian months have 30 days each, except Pagume (13th month) which has 5 or 6 days
                  int daysInCurrentMonth = (ethiopianExpiryDate.month == 13) ? 
                    (ethiopianExpiryDate.year % 4 == 3 ? 6 : 5) : 30;
                  
                  int daysToAdd = remainingDays > daysInCurrentMonth ? daysInCurrentMonth : remainingDays;
                  
                  if (ethiopianExpiryDate.day + daysToAdd > daysInCurrentMonth) {
                    // Move to next month
                    if (ethiopianExpiryDate.month == 13) {
                      ethiopianExpiryDate = EthiopianDateTime(ethiopianExpiryDate.year + 1, 1, daysToAdd - (daysInCurrentMonth - ethiopianExpiryDate.day));
                    } else {
                      ethiopianExpiryDate = EthiopianDateTime(ethiopianExpiryDate.year, ethiopianExpiryDate.month + 1, daysToAdd - (daysInCurrentMonth - ethiopianExpiryDate.day));
                    }
                  } else {
                    ethiopianExpiryDate = EthiopianDateTime(ethiopianExpiryDate.year, ethiopianExpiryDate.month, ethiopianExpiryDate.day + daysToAdd);
                  }
                  
                  remainingDays -= daysToAdd;
                }
                
                // Get current Ethiopian date
                DateTime now = DateTime.now();
                final currentEthiopianDate = EthiopianDateConverter.convertToEthiopianDate(EthiopianDateTime(now.year, now.month, now.day));
                
                // Check if expiry date is in the past (Ethiopian calendar)
                bool isExpired = false;
                int daysExpired = 0;
                
                if (ethiopianExpiryDate.year < currentEthiopianDate.year ||
                    (ethiopianExpiryDate.year == currentEthiopianDate.year && ethiopianExpiryDate.month < currentEthiopianDate.month) ||
                    (ethiopianExpiryDate.year == currentEthiopianDate.year && ethiopianExpiryDate.month == currentEthiopianDate.month && ethiopianExpiryDate.day < currentEthiopianDate.day)) {
                  isExpired = true;
                  
                  // Calculate days expired (approximate)
                  DateTime expiryGregorian = EthiopianDateConverter.convertToGregorianDate(ethiopianExpiryDate);
                  daysExpired = now.difference(expiryGregorian).inDays;
                }
                
                if (isExpired) {
                  setState(() {
                    _isRegistering = false;
                  });
                  String ethiopianExpiryDateStr = '${ethiopianExpiryDate.year}-${ethiopianExpiryDate.month.toString().padLeft(2, '0')}-${ethiopianExpiryDate.day.toString().padLeft(2, '0')}';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Warning: This duration expired on $ethiopianExpiryDateStr ($daysExpired days ago)! Please choose a more recent date or longer duration.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 6),
                    ),
                  );
                  return;
                }
                
                // Warn if membership will expire very soon (within 7 days)
                // But for 2 Weeks duration, use a lower threshold since it's a short-term membership
                int remainingDaysUntilExpiry = 0;
                
                // Calculate remaining days until expiry (Ethiopian calendar)
                if (ethiopianExpiryDate.year == currentEthiopianDate.year && 
                    ethiopianExpiryDate.month == currentEthiopianDate.month) {
                  remainingDaysUntilExpiry = ethiopianExpiryDate.day - currentEthiopianDate.day;
                } else {
                  // Convert to Gregorian for easier calculation
                  DateTime expiryGregorian = EthiopianDateConverter.convertToGregorianDate(ethiopianExpiryDate);
                  remainingDaysUntilExpiry = expiryGregorian.difference(now).inDays;
                }
                
                int warningThreshold = (_duration == '2 Weeks') ? 3 : 7; // Lower threshold for 2 Weeks
                if (remainingDaysUntilExpiry <= warningThreshold) {
                  String ethiopianExpiryDateStr = '${ethiopianExpiryDate.year}-${ethiopianExpiryDate.month.toString().padLeft(2, '0')}-${ethiopianExpiryDate.day.toString().padLeft(2, '0')}';
                  bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Duration Expires Soon'),
                      content: Text('This duration will expire on $ethiopianExpiryDateStr (in $remainingDaysUntilExpiry day(s)).${_duration == '2 Weeks' ? '\n\nNote: 2 Weeks is a short-term duration.' : ''} Are you sure you want to continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text('Continue'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm != true) {
                    setState(() {
                      _isRegistering = false;
                    });
                    return;
                  }
                }

                // No register error tracking for re-registration from inactive status

                try {
                  // Generate a NEW member ID for re-registration
                  final DatabaseReference newMemberRef = _databaseRef.push();
                  String newMemberId = newMemberRef.key!;
                  
                  // Prepare complete member data including all existing fields
                  // Compute price from selected duration (DB list)
                  int computedPrice = 0;
                  try {
                    final idx = durationsList.indexWhere((d) => (d['name'] as String?) == _duration);
                    if (idx != -1) {
                      final p = durationsList[idx]['price'];
                      if (p is int) computedPrice = p; else if (p is num) computedPrice = p.toInt();
                    }
                  } catch (e) {}

                  Map<String, dynamic> completeMemberData = {
                    'firstName': member['firstName'],
                    'lastName': member['lastName'],
                    'profileImageUrl': member['profileImageUrl'],
                    'lockerKey': member['lockerKey'],
                    'phoneNumber': member['phoneNumber'],
                  'registerDate': newRegisterDate != null
                      ? '${newRegisterDate.year}-${newRegisterDate.month.toString().padLeft(2, '0')}-${newRegisterDate.day.toString().padLeft(2, '0')}'
                      : '',
                  'weight': int.tryParse(newWeightStr) ?? 0,
                    'remaining': _remaining,
                  'duration': _duration,
                    'price': computedPrice,
                    'paymentMethod': _paymentMethod,
                    'paymentImageUrl': _paymentImageUrl,
                    'status': 'active',
                    'reRegisteredFrom': memberId, // Store the old member ID for tracking
                    'reRegisterDate': DateTime.now().toIso8601String(),
                    'lastUpdatedDate': DateTime.now().toIso8601String(),
                    'lastUpdateType': 're-registration', // Track that this was a re-registration
                    'originalRegisterDate': member['registerDate'], // Keep original registration date
                  };
                  
                  // Create NEW member entry with new ID
                  await newMemberRef.set(completeMemberData);
                  print('✅ Created NEW member with ID: $newMemberId');
                  
                  // Delete the old inactive member entry
                  await _databaseRef.child(memberId).remove();
                  print('✅ Deleted old member with ID: $memberId');

                  // Create report entry with the SAME new member ID
                  final DatabaseReference reporteRef = FirebaseDatabase.instance.ref('reporte');
                  
                  Map<String, dynamic> reportData = {
                    'firstName': member['firstName'],
                    'lastName': member['lastName'],
                    'fullName': fullName,
                    'weight': int.tryParse(newWeightStr) ?? 0,
                    'remaining': _remaining,
                    'registerDate': newRegisterDate != null
                        ? '${newRegisterDate.year}-${newRegisterDate.month.toString().padLeft(2, '0')}-${newRegisterDate.day.toString().padLeft(2, '0')}'
                        : '',
                    'duration': _duration,
                    'price': computedPrice,
                    'paymentMethod': _paymentMethod,
                    'paymentImageUrl': _paymentImageUrl,
                    'profileImageUrl': member['profileImageUrl'],
                    'lockerKey': member['lockerKey'],
                    'phoneNumber': member['phoneNumber'],
                    'status': 're-registered from inactive',
                    'reRegisterDate': DateTime.now().toIso8601String(),
                    'previousMemberId': memberId, // Track the old member ID
                    'reRegisteredFrom': memberId, // Also track for consistency
                    'lastUpdatedDate': DateTime.now().toIso8601String(),
                    'lastUpdateType': 're-registration',
                    'originalRegisterDate': member['registerDate'], // Keep original date
                  };

                  // Use the SAME new member ID for the report entry
                  // This ensures that when the member is updated in active page,
                  // the report will also be updated with the same ID
                  await reporteRef.child(newMemberId).set(reportData);
                  
                  print('✅ Created NEW report entry with same ID: $newMemberId');

                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Member re-registered successfully with new ID'),
                    backgroundColor: Colors.green,
                  ));
                  Navigator.of(context).pop();
                  _fetchInactiveMembers(); // Refresh list
                } catch (error) {
                  setState(() {
                    _isRegistering = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error re-registering member: $error'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
                  child: _isRegistering
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
                          Text('Re-registering...'),
                        ],
                      )
                    : Text('Re-register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode 
          ? '${_selectedMemberIds.length} Selected' 
          : 'Inactive Members'),
        backgroundColor: Colors.deepPurple,
        actions: [
          if (isAdmin) ...[
            // Toggle selection mode button
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.close : Icons.check_circle_outline),
              tooltip: _isSelectionMode ? 'Cancel Selection' : 'Select Members',
              onPressed: _toggleSelectionMode,
              color: _isSelectionMode ? Colors.red : Colors.amber,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search by Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _filterMembers(value);
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredMembers.isEmpty
                    ? const Center(child: Text('No inactive members found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10.0),
                        itemCount: _getPaginatedMembers().length + (_hasMore ? 1 : 0), // +1 for Load More button
                        itemBuilder: (context, index) {
                          final paginatedList = _getPaginatedMembers();
                          
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
                                        label: Text('Load More (${filteredMembers.length - paginatedList.length} more)'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                      ),
                              ),
                            );
                          }
                          
                          final member = paginatedList[index];
                          final memberId = member['id'] as String;
                          final isSelected = _selectedMemberIds.contains(memberId);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            elevation: isSelected ? 12 : 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: isSelected 
                                ? BorderSide(color: Colors.amber, width: 2)
                                : BorderSide.none,
                            ),
                            color: isSelected ? Colors.amber.shade50 : null,
                            child: InkWell(
                              onTap: _isSelectionMode 
                                ? () => _toggleMemberSelection(memberId)
                                : null,
                              borderRadius: BorderRadius.circular(15),
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Checkbox (only in selection mode)
                                    if (_isSelectionMode) ...[
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (value) => _toggleMemberSelection(memberId),
                                        activeColor: Colors.amber,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    // Profile Avatar
                                    _buildProfileAvatar(
                                      member['profileImageUrl'],
                                      member['firstName'] ?? 'Unknown',
                                      member['lastName'] ?? 'Unknown',
                                    ),
                                    const SizedBox(width: 15),
                                    // Member Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${(index + 1)}. ${member['firstName'] ?? 'Unknown'} ${member['lastName'] ?? 'Unknown'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                              'Weight: ${member['weight'] ?? 'N/A'} kg'),
                                          Text(
                                              'Register Date: ${_formatDate(member['registerDate'])}'),
                                          Text(
                                              'Duration: ${member['duration'] ?? 'N/A'}'),
                                          Text('ቀሪ (Remaining): ${member['remaining'] ?? 0} Birr'),
                                          Text('Status: Inactive'),
                                        ],
                                      ),
                                    ),
                                    // Action buttons column (hidden in selection mode)
                                    if (!_isSelectionMode)
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      // Re-register Button
                                      ElevatedButton(
                                        onPressed: isAdmin
                                            ? () {
                                                _reRegister(
                                                  member['id'] ?? 'Unknown ID',
                                                  '${member['firstName'] ?? 'Unknown'} ${member['lastName'] ?? 'Unknown'}',
                                                  member['weight']?.toString() ?? 'N/A',
                                                  member['duration'] ?? '1 Month',
                                                      _formatDate(member['registerDate']),
                                                  member, // Add member parameter
                                                );
                                              }
                                            : null, // Disable the button if the user is not an admin
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.deepPurple,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text(isAdmin ? 'Re-register' : 'No Access'),
                                          ),
                                          SizedBox(height: 8),
                                          // Delete Button (Red)
                                          ElevatedButton.icon(
                                            onPressed: isAdmin
                                                ? () {
                                                    _deleteMember(
                                                      member['id'] ?? 'Unknown ID',
                                                      '${member['firstName'] ?? 'Unknown'} ${member['lastName'] ?? 'Unknown'}',
                                                    );
                                                  }
                                                : null,
                                            icon: Icon(Icons.delete_forever, size: 20),
                                            label: Text('Delete'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      // Bottom action bar for bulk delete (only in selection mode)
      bottomNavigationBar: _isSelectionMode && isAdmin
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedMemberIds.length} member${_selectedMemberIds.length > 1 ? 's' : ''} selected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        // Cancel button
                        TextButton(
                          onPressed: _isDeleting ? null : _toggleSelectionMode,
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Delete button
                        ElevatedButton.icon(
                          onPressed: (_isDeleting || _selectedMemberIds.isEmpty)
                              ? null
                              : _bulkDeleteMembers,
                          icon: _isDeleting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(Icons.delete_forever),
                          label: Text(
                            _isDeleting
                                ? 'Deleting...'
                                : 'Delete (${_selectedMemberIds.length})',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  /// Build payment image upload section
  Widget _buildPaymentImageSection(
    BuildContext context,
    File? paymentImage,
    String? paymentImageUrl,
    bool isUploadingImage,
    double uploadProgress,
    bool useUnsignedUpload,
    Function(File?) onImageChanged,
    Function(String?) onImageUrlChanged,
    Function(bool) onUploadingChanged,
    Function(double) onProgressChanged,
    Function(bool) onUnsignedChanged,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'Payment Receipt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const Spacer(),
                // Debug button for Cloudinary testing
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cloudinary Config: ✅ Configured'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bug_report, size: 20),
                  tooltip: 'Test Cloudinary Config',
                  color: Colors.orange,
                ),
                // Test image picker button
                IconButton(
                  onPressed: () async {
                    try {
                      if (kIsWeb) {
                        final xFile = await ImagePickerService.testImagePickerXFile();
                        if (xFile != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Image Picker Test Success (Web): ${xFile.path}'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } else {
                        final imageFile = await ImagePickerService.testImagePicker();
                        if (imageFile != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Image Picker Test Success (Mobile): ${imageFile.path}'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Image Picker Error: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.photo_camera, size: 20),
                  tooltip: 'Test Image Picker',
                  color: Colors.blue,
                ),
                // Test permissions button
                IconButton(
                  onPressed: () async {
                    try {
                      final permissions = await PermissionChecker.checkAllPermissions();
                      final cameraGranted = permissions['camera'] ?? false;
                      final storageGranted = permissions['storage'] ?? false;
                      
                      String message = 'Permissions: ';
                      if (cameraGranted && storageGranted) {
                        message += '✅ All granted';
                      } else {
                        message += '❌ Camera: ${cameraGranted ? "✅" : "❌"}, Storage: ${storageGranted ? "✅" : "❌"}';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: (cameraGranted && storageGranted) ? Colors.green : Colors.orange,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Permission Test Error: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.security, size: 20),
                  tooltip: 'Test Permissions',
                  color: Colors.purple,
                ),
                // Toggle between signed/unsigned uploads
                Switch(
                  value: useUnsignedUpload,
                  onChanged: (value) {
                    onUnsignedChanged(value);
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Upload a photo of your mobile banking payment receipt',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Text(
                  useUnsignedUpload ? 'Unsigned' : 'Signed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: useUnsignedUpload ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Image preview or upload button
            if (paymentImageUrl != null || paymentImage != null) ...[
              // Show uploaded image
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: paymentImage != null
                      ? Image.file(
                          paymentImage,
                          fit: BoxFit.cover,
                        )
                      : paymentImageUrl != null
                          ? Image.network(
                              paymentImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.error,
                                    color: Colors.red,
                                    size: 50,
                                  ),
                                );
                              },
                            )
                          : const SizedBox(),
                ),
              ),
              const SizedBox(height: 12),
              
              // Show Cloudinary URL if available
              if (paymentImageUrl != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_done, color: Colors.green.shade600, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Uploaded to Cloudinary',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paymentImageUrl,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade600,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handlePaymentImageSelection(
                        context,
                        onImageChanged,
                        onImageUrlChanged,
                        onUploadingChanged,
                        onProgressChanged,
                        useUnsignedUpload,
                      ),
                      icon: const Icon(Icons.edit),
                      label: const Text('Change Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      onImageChanged(null);
                      onImageUrlChanged(null);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Show upload button
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap: isUploadingImage ? null : () => _handlePaymentImageSelection(
                    context,
                    onImageChanged,
                    onImageUrlChanged,
                    onUploadingChanged,
                    onProgressChanged,
                    useUnsignedUpload,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: isUploadingImage
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Modern circular progress indicator
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CircularProgressIndicator(
                                      value: uploadProgress / 100,
                                      strokeWidth: 6,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${uploadProgress.toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Linear progress bar
                              Container(
                                width: 200,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.grey.shade300,
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: uploadProgress / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.deepPurple,
                                          Colors.purpleAccent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Uploading to Cloudinary...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (paymentImage != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'File size: ${ImagePickerService.getFileSize(paymentImage)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to upload receipt',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Handle payment image selection and upload
  Future<void> _handlePaymentImageSelection(
    BuildContext context,
    Function(File?) onImageChanged,
    Function(String?) onImageUrlChanged,
    Function(bool) onUploadingChanged,
    Function(double) onProgressChanged,
    bool useUnsignedUpload,
  ) async {
    try {
      // Check permissions first
      final permissions = await PermissionChecker.checkAllPermissions();
      final cameraGranted = permissions['camera'] ?? false;
      
      if (!cameraGranted) {
        final granted = await PermissionChecker.requestCameraPermission();
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to select images. Please enable it in settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }
      
      File? imageFile;
      XFile? xFile;
      
      if (kIsWeb) {
        xFile = await ImagePickerService.showImageSourceDialogXFile(context);
      } else {
        imageFile = await ImagePickerService.showImageSourceDialog(context);
      }
      
      if (!context.mounted) return;
      
      // Validate the selected image
      bool isValidImage = false;
      if (kIsWeb && xFile != null) {
        isValidImage = xFile.path.isNotEmpty;
      } else if (!kIsWeb && imageFile != null) {
        isValidImage = ImagePickerService.validateImage(imageFile);
      }
      
      if (isValidImage) {
        onImageChanged(imageFile);
        onUploadingChanged(true);
        onProgressChanged(0.0);
        
        String? imageUrl;
        
        if (kIsWeb && xFile != null) {
          imageUrl = useUnsignedUpload 
            ? await CloudinaryServiceUnsigned.uploadImageFromXFile(
                xFile,
                folder: 'gym_payments',
                onProgress: (progress) {
                  onProgressChanged(progress);
                },
              )
            : await CloudinaryServiceWeb.uploadImageFromXFile(
                xFile,
                folder: 'gym_payments',
                onProgress: (progress) {
                  onProgressChanged(progress);
                },
              );
        } else if (!kIsWeb && imageFile != null) {
          imageUrl = useUnsignedUpload 
            ? await CloudinaryServiceUnsigned.uploadImage(
                imageFile,
                folder: 'gym_payments',
                onProgress: (progress) {
                  onProgressChanged(progress);
                },
              )
            : await CloudinaryService.uploadImage(
                imageFile,
                folder: 'gym_payments',
                onProgress: (progress) {
                  onProgressChanged(progress);
                },
              );
        }
        
        if (imageUrl != null) {
          onProgressChanged(100.0);
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (context.mounted) {
            onImageUrlChanged(imageUrl);
            onUploadingChanged(false);
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment receipt uploaded successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (context.mounted) {
            onImageChanged(null);
            onUploadingChanged(false);
            onProgressChanged(0.0);
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload payment receipt. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build profile avatar widget with click to expand
  Widget _buildProfileAvatar(String? profileImageUrl, String firstName, String lastName) {
    return GestureDetector(
      onTap: () {
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          _showExpandedProfileImage(profileImageUrl, firstName, lastName);
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

  /// Show expanded profile image in a dialog
  void _showExpandedProfileImage(String imageUrl, String firstName, String lastName) {
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
                          '$firstName $lastName',
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
