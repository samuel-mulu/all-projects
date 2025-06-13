import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class InactivePage extends StatefulWidget {
  const InactivePage({super.key});

  @override
  _InactivePageState createState() => _InactivePageState();
}

class _InactivePageState extends State<InactivePage> {
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref('medications');
  Map<String, List<Map<String, dynamic>>> groupedInactiveMedications = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchInactiveMedications();
  }

  Future<void> _fetchInactiveMedications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DatabaseEvent event = await _databaseRef.once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> medications =
            event.snapshot.value as Map<dynamic, dynamic>;

        Map<String, List<Map<String, dynamic>>> loadedMedications = {};
        for (var entry in medications.entries) {
          final medData = entry.value;

          if (medData['status'] == 'inactive') {
            String medicationType = medData['medicationType'] ?? 'Unknown';
            DateTime expirationDate = DateTime.parse(
              medData['expirationDate'] ?? DateTime.now().toIso8601String(),
            );
            int daysToExpire = expirationDate.difference(DateTime.now()).inDays;
            Color cardColor = Colors.white;

            if ((medData['quantity'] ?? 0) < 5) {
              cardColor = Colors.orange.shade100; // Softer Low Stock
            } else if (daysToExpire <= 30) {
              cardColor = Colors.yellow.shade100; // Softer Expiration Warning
            }

            loadedMedications.putIfAbsent(medicationType, () => []).add({
              'id': entry.key,
              'cardColor': cardColor,
              ...Map<String, dynamic>.from(medData),
            });
          }
        }

        setState(() {
          groupedInactiveMedications = loadedMedications;
        });
      }
    } catch (e) {
      print('Error fetching inactive medications: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateMedication(
    String id,
    int newQuantity,
    String newExpirationDate,
    String newBatchNumber,
    double newPurchasedPrice,
    double newSellingPrice,
  ) async {
    try {
      await _databaseRef.child(id).update({
        'quantity': newQuantity,
        'expirationDate': newExpirationDate,
        'batchNumber': newBatchNumber,
        'purchasedPrice': newPurchasedPrice,
        'sellingPrice': newSellingPrice,
        'status': 'completed',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication updated successfully!')),
      );
      _fetchInactiveMedications(); // Refresh data
    } catch (e) {
      print('Error updating medication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update medication.')),
      );
    }
  }

  Widget _buildMedicationCard(Map<String, dynamic> medication) {
    int quantity = medication['quantity'] ?? 0;
    DateTime expirationDate = DateTime.parse(
      medication['expirationDate'] ?? DateTime.now().toIso8601String(),
    );
    int daysToExpire = expirationDate.difference(DateTime.now()).inDays;

    final TextEditingController quantityController =
        TextEditingController(text: quantity.toString());
    final TextEditingController expirationController =
        TextEditingController(text: medication['expirationDate']);
    final TextEditingController batchNumberController =
        TextEditingController(text: medication['batchNumber'] ?? '');
    final TextEditingController purchasedPriceController =
        TextEditingController(
            text: medication['purchasedPrice']?.toString() ?? '');
    final TextEditingController sellingPriceController = TextEditingController(
        text: medication['sellingPrice']?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: medication['cardColor'],
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        title: Text(
          '${medication['drug']}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch Number: ${medication['batchNumber'] ?? 'N/A'}'),
            Text('Purchased Price: ${medication['purchasedPrice'] ?? 'N/A'}'),
            Text('Selling Price: ${medication['sellingPrice'] ?? 'N/A'}'),
            Text('Expiration Date: ${medication['expirationDate']}'),
            Text('Quantity: $quantity'),
            if (quantity < 5)
              const Text(
                'Low Stock!',
                style: TextStyle(color: Colors.red),
              ),
            if (daysToExpire <= 30)
              const Text(
                'Expires Soon!',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle search input changes
    void onSearchChanged(String value) {
      setState(() {
        _searchQuery = value.toLowerCase();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inactive Medications'),
        backgroundColor: Colors.deepPurple.shade300,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 65, 88, 99), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Filter by drug name',
                        hintText: 'Enter drug name',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : groupedInactiveMedications.isEmpty
                      ? const Center(
                          child: Text('No inactive medications found'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(10.0),
                          itemCount: groupedInactiveMedications.length,
                          itemBuilder: (context, index) {
                            String medicationType = groupedInactiveMedications
                                .keys
                                .elementAt(index);

                            // Filter medications based on search query
                            List<Map<String, dynamic>> medications =
                                groupedInactiveMedications[medicationType]!
                                    .where((medication) {
                              return medication['drug']
                                  .toLowerCase()
                                  .contains(_searchQuery);
                            }).toList();

                            return medications.isNotEmpty
                                ? ExpansionTile(
                                    title: Text(
                                      medicationType,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    children: medications
                                        .map((medication) =>
                                            _buildMedicationCard(medication))
                                        .toList(),
                                  )
                                : const SizedBox();
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
