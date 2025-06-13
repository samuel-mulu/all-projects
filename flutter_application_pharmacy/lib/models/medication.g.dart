// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicationAdapter extends TypeAdapter<Medication> {
  @override
  final int typeId = 0;

  @override
  Medication read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medication(
      medicationType: fields[0] as String,
      drug: fields[1] as String,
      strength: fields[2] as String,
      strengthUnit: fields[3] as String,
      quantity: fields[4] as int,
      measurement: fields[5] as String,
      purchasedPrice: fields[6] as double,
      sellingPrice: fields[7] as double,
      expirationDate: fields[8] as DateTime,
      batchNumber: fields[9] as String,
      madeIn: fields[10] as String,
      brandName: fields[11] as String,
      status: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Medication obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.medicationType)
      ..writeByte(1)
      ..write(obj.drug)
      ..writeByte(2)
      ..write(obj.strength)
      ..writeByte(3)
      ..write(obj.strengthUnit)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.measurement)
      ..writeByte(6)
      ..write(obj.purchasedPrice)
      ..writeByte(7)
      ..write(obj.sellingPrice)
      ..writeByte(8)
      ..write(obj.expirationDate)
      ..writeByte(9)
      ..write(obj.batchNumber)
      ..writeByte(10)
      ..write(obj.madeIn)
      ..writeByte(11)
      ..write(obj.brandName)
      ..writeByte(12)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
