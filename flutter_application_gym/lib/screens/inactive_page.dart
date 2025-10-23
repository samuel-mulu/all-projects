import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
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
  List<Map<String, dynamic>> _membershipTypes = []; // Dynamic membership types
  
  // Pagination variables
  int _currentPage = 1;
  final int _itemsPerPage = 20; // Load 20 members at a time
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
    _fetchMembershipTypes();
    _fetchInactiveMembers();
  }

  // Fetch membership types from database
  Future<void> _fetchMembershipTypes() async {
    try {
      final DatabaseReference membershipsRef = FirebaseDatabase.instance.ref('memberships');
      final DatabaseEvent event = await membershipsRef.once();
      
      List<Map<String, dynamic>> loadedMemberships = [];
      
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> membershipsMap = event.snapshot.value as Map<dynamic, dynamic>;
        
        membershipsMap.forEach((key, value) {
          if (value is Map) {
            Map<String, dynamic> membership = Map<String, dynamic>.from(value);
            membership['id'] = key;
            loadedMemberships.add(membership);
          }
        });
      }
      
      // Sort by name
      loadedMemberships.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

      setState(() {
        _membershipTypes = loadedMemberships;
      });
    } catch (e) {
      print('Error fetching membership types: $e');
    }
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

  Future<void> _fetchInactiveMembers() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      DatabaseEvent event = await _databaseRef.once();

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
        });
      }
    } catch (e) {
      print('Error fetching members: $e');
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
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
      String currentMembership,
      String currentDuration,
      String currentRegisterDate,
      Map<String, dynamic> member) async {
    TextEditingController weightController =
        TextEditingController(text: currentWeight);
    TextEditingController registerDateController =
        TextEditingController(text: _formatDate(currentRegisterDate));
    TextEditingController remainingController =
        TextEditingController(text: member['remaining']?.toString() ?? '0');

    String _membership = currentMembership;
    String _duration = currentDuration;
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

                // Membership dropdown
                DropdownButtonFormField<String>(
                  value: _membership,
                  onChanged: (newValue) {
                    setState(() {
                      _membership = newValue!;
                    });
                  },
                  items: _membershipTypes.isEmpty
                      ? const [
                          DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                          DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                          DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                        ]
                      : _membershipTypes.map((membership) {
                          return DropdownMenuItem<String>(
                            value: membership['name'],
                            child: Text('${membership['name']} (${membership['price']} Birr/Month)'),
                          );
                        }).toList(),
                  decoration: InputDecoration(labelText: 'Membership'),
                ),

                // Duration dropdown
                DropdownButtonFormField<String>(
                  value: _duration,
                  onChanged: (newValue) {
                    setState(() {
                      _duration = newValue!;
                    });
                  },
                  items: const [
                    DropdownMenuItem(value: '1 Month', child: Text('1 Month')),
                    DropdownMenuItem(
                        value: '2 Months', child: Text('2 Months')),
                    DropdownMenuItem(
                        value: '3 Months', child: Text('3 Months')),
                    DropdownMenuItem(
                        value: '6 Months', child: Text('6 Months')),
                    DropdownMenuItem(value: '1 Year', child: Text('1 Year')),
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

                // Validate that the membership won't be expired immediately
                // The date entered is in Ethiopian calendar format YYYY-MM-DD
                // Convert to Gregorian for accurate expiry calculation
                String ethiopianDateStr = '${newRegisterDate.year}-${newRegisterDate.month.toString().padLeft(2, '0')}-${newRegisterDate.day.toString().padLeft(2, '0')}';
                DateTime gregorianRegisterDate;
                
                try {
                  gregorianRegisterDate = _ethiopianToGregorian(ethiopianDateStr);
                } catch (e) {
                  print('Error converting Ethiopian date: $e');
                  // If conversion fails, use the date as-is (fallback)
                  gregorianRegisterDate = newRegisterDate;
                }
                
                int durationDays = _parseDurationToDays(_duration);
                DateTime expiryDate = gregorianRegisterDate.add(Duration(days: durationDays));
                DateTime now = DateTime.now();
                
                if (expiryDate.isBefore(now)) {
                  setState(() {
                    _isRegistering = false;
                  });
                  int daysExpired = now.difference(expiryDate).inDays;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Warning: This membership is already expired by $daysExpired days! Ethiopian date $ethiopianDateStr converts to ${gregorianRegisterDate.year}-${gregorianRegisterDate.month.toString().padLeft(2, '0')}-${gregorianRegisterDate.day.toString().padLeft(2, '0')} (Gregorian). Please choose a more recent date or longer duration.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 6),
                    ),
                  );
                  return;
                }
                
                // Warn if membership will expire very soon (within 7 days)
                int remainingDays = expiryDate.difference(now).inDays;
                if (remainingDays <= 7) {
                  bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Membership Expires Soon'),
                      content: Text('Ethiopian date: $ethiopianDateStr\nGregorian date: ${gregorianRegisterDate.year}-${gregorianRegisterDate.month.toString().padLeft(2, '0')}-${gregorianRegisterDate.day.toString().padLeft(2, '0')}\n\nThis membership will expire in $remainingDays day(s). Are you sure you want to continue?'),
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
                  'membership': _membership,
                  'duration': _duration,
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
                    'membership': _membership,
                    'duration': _duration,
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
        title: const Text('Inactive Members'),
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
                                            'Membership: ${member['membership'] ?? 'N/A'}'),
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
                                  // Action buttons column
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
                                              member['membership'] ?? 'Standard',
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
                          );
                        },
                      ),
          ),
        ],
      ),
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
