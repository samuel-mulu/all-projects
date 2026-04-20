import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/utils/medication_status.dart';

class MedicationListItem extends StatelessWidget {
  final Map<String, dynamic> medication;
  final VoidCallback? onTap;

  const MedicationListItem({
    super.key,
    required this.medication,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = resolveMedicationStatus(medication);
    final quantity = parseMedicationQuantity(medication);
    final expiry = parseMedicationExpiry(medication);
    final measurement = (medication['measurement'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (medication['drug'] ?? 'Unnamed').toString(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        (medication['brandName'] ?? 'No brand').toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(label: status.label, color: status.color),
              ],
            ),
            AppSpacing.heightMd,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InventoryMeta(label: 'Stock', value: '$quantity $measurement'),
                _InventoryMeta(
                  label: 'Expiry',
                  value: expiry == null ? 'N/A' : expiry.toIso8601String().split('T').first,
                ),
                _InventoryMeta(label: 'Type', value: (medication['medicationType'] ?? '').toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryMeta extends StatelessWidget {
  final String label;
  final String value;

  const _InventoryMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
