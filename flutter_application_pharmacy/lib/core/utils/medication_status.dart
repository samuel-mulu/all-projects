import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MedicationStatusInfo {
  const MedicationStatusInfo({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

int parseMedicationQuantity(Map<String, dynamic> medication) {
  final quantity = medication['quantity'];
  if (quantity is int) {
    return quantity;
  }
  if (quantity is double) {
    return quantity.toInt();
  }
  if (quantity is String) {
    return int.tryParse(quantity) ?? 0;
  }
  return 0;
}

DateTime? parseMedicationExpiry(Map<String, dynamic> medication) {
  final rawDate = medication['expirationDate'];
  if (rawDate is String && rawDate.isNotEmpty) {
    return DateTime.tryParse(rawDate);
  }
  return null;
}

MedicationStatusInfo resolveMedicationStatus(Map<String, dynamic> medication) {
  final quantity = parseMedicationQuantity(medication);
  final expiry = parseMedicationExpiry(medication);
  final status = (medication['status'] ?? '').toString().toLowerCase();
  final now = DateTime.now();

  if (expiry != null && expiry.isBefore(now)) {
    return const MedicationStatusInfo(
        label: 'Expired', color: AppColors.expired);
  }
  if (status == 'inactive') {
    return const MedicationStatusInfo(
        label: 'Inactive', color: AppColors.inactive);
  }
  if (status == 'pending') {
    return const MedicationStatusInfo(
        label: 'Pending', color: AppColors.pending);
  }
  if (quantity <= 5) {
    return const MedicationStatusInfo(
        label: 'Low Stock', color: AppColors.lowStock);
  }
  if (expiry != null && expiry.difference(now).inDays <= 30) {
    return const MedicationStatusInfo(
      label: 'Expiring Soon',
      color: AppColors.lowStock,
    );
  }
  return const MedicationStatusInfo(label: 'Active', color: AppColors.active);
}
