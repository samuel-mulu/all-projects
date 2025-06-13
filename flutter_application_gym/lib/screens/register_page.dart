import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.memberId,
    required Map member,
  });

  final String memberId; // Unique ID for the member

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService(); // Create instance

  String? _firstName, _lastName, _lockerKey;
  int? _weight;
  String _membership = 'Standard';
  String _duration = '1 Month';
  DateTime _registerDate = DateTime.now(); // Default registration date and time
  String? _phoneNumber; // New variable for phone number
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.memberId.isNotEmpty) {
      _loadMemberData();
    }
  }

  Future<void> _loadMemberData() async {
    try {
      final DatabaseEvent event =
          await _firebaseService.getMemberById(widget.memberId);
      final DataSnapshot snapshot = event.snapshot;
      if (snapshot.value != null) {
        final member =
            Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
        setState(() {
          _firstName = member['firstName'];
          _lastName = member['lastName'];
          _weight = member['weight'];
          _membership = member['membership'];
          _duration = member['duration'];
          _registerDate = DateTime.parse(member['registerDate']);
          _lockerKey = member['lockerKey'];
          _phoneNumber = member['phoneNumber'];
        });
      }
    } catch (e) {
      print('Error loading member data: $e');
      // Handle error appropriately
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _registerDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _registerDate) {
      setState(() {
        _registerDate = picked;
      });
    }
  }

  Future<bool> _checkInternetConnection() async {
    var result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<bool> _isLockerKeyUnique(String lockerKey) async {
    try {
      final DatabaseEvent event = await _firebaseService.getAllMembers();
      final DataSnapshot snapshot = event.snapshot;
      final members = (snapshot.value as Map<dynamic, dynamic>?) ?? {};
      return !members.values.any((member) =>
          (member as Map<dynamic, dynamic>)['lockerKey'] == lockerKey);
    } catch (e) {
      print('Error checking locker key uniqueness: $e');
      return false; // Default to false if an error occurs
    }
  }

  Future<void> _registerMember() async {
    if (_formKey.currentState!.validate()) {
      if (!await _checkInternetConnection()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
        return;
      }

      if (_lockerKey != null && !(await _isLockerKeyUnique(_lockerKey!))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Locker key must be unique')),
        );
        return;
      }

      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        Map<String, dynamic> memberData = {
          'firstName': _firstName,
          'lastName': _lastName,
          'weight': _weight,
          'membership': _membership,
          'duration': _duration,
          'registerDate': _registerDate.toIso8601String(),
          'status': 'active',
          'lockerKey': _lockerKey,
          'phoneNumber': _phoneNumber,
        };

        // Save to Firebase
        await _firebaseService.addMember(memberData);

        // Save data offline to SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        List<String> registeredMembers =
            prefs.getStringList('registeredMembers') ?? [];
        registeredMembers.add(memberData.toString());
        await prefs.setStringList('registeredMembers', registeredMembers);

        // Save member data to JSON file
        await _saveMemberToJson(memberData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member registered successfully!')),
        );

        Navigator.of(context).pop();
      } catch (e) {
        print('Error registering member: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error registering member. Please try again.')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveMemberToJson(Map<String, dynamic> member) async {
    try {
      // Get the directory where the JSON file is stored
      Directory directory = await getApplicationDocumentsDirectory();
      File file = File('${directory.path}/members.json');

      // Check if the file exists
      if (!await file.exists()) {
        // If not, create it with an empty list
        await file.writeAsString(jsonEncode([]));
      }

      // Read existing data
      String contents = await file.readAsString();
      List<dynamic> jsonData = jsonDecode(contents);

      // Add the new member
      jsonData.add(member);

      // Write the updated list back to the file
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      print('Error writing to JSON file: $e');
    }
  }

  // Fetch active members count
  Future<int> _fetchActiveMembers() async {
    try {
      final DatabaseEvent event = await _firebaseService.getActiveMembers();
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> activeMembersMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        return activeMembersMap.length;
      }
      return 0;
    } catch (e) {
      print('Error fetching active members: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.memberId.isEmpty ? 'Register Member' : 'Update Member'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextFormField(
                    initialValue: _firstName,
                    labelText: 'First Name',
                    icon: Icons.person,
                    onSave: (value) => _firstName = value,
                    validator: (value) =>
                        value!.isEmpty ? 'Enter first name' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    initialValue: _lastName,
                    labelText: 'Last Name',
                    icon: Icons.person,
                    onSave: (value) => _lastName = value,
                    validator: (value) =>
                        value!.isEmpty ? 'Enter last name' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    initialValue: _phoneNumber,
                    labelText: 'Phone Number',
                    icon: Icons.phone,
                    onSave: (value) => _phoneNumber = value,
                    validator: (value) {
                      if (value!.isEmpty) return 'Enter phone number';
                      // Optional: Add more sophisticated validation for phone numbers if necessary
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    initialValue: _lockerKey,
                    labelText: 'Locker Key',
                    icon: Icons.lock,
                    onSave: (value) => _lockerKey = value,
                    validator: (value) =>
                        value!.isEmpty ? 'Enter locker key' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    value: _membership,
                    labelText: 'Membership',
                    icon: Icons.card_membership,
                    items: const ['Standard', 'Premium', 'VIP'],
                    onChanged: (newValue) => setState(() {
                      _membership = newValue!;
                    }),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    value: _duration,
                    labelText: 'Duration',
                    icon: Icons.calendar_today,
                    items: const [
                      '1 Month',
                      '2 Months',
                      '3 Months',
                      '6 Months',
                      '1 Year'
                    ],
                    onChanged: (newValue) => setState(() {
                      _duration = newValue!;
                    }),
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    initialValue: _weight?.toString(),
                    labelText: 'Weight',
                    icon: Icons.fitness_center,
                    keyboardType: TextInputType.number,
                    onSave: (value) => _weight = int.tryParse(value!),
                    validator: (value) {
                      if (value!.isEmpty) return 'Enter weight';
                      final int? weight = int.tryParse(value);
                      return (weight == null || weight <= 0)
                          ? 'Enter a valid weight'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: _buildTextFormField(
                        initialValue:
                            DateFormat('yyyy-MM-dd').format(_registerDate),
                        labelText: 'Registration Date',
                        icon: Icons.date_range,
                        enabled: false,
                        onSave: (String? newValue) {},
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _registerMember,
                          child: Text(
                              widget.memberId.isEmpty ? 'Register' : 'Update'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required String? initialValue,
    required String labelText,
    required IconData icon,
    required FormFieldSetter<String>? onSave,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon),
      ),
      onSaved: onSave,
      validator: validator,
      keyboardType: keyboardType,
      enabled: enabled,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String labelText,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }
}
