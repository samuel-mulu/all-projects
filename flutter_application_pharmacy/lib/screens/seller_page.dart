import 'package:flutter/material.dart';
import '/services/firebase_service.dart'; // Import the FirebaseService
import 'package:intl/intl.dart'; // For date formatting

class SellerPage extends StatefulWidget {
  const SellerPage({Key? key}) : super(key: key);

  @override
  _SellerPageState createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _completedMedications = [];
  String? _selectedDrugName;
  int? _quantityAvailable;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
  bool _isLoading = true;
  String? _paymentMethod = 'Cash'; // Default payment method
  TextEditingController _reasonController = TextEditingController();

  // Pharmacy-Specific Color Scheme
  Color primaryColor = Colors.teal;
  Color accentColor = Colors.blueAccent;
  Color textColor = Colors.black87;
  Color errorColor = Colors.redAccent;
  Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchCompletedMedications();
  }

  Future<void> _fetchCompletedMedications() async {
    try {
      List<Map<String, dynamic>> medications =
          await _firebaseService.fetchMedications();
      medications = medications
          .where((med) =>
              med['status'] == 'completed' || med['status'] == 'inactive')
          .toList();

      setState(() {
        _completedMedications = medications;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackbar(
          'Failed to load completed medications. Please try again.');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchDrugQuantity(String drugName) async {
    try {
      int quantity = await _firebaseService.fetchDrugQuantity(drugName);
      setState(() {
        _quantityAvailable = quantity;
      });
    } catch (e) {
      _showErrorSnackbar('Failed to fetch drug quantity. Please try again.');
    }
  }

  Future<void> _sellDrug(String drugName) async {
    if (_quantityAvailable != null) {
      if (_quantityController.text.isEmpty) {
        _showErrorSnackbar('Please enter a valid quantity.');
        return;
      }

      int? quantityToSell = int.tryParse(_quantityController.text);
      if (quantityToSell == null ||
          quantityToSell <= 0 ||
          quantityToSell > _quantityAvailable!) {
        _showErrorSnackbar('Invalid or excessive quantity.');
        return;
      }

      int newQuantity = _quantityAvailable! - quantityToSell;
      final selectedMedication = _completedMedications.firstWhere(
        (med) => med['drug'] == drugName,
        orElse: () => {},
      );
      double sellingPrice = quantityToSell *
          (double.tryParse(selectedMedication['sellingPrice'].toString()) ?? 0);

      setState(() {
        _isLoading = true; // Show loading indicator
      });

      try {
        await _firebaseService.updateDrugQuantity(drugName, newQuantity);
        String date = _getGregorianDate(); // Updated to Gregorian date

        // Check if the payment method is Credit and handle reason input
        String? reason =
            _paymentMethod == 'Credit' ? _reasonController.text : '';

        // If reason is required for credit, make sure it's provided
        if (_paymentMethod == 'Credit' && reason.isEmpty) {
          _showErrorSnackbar('Please provide a reason for credit sale.');
          return;
        }

        await _firebaseService.recordSale(
          drugName,
          quantityToSell,
          sellingPrice,
          _paymentMethod!,
          date,
          reason: reason, // Pass the reason here
        );

        _quantityController.clear();
        setState(() {
          _quantityAvailable = newQuantity;
          _isLoading = false; // Hide loading indicator
        });

        _showSuccessDialog();
      } catch (e) {
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
        _showErrorSnackbar(
            'An error occurred during the sale. Please try again.');
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          elevation: 10,
          title: const Text('Success'),
          content: const Text('Drug sold successfully!'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: errorColor,
      ),
    );
  }

  // Updated to return the current date in Gregorian format
  String _getGregorianDate() {
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    return formatter.format(DateTime.now()); // Using the Gregorian calendar
  }

  List<Map<String, dynamic>> get _filteredMedications {
    if (_filterController.text.isEmpty) {
      return _completedMedications;
    } else {
      return _completedMedications.where((medication) {
        return medication['drug']
            .toString()
            .toLowerCase()
            .contains(_filterController.text.toLowerCase());
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Drug', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter TextField
                  TextField(
                    controller: _filterController,
                    decoration: InputDecoration(
                      labelText: 'Filter by Drug Name',
                      labelStyle: TextStyle(color: primaryColor),
                      prefixIcon: Icon(Icons.search, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  // Medication List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredMedications.length,
                      itemBuilder: (context, index) {
                        final medication = _filteredMedications[index];
                        return MedicationCard(
                          medication: medication,
                          onTap: () async {
                            _selectedDrugName = medication['drug'];
                            await _fetchDrugQuantity(_selectedDrugName!);
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),

                  // Sell Drug Box
                  if (_selectedDrugName != null && _quantityAvailable != null)
                    const SizedBox(height: 16),
                  if (_selectedDrugName != null && _quantityAvailable != null)
                    _buildSellBox(),
                ],
              ),
      ),
    );
  }

  Widget _buildSellBox() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Drug: $_selectedDrugName',
              style: TextStyle(
                color: primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Quantity Available: $_quantityAvailable',
              style: TextStyle(color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Quantity to Sell
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity to Sell'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Payment Method Dropdown
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                DropdownMenuItem(
                    value: 'Mobile Banking', child: Text('Mobile Banking')),
              ],
              onChanged: (value) {
                setState(() {
                  _paymentMethod = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Show Reason Field if Credit is Selected
            if (_paymentMethod == 'Credit') ...[
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Credit Sale',
                  hintText: 'Enter reason...',
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (_selectedDrugName != null) {
                      _sellDrug(_selectedDrugName!);
                    }
                  },
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        ) // Show loading indicator while processing
                      : const Text('Sell Drug'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedDrugName = null;
                      _quantityAvailable = null;
                      _quantityController.clear();
                      _reasonController.clear();
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MedicationCard extends StatelessWidget {
  final Map<String, dynamic> medication;
  final VoidCallback onTap;

  const MedicationCard(
      {Key? key, required this.medication, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 5,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.medication, color: Colors.blue, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  medication['drug'],
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
