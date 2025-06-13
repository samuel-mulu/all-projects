import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
    _fetchInactiveMembers();
  }

  Future<void> _fetchCurrentUserRole() async {
    var _auth = FirebaseAuth.instance; // Initialize Firebase Auth
    User? user = _auth.currentUser; // Get current user
    if (user != null) {
      final userRef = FirebaseDatabase.instance
          .ref("members/${user.email!.replaceAll('.', '_')}");

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
    });
  }

  Future<void> _reRegister(
      String memberId,
      String fullName,
      String currentWeight,
      String currentMembership,
      String currentDuration,
      String currentRegisterDate) async {
    TextEditingController weightController =
        TextEditingController(text: currentWeight);
    TextEditingController registerDateController =
        TextEditingController(text: currentRegisterDate);

    String _membership = currentMembership;
    String _duration = currentDuration;

    showDialog(
      context: context,
      builder: (context) {
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
                  items: const [
                    DropdownMenuItem(
                        value: 'Standard', child: Text('Standard')),
                    DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                    DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                  ],
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String newWeightStr = weightController.text;
                String newRegisterDateStr = registerDateController.text.trim();

                // Use a regex to validate the date format
                RegExp dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

                if (!dateRegex.hasMatch(newRegisterDateStr)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Invalid date format. Use YYYY-MM-DD.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                DateTime? newRegisterDate;

                // Try parsing the date string
                try {
                  newRegisterDate = DateTime.parse(newRegisterDateStr);

                  // Additional check to ensure the day, month, and year are valid
                  if (newRegisterDateStr !=
                      '${newRegisterDate.year.toString().padLeft(4, '0')}-${newRegisterDate.month.toString().padLeft(2, '0')}-${newRegisterDate.day.toString().padLeft(2, '0')}') {
                    throw FormatException("Invalid date");
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Invalid date. Please enter a valid date.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                // Prepare member data for update
                Map<String, dynamic> memberData = {
                  'registerDate': newRegisterDate != null
                      ? '${newRegisterDate.year}-${newRegisterDate.month.toString().padLeft(2, '0')}-${newRegisterDate.day.toString().padLeft(2, '0')}'
                      : '',
                  'weight': int.tryParse(newWeightStr) ?? 0,
                  'membership': _membership,
                  'duration': _duration,
                  'status': 'active', // Change status to active
                };

                try {
                  // Update member data
                  await _databaseRef.child(memberId).update(memberData);

                  // Prepare report data to store the re-register information
                  Map<String, dynamic> reportData = {
                    'memberId': memberId,
                    'fullName': fullName,
                    'weight': int.tryParse(newWeightStr) ?? 0,
                    'registerDate': newRegisterDate != null
                        ? '${newRegisterDate.year}-${newRegisterDate.month.toString().padLeft(2, '0')}-${newRegisterDate.day.toString().padLeft(2, '0')}'
                        : '',
                    'membership': _membership,
                    'duration': _duration,
                    'status': 're-register', // Re-register status
                    'reRegisterDate': DateTime.now()
                        .toIso8601String(), // Add the time of re-registration
                  };

                  // Store re-register data in the "reporte" node with a unique ID
                  await _databaseRef.child('reporte').push().set(reportData);

                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Member re-registered successfully'),
                    backgroundColor: Colors.green,
                  ));
                  Navigator.of(context).pop();
                  _fetchInactiveMembers(); // Refresh list
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error re-registering member: $error'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              child: Text('Re-register'),
            ),
          ],
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
                        itemCount: filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = filteredMembers[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(15),
                              title: Text(
                                '${(index + 1)}. ${member['firstName'] ?? 'Unknown'} ${member['lastName'] ?? 'Unknown'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Membership: ${member['membership'] ?? 'N/A'}'),
                                  Text(
                                      'Weight: ${member['weight'] ?? 'N/A'} kg'),
                                  Text(
                                      'Register Date: ${member['registerDate'] ?? 'N/A'}'),
                                  Text(
                                      'Duration: ${member['duration'] ?? 'N/A'}'),
                                  Text('Status: Inactive'),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: isAdmin
                                    ? () {
                                        _reRegister(
                                          member['id'] ?? 'Unknown ID',
                                          '${member['firstName'] ?? 'Unknown'} ${member['lastName'] ?? 'Unknown'}',
                                          member['weight']?.toString() ?? 'N/A',
                                          member['membership'] ?? 'Standard',
                                          member['duration'] ?? '1 Month',
                                          member['registerDate'] ?? 'N/A',
                                        );
                                      }
                                    : null, // Disable the button if the user is not an admin
                                child:
                                    Text(isAdmin ? 'Re-register' : 'No Access'),
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
