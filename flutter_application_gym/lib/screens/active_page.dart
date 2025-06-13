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
  List<Map<String, dynamic>> activeMembers = [];
  bool _isLoading = true;
  Timer? countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchActiveMembers();
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
    countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchActiveMembers() async {
    try {
      DatabaseEvent event = await _databaseRef.once();

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
        });
      }
    } catch (e) {
      print('Error fetching members: $e');
    } finally {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$firstName $lastName\'s package has expired.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _moveToInactivePage(String memberId) async {
    await _databaseRef.child(memberId).update({'status': 'inactive'});
  }

  // Re-register function for updating membership
  void _reRegister(String memberId, int currentWeight, String currentMembership,
      String currentDuration) {
    TextEditingController weightController =
        TextEditingController(text: currentWeight.toString());
    TextEditingController registerDateController =
        TextEditingController(text: "- -");

    // Variables for dropdown values
    String _membership = currentMembership;
    String _duration = currentDuration;

    showDialog(
      context: context,
      builder: (context) {
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
                  controller: registerDateController,
                  decoration: InputDecoration(
                    labelText: 'Register Date (YYYY-MM-DD)',
                    hintText: '   -   -    ',
                  ),
                ),
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
              onPressed: () {
                String newWeightStr = weightController.text;
                String newRegisterDateStr = registerDateController.text.trim();
                DateTime? newRegisterDate;

                // Validate the date format
                if (newRegisterDateStr.length == 10) {
                  try {
                    newRegisterDate = DateTime.parse(newRegisterDateStr);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Invalid date format. Use YYYY-MM-DD.'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Please enter a valid date.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                // Update member data
                _databaseRef.child(memberId).update({
                  'registerDate': newRegisterDate.toIso8601String(),
                  'weight':
                      int.parse(newWeightStr), // Ensure it's stored as int
                  'membership': _membership, // New membership value
                  'duration': _duration, // New duration value
                  'status': 'active',
                }).then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Member re-registered successfully'),
                    backgroundColor: Colors.green,
                  ));
                  Navigator.of(context).pop();
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error re-registering member: $error'),
                    backgroundColor: Colors.red,
                  ));
                });
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
        title: const Text('Active Members'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeMembers.isEmpty
              ? const Center(child: Text('No active members found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(10.0),
                  itemCount: activeMembers.length,
                  itemBuilder: (context, index) {
                    final member = activeMembers[index];
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
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        title: Text(
                          '${member['firstName']} ${member['lastName']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blueAccent,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Membership: ${member['membership']}'),
                            Text(
                                'Registered on: ${_convertToEthiopianDate(registerDate)}'),
                            Text('Duration: ${member['duration']}'),
                            Text('Weight: ${member['weight']} kg'),
                            Text('Locker Key: ${member['lockerKey']}'),
                            Text(
                                'Phone Number: ${member['phoneNumber'] ?? 'Not Provided'}'), // Show phone number or fallback text
                            const SizedBox(height: 10),
                            _buildCountdownCircle(
                                remainingDays, member['duration']),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _reRegister(
                            member['id'],
                            member['weight'],
                            member['membership'], // Add currentMembership
                            member['duration'], // Add currentDuration
                          ),
                          child: const Text('Update'),
                        ),
                      ),
                    );
                  },
                ),
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
}
