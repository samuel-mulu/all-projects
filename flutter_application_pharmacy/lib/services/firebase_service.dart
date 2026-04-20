import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/medication.dart';

class FirebaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final Box<Medication> _medicationBox = Hive.box<Medication>('medication');

  // Fetch all medications with local caching support
  Future<List<Map<String, dynamic>>> fetchMedications() async {
    try {
      final snapshot = await _database.child('medications').once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> medications = [];

        // Clear local cache and update with fresh data
        await _medicationBox.clear();

        data.forEach((key, value) {
          final medicationData = Map<String, dynamic>.from(value);
          medications.add({'id': key, ...medicationData});
          
          // Save to local cache
          try {
            _medicationBox.put(key, Medication.fromMap(medicationData));
          } catch (e) {
            debugPrint('Error caching medication $key: $e');
          }
        });
        return medications;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching medications (falling back to cache): $e');
      
      // Fallback to local cache
      if (_medicationBox.isNotEmpty) {
        return _medicationBox.keys.map((key) {
          final med = _medicationBox.get(key);
          return {'id': key, ...med!.toMap()};
        }).toList();
      }
      return [];
    }
  }

  // Fetch a specific medication by its ID
  Future<Map<String, dynamic>?> fetchMedicationById(String medicationId) async {
    try {
      final snapshot = await _database.child('medications/$medicationId').once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final medicationData = Map<String, dynamic>.from(data);
        
        // Update specific item in cache
        _medicationBox.put(medicationId, Medication.fromMap(medicationData));
        
        return {'id': medicationId, ...medicationData};
      }
      
      // Try local cache if not found in Firebase (might be offline)
      final cached = _medicationBox.get(medicationId);
      if (cached != null) {
        return {'id': medicationId, ...cached.toMap()};
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching medication by ID: $e');
      final cached = _medicationBox.get(medicationId);
      return cached != null ? {'id': medicationId, ...cached.toMap()} : null;
    }
  }

  // Update the quantity of a specific drug
  Future<void> updateDrugQuantity(String drugName, int newQuantity) async {
    try {
      final snapshot = await _database
          .child('medications')
          .orderByChild('drug')
          .equalTo(drugName)
          .once();

      if (snapshot.snapshot.exists) {
        final key = snapshot.snapshot.children.first.key;
        await _database.child('medications/$key').update({
          'quantity': newQuantity,
        });
        
        // Update local cache if key is known
        final cached = _medicationBox.get(key);
        if (cached != null) {
          final updated = Medication.fromMap({...cached.toMap(), 'quantity': newQuantity});
          _medicationBox.put(key!, updated);
        }
      }
    } catch (e) {
      debugPrint('Error updating drug quantity: $e');
      // In a real production app, we might want to queue this update for when we are back online
    }
  }

  Future<List<Map<String, dynamic>>> fetchSales({int limit = 50, String? startAfterKey}) async {
    try {
      Query query = _database.child('sales').orderByKey();
      
      if (startAfterKey != null) {
        query = query.startAfter(startAfterKey);
      }
      
      query = query.limitToFirst(limit);
      
      final snapshot = await query.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final sales = <Map<String, dynamic>>[];

        data.forEach((key, value) {
          final saleData = Map<String, dynamic>.from(value);
          sales.add({'id': key, ...saleData});
        });

        // Since we are fetching by key, we might need to sort by date descending manually if needed,
        // or just rely on keys if they are push IDs (which are chronological).
        sales.sort((a, b) {
          final firstDate = (a['date'] ?? '').toString();
          final secondDate = (b['date'] ?? '').toString();
          return secondDate.compareTo(firstDate);
        });

        return sales;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching sales: $e');
      return [];
    }
  }

  Future<int> fetchDrugQuantity(String drugName) async {
    try {
      final snapshot = await _database
          .child('medications')
          .orderByChild('drug')
          .equalTo(drugName)
          .once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.children.first.value as Map<dynamic, dynamic>;
        return int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Error fetching drug quantity: $e');
      // Fallback to cache search by name
      final cached = _medicationBox.values.where((m) => m.drug == drugName).firstOrNull;
      return cached?.quantity ?? 0;
    }
  }

  Future<bool> saveMedication({
    String? id,
    required Map<String, dynamic> data,
  }) async {
    try {
      if (id == null || id.isEmpty) {
        final ref = _database.child('medications').push();
        await ref.set(data);
        _medicationBox.put(ref.key!, Medication.fromMap(data));
      } else {
        await _database.child('medications/$id').update(data);
        _medicationBox.put(id, Medication.fromMap(data));
      }
      return true;
    } catch (e) {
      debugPrint('Error saving medication: $e');
      return false;
    }
  }

  Future<void> recordSale(
    String drugName,
    int quantitySold,
    double sellingPrice,
    String paymentMethod,
    String date, {
    required String reason,
  }) async {
    try {
      final Map<String, dynamic> saleRecord = {
        'drugName': drugName,
        'quantitySold': quantitySold,
        'sellingPrice': sellingPrice,
        'paymentMethod': paymentMethod,
        'date': date,
      };

      if (paymentMethod == 'Credit') {
        saleRecord['reason'] = reason;
      }

      await _database.child('sales').push().set(saleRecord);
    } catch (e) {
      debugPrint('Error recording sale: $e');
    }
  }

  Future<void> updateMedicationStatus(String medicationId, String status) async {
    try {
      await _database.child('medications/$medicationId').update({'status': status});
      final cached = _medicationBox.get(medicationId);
      if (cached != null) {
        _medicationBox.put(medicationId, Medication.fromMap({...cached.toMap(), 'status': status}));
      }
    } catch (e) {
      debugPrint('Error updating medication status: $e');
    }
  }
}
