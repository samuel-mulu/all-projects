import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class ActivePage extends StatefulWidget {
  const ActivePage({super.key});

  @override
  _ActivePageState createState() => _ActivePageState();
}

class _ActivePageState extends State<ActivePage>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref('medications');
  Map<String, List<Map<String, dynamic>>> groupedMedications = {};
  bool _isLoading = true;
  Timer? countdownTimer;
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredMedications = [];

  @override
  void initState() {
    super.initState();
    _fetchActiveMedications();
    _searchController.addListener(_filterMedications); // Listen for changes
  }

  // Function to fetch medications from the database
  Future<void> _fetchActiveMedications() async {
    try {
      DatabaseEvent event = await _databaseRef.once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> medicationsMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        Map<String, List<Map<String, dynamic>>> loadedMedications = {};

        for (var entry in medicationsMap.entries) {
          String medicationId = entry.key; // Get the medication ID
          Map<String, dynamic> medicationData =
              Map<String, dynamic>.from(entry.value);

          try {
            String expirationDateStr = medicationData['expirationDate'] ?? '';
            String medicationType = medicationData['medicationType'] ?? '';
            int quantity = 0;
            var quantityValue = medicationData['quantity'];

            if (quantityValue is String) {
              var match = RegExp(r'\d+').firstMatch(quantityValue);
              if (match != null) {
                quantity = int.parse(match.group(0)!);
              }
            } else if (quantityValue is int) {
              quantity = quantityValue;
            } else if (quantityValue is double) {
              quantity = quantityValue.toInt();
            }

            DateTime expirationDate = DateTime.parse(expirationDateStr);
            DateTime now = DateTime.now();

            // Fetching new fields: MeasurementDose and MeasurementDoseUnit
            String measurementDose = medicationData['MeasurementDose'] ?? '';
            String measurementDoseUnit =
                medicationData['MeasurementDoseUnit'] ?? '';

            // Check for completed medications
            if (medicationData['status'] == 'completed') {
              // Handle expired or finished medications
              if (now.isAfter(expirationDate.add(const Duration(days: 5)))) {
                await _moveToExpiredPage(medicationId);
              } else if (now.isAfter(
                  expirationDate.subtract(const Duration(days: 150)))) {
                medicationData['cardColor'] = Colors.red;
                await _databaseRef
                    .child(medicationId)
                    .update({'status': 'inactive'});
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text('${medicationData['drug']} is about to expire!'),
                  backgroundColor: Colors.red,
                ));
              } else if (quantity <= 0) {
                await _moveToFinishedPage(medicationId);
              } else if (quantity <= 5) {
                medicationData['cardColor'] = Colors.yellow;
                await _databaseRef
                    .child(medicationId)
                    .update({'status': 'inactive'});
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${medicationData['drug']} is low in stock!'),
                  backgroundColor: Colors.yellow,
                ));
              } else {
                loadedMedications.putIfAbsent(medicationType, () => []).add({
                  'id': medicationId,
                  'cardColor': Colors.white,
                  'MeasurementDose': measurementDose,
                  'MeasurementDoseUnit': measurementDoseUnit,
                  ...medicationData,
                });
              }
            }
          } catch (e) {
            print('Error processing medication data: $e');
          }
        }

        if (!mounted) return;
        setState(() {
          groupedMedications = loadedMedications;
          _filteredMedications = _getAllMedications();
        });
      }
    } catch (e) {
      print('Error fetching medications: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get all medications as a flat list for filtering
  List<Map<String, dynamic>> _getAllMedications() {
    List<Map<String, dynamic>> allMedications = [];
    groupedMedications.forEach((key, medications) {
      allMedications.addAll(medications);
    });
    return allMedications;
  }

  // Filter medications based on search text
  void _filterMedications() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMedications = _getAllMedications()
          .where(
              (medication) => medication['drug'].toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _reRegisterMedication(Map<String, dynamic> medication) async {
    // Open a dialog to confirm re-registration
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Re-register Medication: ${medication['drug']}'),
          content:
              _buildReRegistrationForm(medication), // Pass the medication data
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    // After the form is submitted and re-registration is done, update the status
    // and refresh the list.
    try {
      // Assuming the medication data is updated and submitted in _buildReRegistrationForm
      // Here we update the status to "pending" in the database
      await _databaseRef.child(medication['id']).update({
        'status': 'pending', // Set the status to pending
      });

      // Optionally reload or refresh the medication list
      _loadMedications(); // Reload medications to reflect the changes
    } catch (e) {
      print('Error re-registering medication: $e');
    }
  }

  Widget _buildReRegistrationForm(Map<String, dynamic> medication) {
    // Extract the existing values from the medication object
    String? _strengthUnit = medication['strengthUnit'] ?? 'mg';
    String? _measurement = medication['measurement'] ?? 'each';
    double? _purchasedPrice =
        medication['purchasedPrice']?.toDouble(); // Ensure it's a double
    double? _sellingPrice =
        medication['sellingPrice']?.toDouble(); // Ensure it's a double
    DateTime? _expirationDate =
        DateTime.tryParse(medication['expirationDate'] ?? '');
    int? _quantity = medication['quantity'];
    String? _strength = medication['strength'];

    final List<String> _strengthUnits = ['mg', 'g', 'ml', 'L'];
    final List<String> _measurements = [
      'pack',
      'box',
      'each',
      'roll',
      'bag',
      'dozen',
      'tube',
      'amp',
      'bottle',
      'vial',
      'tin',
      'jar',
      'tab'
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          // Expiration Date Field
          TextField(
            decoration: InputDecoration(labelText: 'Expiration Date'),
            onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: _expirationDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              setState(() {
                _expirationDate = pickedDate;
              });
            },
            readOnly: true,
            controller: TextEditingController(
              text: _expirationDate != null
                  ? '${_expirationDate.toLocal()}'.split(' ')[0]
                  : '',
            ),
          ),
          // Purchased Price Field
          TextField(
            decoration: InputDecoration(labelText: 'Purchased Price'),
            keyboardType: TextInputType.number,
            controller: TextEditingController(
              text: _purchasedPrice?.toString() ?? '',
            ),
            onChanged: (value) {
              // Safely parse to double, falling back to 0.0 if parsing fails
              _purchasedPrice = double.tryParse(value) ?? 0.0;
            },
          ),

          TextField(
            decoration: InputDecoration(labelText: 'Selling Price'),
            keyboardType: TextInputType.number,
            controller: TextEditingController(
              text: _sellingPrice?.toString() ?? '',
            ),
            onChanged: (value) {
              _sellingPrice = double.tryParse(value) ?? 0.0;
            },
          ),

          TextField(
            decoration: InputDecoration(labelText: 'Quantity'),
            keyboardType: TextInputType.number,
            controller: TextEditingController(
              text: _quantity?.toString() ?? '',
            ),
            onChanged: (value) {
              // Safely parse to integer
              _quantity = int.tryParse(value) ?? 0;
            },
          ),

          // Strength Field
          TextField(
            decoration: InputDecoration(labelText: 'Strength'),
            controller: TextEditingController(
              text: _strength ?? '',
            ),
            onChanged: (value) {
              _strength = value;
            },
          ),
          // Measurement Dropdown
          DropdownButtonFormField<String>(
            value: _measurement,
            decoration: InputDecoration(labelText: 'Measurement'),
            items: _measurements
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (newValue) => setState(() => _measurement = newValue),
          ),
          // Strength Unit Dropdown
          DropdownButtonFormField<String>(
            value: _strengthUnit,
            decoration: InputDecoration(labelText: 'Strength Unit'),
            items: _strengthUnits
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (newValue) => setState(() => _strengthUnit = newValue!),
          ),
          // Re-register button
          ElevatedButton(
            onPressed: () async {
              try {
                // Update the medication details in Firebase
                await _databaseRef.child(medication['id']).update({
                  'strength': _strength,
                  'strengthUnit': _strengthUnit,
                  'purchasedPrice': _purchasedPrice,
                  'sellingPrice': _sellingPrice,
                  'quantity': _quantity,
                  'expirationDate': _expirationDate?.toIso8601String(),
                  'measurement': _measurement,
                });

                Navigator.of(context).pop(); // Close dialog
              } catch (e) {
                print('Error re-registering medication: $e');
              }
            },
            child: Text('Re-register Medication'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToExpiredPage(String medicationId) async {
    // Implement logic to move to expired page
  }

  Future<void> _moveToFinishedPage(String medicationId) async {
    // Implement logic to move to finished page
  }
  @override
  Widget build(BuildContext context) {
    // Group medications by their type
    Map<String, List<Map<String, dynamic>>> groupedMedications = {};
    for (var medication in _filteredMedications) {
      String medicationType = medication['medicationType'];
      if (!groupedMedications.containsKey(medicationType)) {
        groupedMedications[medicationType] = [];
      }
      groupedMedications[medicationType]!.add(medication);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: const Text('Pharmacy Store'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Drug Name',
                hintText: 'Enter drug name...',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredMedications.isEmpty
              ? const Center(child: Text('No active medications found.'))
              : ListView.builder(
                  itemCount: groupedMedications.keys.length,
                  itemBuilder: (context, index) {
                    String medicationType =
                        groupedMedications.keys.elementAt(index);
                    List<Map<String, dynamic>> medications =
                        groupedMedications[medicationType]!;

                    return ExpansionTile(
                      leading: Icon(
                        Icons.local_pharmacy,
                        color: Colors.green[800],
                      ),
                      title: Text(
                        medicationType,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      children: medications.map((medication) {
                        return Card(
                          color: medication['cardColor'] ?? Colors.white,
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.medication,
                              size: 40,
                              color: Colors.blue,
                            ),
                            title: Text(
                              medication['drug'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              'Expiration: ${medication['expirationDate']}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                            trailing: Text(
                              'Qty: ${medication['quantity']}',
                              style: TextStyle(
                                fontSize: 16,
                                color:
                                    medication['cardColor'] == Colors.redAccent
                                        ? Colors.red
                                        : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () => _reRegisterMedication(medication),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
    );
  }
}

void _loadMedications() {}
