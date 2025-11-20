import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ethiopian_calendar/ethiopian_date_converter.dart';
import 'package:ethiopian_calendar/model/ethiopian_date.dart';
import 'dart:async';

class ActivePage extends StatefulWidget {
  const ActivePage({super.key});

  @override
  _ActivePageState createState() => _ActivePageState();
}

class _ActivePageState extends State<ActivePage>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref('members');
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = 
      GlobalKey<ScaffoldMessengerState>(); // Key for isolated notifications
  List<Map<String, dynamic>> activeMembers = [];
  List<Map<String, dynamic>> filteredMembers = [];
  bool _isLoading = true;
  Timer? countdownTimer;
  TextEditingController searchController = TextEditingController();
  bool _showRegisterErrorDetails = false; // Toggle for showing register error details
  StreamSubscription<DatabaseEvent>? _membersSubscription; // Live update listener
  
  // Pagination variables
  int _currentPage = 1;
  final int _itemsPerPage = 20; // Load 20 members at a time
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _setupLiveUpdates(); // Setup real-time listener
    _startCountdownTimer();
  }


  void _startCountdownTimer() {
    countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        // Force the widget to rebuild every minute to reflect the countdown
      });
    });
  }

  @override
  void dispose() {
    _membersSubscription?.cancel(); // Cancel listener when page is disposed
    countdownTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  // Setup live updates using Firebase real-time listener
  void _setupLiveUpdates() {
    final DatabaseReference membersRef = FirebaseDatabase.instance.ref('members');
    
    // Listen to changes in the members path
    _membersSubscription = membersRef.onValue.listen((DatabaseEvent event) {
      if (mounted) {
        _processActiveMembersData(event);
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

  // Process active members data from Firebase event
  void _processActiveMembersData(DatabaseEvent event) {
    try {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> membersMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> loadedMembers = [];
        DateTime now = DateTime.now();

        for (var entry in membersMap.entries) {
          String memberId = entry.key; // Get the member ID
          Map<String, dynamic> memberData =
              Map<String, dynamic>.from(entry.value);

          try {
            String registerDateStr = memberData['registerDate'] ?? '';
            String durationStr = memberData['duration'] ?? '';
            String status = memberData['status'] ?? '';
            String phoneNumber = memberData['phoneNumber'] ??
                'Not Provided'; // Default if missing

            if (durationStr.isEmpty) continue;

            DateTime registerDate = _ethiopianToGregorian(registerDateStr);
            int remainingDays = _getRemainingDays(registerDate, durationStr);

            // Check for active members
            if (status == 'active' && remainingDays > 0) {
              loadedMembers.add({
                'id': memberId, // Add the member ID to the data
                ...memberData,
                'phoneNumber': phoneNumber, // Ensure phoneNumber is added
              });
            } else if (remainingDays <= 0) {
              // Notify user and move to inactive
              _notifyExpiry(memberData['firstName'], memberData['lastName']);
              _moveToInactivePage(memberId); // Change to inactive
            }
          } catch (e) {
            print('Error processing member data: $e');
          }
        }

        setState(() {
          activeMembers = loadedMembers;
          filteredMembers = activeMembers;
          // Reset pagination when data is refreshed
          _currentPage = 1;
          _hasMore = filteredMembers.length > _itemsPerPage;
          _isLoading = false;
        });
      } else {
        setState(() {
          activeMembers = [];
          filteredMembers = [];
          _currentPage = 1;
          _hasMore = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error processing active members data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Manual refresh function
  Future<void> _fetchActiveMembers() async {
    try {
      final DatabaseReference membersRef = FirebaseDatabase.instance.ref('members');
      final DatabaseEvent event = await membersRef.once();
      _processActiveMembersData(event);
    } catch (e) {
      print('Error during manual refresh: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Converts Ethiopian date string to Gregorian
  DateTime _ethiopianToGregorian(String ethiopianDateStr) {
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
    final gregorianDate =
        EthiopianDateConverter.convertToGregorianDate(ethiopianDate);
    return gregorianDate;
  }


  // Calculates remaining days until the membership expires
  int _getRemainingDays(DateTime registerDate, String duration) {
    int totalDays = _parseDurationToDays(duration);
    DateTime expiryDate = registerDate.add(Duration(days: totalDays));
    return expiryDate.difference(DateTime.now()).inDays;
  }

  // Parsing duration like "30 days" into days
  int _parseDurationToDays(String duration) {
    final durationPattern = RegExp(r'(\d+)\s*(\w+)');
    final match = durationPattern.firstMatch(duration);

    if (match == null) {
      throw FormatException("Invalid duration format: $duration");
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
        throw FormatException("Unknown duration unit: $unit");
    }
  }

  void _notifyExpiry(String firstName, String lastName) {
    // Only show notification if this page is still mounted and visible
    if (mounted && _scaffoldMessengerKey.currentState != null) {
      // Use the page's ScaffoldMessenger key to ensure notification only shows on Active page
      _scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text('🔴 $firstName $lastName\'s package has expired.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3), // Auto-dismiss after 3 seconds
          behavior: SnackBarBehavior.floating, // Floating style
          margin: EdgeInsets.only(bottom: 100, left: 20, right: 20), // Increased bottom margin to avoid Load More button
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              // Dismiss notification
              _scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  Future<void> _moveToInactivePage(String memberId) async {
    await _databaseRef.child(memberId).update({'status': 'inactive'});
  }

  // Function to filter members based on search query
  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredMembers = activeMembers;
      } else {
        filteredMembers = activeMembers.where((member) {
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

  // Re-register function for updating duration
  Future<void> _reRegister(String memberId, int currentWeight, String currentDuration, Map<String, dynamic> member) async {
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
    // Get the CURRENT register date (not from errors array)
    // The member['registerDate'] field always stores the LATEST/CURRENT registration date
    String currentRegisterDate = '';
    try {
      String registerDateRaw = member['registerDate']?.toString() ?? '';
      if (registerDateRaw.isNotEmpty) {
        // Remove time component if present
        if (registerDateRaw.contains('T')) {
          currentRegisterDate = registerDateRaw.split('T')[0];
        } else if (registerDateRaw.contains(' ')) {
          currentRegisterDate = registerDateRaw.split(' ')[0];
        } else {
          currentRegisterDate = registerDateRaw;
        }
      }
    } catch (e) {
      print('Error parsing register date: $e');
      currentRegisterDate = '';
    }
    
    // Get remaining value with proper null safety
    int currentRemaining = 0;
    try {
      if (member['remaining'] != null) {
        currentRemaining = int.parse(member['remaining'].toString());
      }
    } catch (e) {
      print('Error parsing remaining: $e');
      currentRemaining = 0;
    }
    
    TextEditingController weightController =
        TextEditingController(text: currentWeight.toString());
    TextEditingController registerDateController =
        TextEditingController(text: currentRegisterDate);
    TextEditingController remainingController =
        TextEditingController(text: currentRemaining.toString());

    // Variables for dropdown values
    String _duration = currentDuration; // Preselect current duration
    int? _remaining = currentRemaining; // Initialize with current remaining value
    bool _isUpdating = false; // Track update state

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing during update
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Re-register Member'),
              content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Weight (kg)'),
                ),
                TextField(
                  controller: remainingController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'ቀሪ (Remaining)'),
                  onChanged: (value) {
                    // Store the remaining value for later use
                    _remaining = int.tryParse(value);
                  },
                ),
                TextField(
                  controller: registerDateController,
                  decoration: InputDecoration(
                    labelText: 'Register Date (YYYY-MM-DD)',
                    hintText: 'YYYY-MM-DD',
                    helperText: currentRegisterDate.isNotEmpty 
                        ? 'Current: $currentRegisterDate' 
                        : 'Enter registration date',
                    helperStyle: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
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
                  onPressed: _isUpdating ? null : () async {
                    // Set updating state
                    setState(() {
                      _isUpdating = true;
                    });
                String newWeightStr = weightController.text.trim();
                String newRegisterDateStr = registerDateController.text.trim();
                DateTime? newRegisterDate;

                // Validate weight input
                if (newWeightStr.isEmpty) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Please enter a weight value.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                int? weightValue = int.tryParse(newWeightStr);
                if (weightValue == null) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Please enter a valid weight (numbers only).'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                if (weightValue < 0 || weightValue > 500) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Weight must be between 0 and 500 kg.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                // Simple date validation - only check essential issues
                if (newRegisterDateStr.isEmpty) {
                  setState(() {
                    _isUpdating = false;
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
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Wrong date order. Use YYYY-MM-DD format, not MM-DD-YYYY.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                // Parse and validate the date
                try {
                  newRegisterDate = DateTime.parse(newRegisterDateStr);
                  
                  // Check for invalid month
                  if (newRegisterDate.month < 1 || newRegisterDate.month > 12) {
                    setState(() {
                      _isUpdating = false;
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
                      _isUpdating = false;
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
                      _isUpdating = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Registration date cannot be in the future.'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }
                  
                } catch (e) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Invalid date format. Please use YYYY-MM-DD (e.g., 2024-01-15).'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                // Get current register error array or create new one
                final snapshot = await _databaseRef.child(memberId).once();
                Map<String, dynamic> currentMemberData = {};
                if (snapshot.snapshot.value != null) {
                  currentMemberData = Map<String, dynamic>.from(snapshot.snapshot.value as Map<dynamic, dynamic>);
                }

                List<Map<String, dynamic>> registerErrors = [];
                if (currentMemberData['registerErrors'] != null) {
                  registerErrors = List<Map<String, dynamic>>.from(
                    (currentMemberData['registerErrors'] as List).map((e) => Map<String, dynamic>.from(e))
                  );
                }

                // Only add register error if the registration date has actually changed
                String oldRegisterDate = '';
                try {
                  String oldDateRaw = member['registerDate']?.toString() ?? '';
                  if (oldDateRaw.contains('T')) {
                    oldRegisterDate = oldDateRaw.split('T')[0];
                  } else if (oldDateRaw.contains(' ')) {
                    oldRegisterDate = oldDateRaw.split(' ')[0];
                  } else {
                    oldRegisterDate = oldDateRaw;
                  }
                } catch (e) {
                  print('Error parsing old register date: $e');
                }

                String newRegisterDateOnly = '${newRegisterDate.year}-${newRegisterDate.month.toString().padLeft(2, '0')}-${newRegisterDate.day.toString().padLeft(2, '0')}';
                
                // Only add to registerErrors if the date actually changed
                if (oldRegisterDate != newRegisterDateOnly) {
                  registerErrors.add({
                    'errorType': 'date_update',
                    'previousDate': member['registerDate'],
                    'newDate': newRegisterDate.toIso8601String(),
                    'updatedAt': DateTime.now().toIso8601String(),
                    'updatedBy': 'admin', // You can get this from user context
                    'reason': 'Registration date changed from $oldRegisterDate to $newRegisterDateOnly',
                  });
                  print('📝 Registration date changed: $oldRegisterDate → $newRegisterDateOnly');
                } else {
                  print('✅ Registration date unchanged, no error added');
                }

                // Ensure remaining has a valid value
                int remainingValue = _remaining ?? currentRemaining;

                // Compute price from selected duration (from DB list)
                int computedPrice = 0;
                try {
                  final idx = durationsList.indexWhere((d) => (d['name'] as String?) == _duration);
                  if (idx != -1) {
                    final p = durationsList[idx]['price'];
                    if (p is int) computedPrice = p; else if (p is num) computedPrice = p.toInt();
                  }
                } catch (e) {}

                // Update member data in members path
                _databaseRef.child(memberId).update({
                  'registerDate': newRegisterDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
                  'weight': weightValue, // Ensure it's stored as int with null safety
                  'remaining': remainingValue, // Add remaining field (ቀሪ) with null safety
                  'duration': _duration, // New duration value
                  'price': computedPrice, // Save price alongside duration
                  'registerErrors': registerErrors, // Add register errors array
                  'status': 'active',
                  'lastUpdatedDate': DateTime.now().toIso8601String(), // Track when last updated
                  'lastUpdateType': 'manual_update', // Track the type of update
                }).then((_) async {
                  print('✅ Updated member in members path');
                  
                  // Also update in reporte path using the SAME memberId
                  try {
                    final DatabaseReference reporteRef = FirebaseDatabase.instance.ref('reporte');
                    
                    // Prepare report data with the same information
                    Map<String, dynamic> reportData = {
                      'registerDate': newRegisterDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
                      'weight': weightValue,
                      'remaining': remainingValue,
                      'duration': _duration,
                      'price': computedPrice,
                      'firstName': member['firstName'],
                      'lastName': member['lastName'],
                      'lockerKey': member['lockerKey'],
                      'phoneNumber': member['phoneNumber'],
                      'paymentMethod': member['paymentMethod'],
                      'paymentImageUrl': member['paymentImageUrl'],
                      'profileImageUrl': member['profileImageUrl'],
                      'status': member['reRegisteredFrom'] != null ? 're-registered member' : 'active member',
                      'lastUpdatedDate': DateTime.now().toIso8601String(),
                      'lastUpdateType': 'manual_update',
                      // Preserve original registration info if it exists
                      'originalRegisterDate': member['originalRegisterDate'],
                      'reRegisteredFrom': member['reRegisteredFrom'],
                      'reRegisterDate': member['reRegisterDate'],
                    };
                    
                    // Use the same memberId for synchronization
                    await reporteRef.child(memberId).update(reportData);
                    print('✅ Updated member in reporte path with same ID: $memberId');
                  } catch (e) {
                    print('Error updating reporte path: $e');
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Member re-registered successfully'),
                    backgroundColor: Colors.green,
                  ));
                  Navigator.of(context).pop();
                  _fetchActiveMembers(); // Refresh the list
                }).catchError((error) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error re-registering member: $error'),
                    backgroundColor: Colors.red,
                  ));
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
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey, // Isolated notification system
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Active Members'),
          backgroundColor: Colors.deepPurple,
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
                    ? const Center(child: Text('No active members found'))
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
                    DateTime registerDate =
                        _ethiopianToGregorian(member['registerDate']);
                    int remainingDays =
                        _getRemainingDays(registerDate, member['duration']);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Avatar
                            _buildProfileAvatar(
                              member['profileImageUrl'],
                              member['firstName'],
                              member['lastName'],
                            ),
                            const SizedBox(width: 15),
                            // Member Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                          '${member['firstName']} ${member['lastName']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blueAccent,
                          ),
                        ),
                                  const SizedBox(height: 8),
                            Text(
                                'Registered on: ${_convertToEthiopianDate(registerDate)}'),
                            Text('Duration: ${member['duration'] ?? 'N/A'}'),
                            Text('Weight: ${member['weight'] ?? 0} kg'),
                            Text('Locker Key: ${member['lockerKey'] ?? 'Not Provided'}'),
                            Text(
                                'Phone Number: ${member['phoneNumber'] ?? 'Not Provided'}'), // Show phone number or fallback text
                            Text('ቀሪ (Remaining): ${member['remaining'] ?? 0} Birr'), // Show remaining field
                            
                            // Show registration/update tracking info
                            if (member['lastUpdatedDate'] != null || member['reRegisterDate'] != null) ...[
                              const SizedBox(height: 8),
                              _buildUpdateTrackingBadge(member),
                            ],
                            
                            // Show register errors if any
                            if (member['registerErrors'] != null && (member['registerErrors'] as List).isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Text(
                                    'Register Errors: ${(member['registerErrors'] as List).length}',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _showRegisterErrorDetails = !_showRegisterErrorDetails;
                                      });
                                    },
                                    icon: Icon(
                                      _showRegisterErrorDetails ? Icons.expand_less : Icons.expand_more,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                    tooltip: _showRegisterErrorDetails ? 'Hide Details' : 'Show Details',
                                  ),
                                ],
                              ),
                              // Show register error details when toggle is enabled
                              if (_showRegisterErrorDetails) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Previous Registration Dates:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...((member['registerErrors'] as List).map((error) {
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 8, top: 2),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.history,
                                                size: 14,
                                                color: Colors.orange.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${error['previousDate']?.toString().split('T')[0] ?? 'Unknown Date'}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.orange.shade600,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList()),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 10),
                            _buildCountdownCircle(
                                remainingDays, member['duration']),
                          ],
                        ),
                            ),
                            // Update Button
                            const SizedBox(width: 10),
                            ElevatedButton(
                          onPressed: () async => await _reRegister(
                            member['id'],
                            member['weight'] ?? 0, // Provide default value if null
                            member['duration'] ?? '2 Weeks', // Provide default if null
                            member, // Add member parameter
                          ),
                          child: const Text('Update'),
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
      ), // Close ScaffoldMessenger
    );
  }

  Widget _buildCountdownCircle(int remainingDays, String duration) {
    int totalDays = _parseDurationToDays(duration);
    double percentage = (remainingDays / totalDays).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${remainingDays < 0 ? 0 : remainingDays} Days Left',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: remainingDays < 0 ? Colors.red : Colors.black,
          ),
        ),
        const SizedBox(height: 5),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: percentage),
          duration: const Duration(seconds: 1),
          builder: (context, value, child) {
            return CircularProgressIndicator(
              value: value,
              strokeWidth: 6,
              backgroundColor: Colors.grey[300],
              color: remainingDays <= 5 ? Colors.red : Colors.green,
            );
          },
        ),
      ],
    );
  }

  String _convertToEthiopianDate(DateTime date) {
    final ethiopianDate = EthiopianDateConverter.convertToEthiopianDate(
      EthiopianDateTime(date.year, date.month, date.day),
    );

    // Format Ethiopian date as YYYY-MM-DD
    String formattedEthiopianDate =
        '${ethiopianDate.year}-${ethiopianDate.month}-${ethiopianDate.day}';
    return formattedEthiopianDate;
  }

  // Get current Ethiopian date in YYYY-MM-DD format
  String _getCurrentEthiopianDate() {
    DateTime now = DateTime.now();
    return _convertToEthiopianDate(now);
  }

  /// Build update tracking badge to show registration or update info
  Widget _buildUpdateTrackingBadge(Map<String, dynamic> member) {
    String updateType = member['lastUpdateType'] ?? 'unknown';
    String? lastUpdatedDate = member['lastUpdatedDate'];
    String? reRegisterDate = member['reRegisterDate'];
    
    // Determine the display information
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;
    String dateToShow;
    
    if (updateType == 're-registration' || reRegisterDate != null) {
      badgeColor = Colors.green;
      badgeIcon = Icons.replay;
      badgeText = 'Re-registered';
      dateToShow = reRegisterDate ?? lastUpdatedDate ?? '';
    } else if (updateType == 'manual_update') {
      badgeColor = Colors.blue;
      badgeIcon = Icons.update;
      badgeText = 'Updated';
      dateToShow = lastUpdatedDate ?? '';
    } else {
      badgeColor = Colors.orange;
      badgeIcon = Icons.info;
      badgeText = 'Modified';
      dateToShow = lastUpdatedDate ?? '';
    }
    
    // Format the date
    String formattedDate = _formatDateTime(dateToShow);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$badgeText: $formattedDate',
              style: TextStyle(
                fontSize: 11,
                color: badgeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Format DateTime string for display
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'Unknown';
    
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
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

