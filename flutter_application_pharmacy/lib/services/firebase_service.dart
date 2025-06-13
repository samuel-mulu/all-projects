import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Fetch all medications from the database
  Future<List<Map<String, dynamic>>> fetchMedications() async {
    try {
      final snapshot = await _database.child('medications').once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> medications = [];

        data.forEach((key, value) {
          Map<String, dynamic> medicationData =
              Map<String, dynamic>.from(value);
          medications.add({'id': key, ...medicationData});
        });
        return medications;
      } else {
        print("No medications found.");
        return [];
      }
    } catch (e) {
      print('Error fetching medications: $e');
      return [];
    }
  }

  // Fetch a specific medication by its ID
  Future<Map<String, dynamic>?> fetchMedicationById(String medicationId) async {
    try {
      final snapshot =
          await _database.child('medications/$medicationId').once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        return {'id': medicationId, ...Map<String, dynamic>.from(data)};
      } else {
        print("Medication with ID $medicationId not found.");
        return null;
      }
    } catch (e) {
      print('Error fetching medication by ID: $e');
      return null;
    }
  }

  // Fetch the quantity of a specific drug by name

  // Update the quantity of a specific drug
  // Update this function in your firebase service
  // Firebase service method to update drug quantity
  // Update this function in your firebase service
  Future<void> updateDrugQuantity(String drugName, int newQuantity) async {
    try {
      // Use the drug name to find the unique ID
      // Assuming you have stored the drug name in the database
      final snapshot = await _database
          .child('medications')
          .orderByChild('drug')
          .equalTo(drugName)
          .once();

      if (snapshot.snapshot.exists) {
        var key = snapshot
            .snapshot.children.first.key; // Get the first key of the medication
        await _database.child('medications/$key').update({
          'quantity': newQuantity, // Update the quantity to the new value
        });
        print('Quantity updated to $newQuantity for medication: $drugName');
      } else {
        print('Medication not found for name: $drugName');
      }
    } catch (e) {
      print('Error updating drug quantity: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchSalesByPaymentMethod(
      List<String> paymentMethods) async {
    try {
      final snapshot = await _database.child('sales').once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> sales = [];

        data.forEach((key, value) {
          Map<String, dynamic> saleData = Map<String, dynamic>.from(value);
          if (paymentMethods.contains(saleData['paymentMethod'])) {
            sales.add({'id': key, ...saleData});
          }
        });
        return sales;
      } else {
        print("No sales found.");
        return [];
      }
    } catch (e) {
      print('Error fetching sales by payment method: $e');
      return [];
    }
  }

  Future<int> fetchDrugQuantity(String drugName) async {
    try {
      // Fetch all drugs under 'medications'
      final snapshot = await _database.child('medications').once();

      if (snapshot.snapshot.exists) {
        final medications = snapshot.snapshot.value as Map<dynamic, dynamic>;

        // Iterate through the medications to find the one that matches the drugName
        for (var key in medications.keys) {
          final drugData = medications[key] as Map<dynamic, dynamic>;
          if (drugData['drug'] == drugName) {
            // Return the quantity for the matching drug
            int quantity =
                drugData['quantity'] is int ? drugData['quantity'] : 0;
            return quantity;
          }
        }

        // If no matching drug is found
        print("No quantity found for drug $drugName.");
        return 0;
      } else {
        print("No medications found in the database.");
        return 0;
      }
    } catch (e) {
      print('Error fetching drug quantity: $e');
      return 0;
    }
  }

  // Record the sale of a drug
  Future<void> recordSale(
    String drugName,
    int quantitySold,
    double sellingPrice,
    String paymentMethod,
    String date, {
    required String reason,
  }) async {
    try {
      // Structure for the sales record
      final Map<String, dynamic> saleRecord = {
        'drugName': drugName,
        'quantitySold': quantitySold,
        'sellingPrice': sellingPrice,
        'paymentMethod': paymentMethod,
        'date': date,
      };

      // Add the reason only if the payment method is "Credit"
      if (paymentMethod == 'Credit') {
        saleRecord['reason'] = reason;
      }

      // Push the sale record to the database
      await _database.child('sales').push().set(saleRecord);
    } catch (e) {
      print('Error recording sale: $e');
    }
  }

  // Fetch all medications as a list (reuse fetchMedications method)

  // Update medication status
  Future<void> updateMedicationStatus(
      String medicationId, String status) async {
    try {
      await _database
          .child('medications/$medicationId')
          .update({'status': status});
    } catch (e) {
      print('Error updating medication status: $e');
    }
  }

  // Get the current Ethiopian date (mock implementation, should be replaced)
  String _getEthiopianDate() {
    // Replace this with actual logic for Ethiopian date conversion
    return 'Ethiopian Date';
  }

  getMedications() {}

  getDrugQuantity(String drugName) {}

  getMembers() {}
  Future<List<Map<String, dynamic>>> getAllMedicationsAsList() async {
    return await fetchMedications();
  }

  updateMemberStatus(String id, String s) {}
}
