import 'package:hive/hive.dart';

part 'medication.g.dart'; // Make sure the medication.g.dart is generated using build_runner

@HiveType(typeId: 0)
class Medication {
  @HiveField(0)
  final String medicationType;
  @HiveField(1)
  final String drug;
  @HiveField(2)
  final String strength;
  @HiveField(3)
  final String strengthUnit;
  @HiveField(4)
  final int quantity;
  @HiveField(5)
  final String measurement;
  @HiveField(6)
  final double purchasedPrice;
  @HiveField(7)
  final double sellingPrice;
  @HiveField(8)
  final DateTime expirationDate;
  @HiveField(9)
  final String batchNumber;
  @HiveField(10)
  final String madeIn;
  @HiveField(11)
  final String brandName;
  @HiveField(12)
  final String status;

  Medication({
    required this.medicationType,
    required this.drug,
    required this.strength,
    required this.strengthUnit,
    required this.quantity,
    required this.measurement,
    required this.purchasedPrice,
    required this.sellingPrice,
    required this.expirationDate,
    required this.batchNumber,
    required this.madeIn,
    required this.brandName,
    required this.status,
  });

  // Add the toMap method to convert Medication object to Map
  Map<String, dynamic> toMap() {
    return {
      'medicationType': medicationType,
      'drug': drug,
      'strength': strength,
      'strengthUnit': strengthUnit,
      'quantity': quantity,
      'measurement': measurement,
      'purchasedPrice': purchasedPrice,
      'sellingPrice': sellingPrice,
      'expirationDate': expirationDate.toIso8601String(),
      'batchNumber': batchNumber,
      'madeIn': madeIn,
      'brandName': brandName,
      'status': status,
    };
  }

  // Add fromMap method to convert Map to Medication object
  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      medicationType: map['medicationType'],
      drug: map['drug'],
      strength: map['strength'],
      strengthUnit: map['strengthUnit'],
      quantity: map['quantity'],
      measurement: map['measurement'],
      purchasedPrice: map['purchasedPrice'],
      sellingPrice: map['sellingPrice'],
      expirationDate: DateTime.parse(map['expirationDate']),
      batchNumber: map['batchNumber'],
      madeIn: map['madeIn'],
      brandName: map['brandName'],
      status: map['status'],
    );
  }
}
