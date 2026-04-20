import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/medication.dart';

class FirebaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final Box<Medication> _medicationBox = Hive.box<Medication>('medication');

  Future<List<Map<String, dynamic>>> fetchMedications() async {
    try {
      final snapshot = await _database.child('medications').once();

      if (snapshot.snapshot.exists) {
        final rawData = snapshot.snapshot.value;
        if (rawData is! Map<dynamic, dynamic>) {
          return [];
        }

        final medications = <Map<String, dynamic>>[];

        await _medicationBox.clear();

        rawData.forEach((key, value) {
          if (value is! Map) {
            return;
          }

          final medicationData = Map<String, dynamic>.from(value);
          medications.add({'id': key, ...medicationData});

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

      if (_medicationBox.isNotEmpty) {
        return _medicationBox.keys.map((key) {
          final med = _medicationBox.get(key);
          return {'id': key, ...med!.toMap()};
        }).toList();
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchMedicationById(String medicationId) async {
    try {
      final snapshot = await _database.child('medications/$medicationId').once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final medicationData = Map<String, dynamic>.from(data);
        _medicationBox.put(medicationId, Medication.fromMap(medicationData));

        return {'id': medicationId, ...medicationData};
      }

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

  Future<int> fetchMedicationQuantity(String medicationId) async {
    try {
      final snapshot = await _database.child('medications/$medicationId').once();

      if (snapshot.snapshot.exists && snapshot.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        return int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
      }

      final cached = _medicationBox.get(medicationId);
      return cached?.quantity ?? 0;
    } catch (e) {
      debugPrint('Error fetching medication quantity: $e');
      final cached = _medicationBox.get(medicationId);
      return cached?.quantity ?? 0;
    }
  }

  Future<bool> updateMedicationQuantity(String medicationId, int newQuantity) async {
    try {
      await _database.child('medications/$medicationId').update({
        'quantity': newQuantity,
      });

      final cached = _medicationBox.get(medicationId);
      if (cached != null) {
        final updated = Medication.fromMap({
          ...cached.toMap(),
          'quantity': newQuantity,
        });
        _medicationBox.put(medicationId, updated);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating medication quantity: $e');
      return false;
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

  Future<List<Map<String, dynamic>>> fetchExpenses() async {
    try {
      final snapshot = await _database.child('expenses').once();

      if (snapshot.snapshot.exists) {
        final rawData = snapshot.snapshot.value;
        if (rawData is! Map<dynamic, dynamic>) {
          return [];
        }

        final expenses = <Map<String, dynamic>>[];
        rawData.forEach((key, value) {
          if (value is! Map) {
            return;
          }

          final expenseData = Map<String, dynamic>.from(value);
          expenses.add({'id': key, ...expenseData});
        });

        expenses.sort((a, b) {
          final firstDate = (a['date'] ?? '').toString();
          final secondDate = (b['date'] ?? '').toString();
          return secondDate.compareTo(firstDate);
        });

        return expenses;
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
      return [];
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

  Future<bool> recordSale({
    required String medicationId,
    required String drugName,
    required int quantitySold,
    required double unitPrice,
    required double totalSellingPrice,
    required String paymentMethod,
    required String date,
    required String reason,
  }) async {
    try {
      final Map<String, dynamic> saleRecord = {
        'medicationId': medicationId,
        'drugName': drugName,
        'quantitySold': quantitySold,
        'unitPrice': unitPrice,
        'sellingPrice': totalSellingPrice,
        'paymentMethod': paymentMethod,
        'date': date,
      };

      if (paymentMethod == 'Credit') {
        saleRecord['reason'] = reason;
      }

      await _database.child('sales').push().set(saleRecord);
      return true;
    } catch (e) {
      debugPrint('Error recording sale: $e');
      return false;
    }
  }

  Future<bool> recordExpense({
    required double amount,
    required String reason,
    required String paymentMethod,
    required String date,
  }) async {
    try {
      await _database.child('expenses').push().set({
        'amount': amount,
        'reason': reason,
        'paymentMethod': paymentMethod,
        'date': date,
      });
      return true;
    } catch (e) {
      debugPrint('Error recording expense: $e');
      return false;
    }
  }

  Future<bool> updateMedicationStatus(String medicationId, String status) async {
    try {
      await _database.child('medications/$medicationId').update({'status': status});
      final cached = _medicationBox.get(medicationId);
      if (cached != null) {
        _medicationBox.put(medicationId, Medication.fromMap({...cached.toMap(), 'status': status}));
      }
      return true;
    } catch (e) {
      debugPrint('Error updating medication status: $e');
      return false;
    }
  }
}
