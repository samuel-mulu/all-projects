import 'package:flutter/material.dart';

import '../../services/app_settings_service.dart';
import '../theme/app_colors.dart';

const _approvedStatuses = {
  '',
  'approved',
  'active',
  'completed',
  'standard',
};

const _pendingStatuses = {
  'pending',
  'pending_review',
};

const _rejectedStatuses = {
  'rejected',
  'inactive',
};

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

String normalizeMedicationWorkflowStatus(Map<String, dynamic> medication) {
  final rawStatus = (medication['status'] ?? '').toString().trim().toLowerCase();

  if (_pendingStatuses.contains(rawStatus)) {
    return 'pending';
  }
  if (_rejectedStatuses.contains(rawStatus)) {
    return 'rejected';
  }
  if (_approvedStatuses.contains(rawStatus)) {
    return 'approved';
  }

  return 'approved';
}

bool isMedicationApproved(Map<String, dynamic> medication) =>
    normalizeMedicationWorkflowStatus(medication) == 'approved';

bool isMedicationPending(Map<String, dynamic> medication) =>
    normalizeMedicationWorkflowStatus(medication) == 'pending';

bool isMedicationRejected(Map<String, dynamic> medication) =>
    normalizeMedicationWorkflowStatus(medication) == 'rejected';

bool isMedicationOutOfStock(Map<String, dynamic> medication) {
  return parseMedicationQuantity(medication) <= 0;
}

bool isMedicationExpired(Map<String, dynamic> medication) {
  final expiry = parseMedicationExpiry(medication);
  if (expiry == null) {
    return false;
  }
  return expiry.isBefore(DateTime.now());
}

bool isMedicationLowStock(Map<String, dynamic> medication) {
  final quantity = parseMedicationQuantity(medication);
  final threshold = AppSettingsService.instance.stockAlertThreshold;
  return quantity > 0 && quantity <= threshold;
}

bool isMedicationExpiringSoon(Map<String, dynamic> medication) {
  final expiry = parseMedicationExpiry(medication);
  if (expiry == null) {
    return false;
  }

  final difference = expiry.difference(DateTime.now()).inDays;
  final threshold = AppSettingsService.instance.expiryAlertDays;
  return difference >= 0 && difference <= threshold;
}

bool isMedicationStockAlert(Map<String, dynamic> medication) {
  return isMedicationOutOfStock(medication) || isMedicationLowStock(medication);
}

bool isMedicationExpiryAlert(Map<String, dynamic> medication) {
  return isMedicationExpired(medication) || isMedicationExpiringSoon(medication);
}

MedicationStatusInfo resolveMedicationStatus(Map<String, dynamic> medication) {
  final workflowStatus = normalizeMedicationWorkflowStatus(medication);

  if (workflowStatus == 'pending') {
    return const MedicationStatusInfo(
      label: 'Pending Approval',
      color: AppColors.pending,
    );
  }

  if (workflowStatus == 'rejected') {
    return const MedicationStatusInfo(
      label: 'Rejected',
      color: AppColors.inactive,
    );
  }

  if (isMedicationExpired(medication)) {
    return const MedicationStatusInfo(
      label: 'Expired',
      color: AppColors.expired,
    );
  }

  if (isMedicationOutOfStock(medication)) {
    return const MedicationStatusInfo(
      label: 'Out of Stock',
      color: AppColors.expired,
    );
  }

  if (isMedicationLowStock(medication)) {
    return const MedicationStatusInfo(
      label: 'Low Stock',
      color: AppColors.lowStock,
    );
  }

  if (isMedicationExpiringSoon(medication)) {
    return const MedicationStatusInfo(
      label: 'Expiring Soon',
      color: AppColors.lowStock,
    );
  }

  return const MedicationStatusInfo(
    label: 'Approved',
    color: AppColors.active,
  );
}
