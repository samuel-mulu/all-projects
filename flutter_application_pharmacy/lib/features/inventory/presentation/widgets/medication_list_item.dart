import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/medication_status.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_chip.dart';

class MedicationListItem extends StatelessWidget {
  const MedicationListItem({
    super.key,
    required this.medication,
    this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.isSelected = false,
    this.showPurchasePrice = false,
  });

  final Map<String, dynamic> medication;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool isSelected;
  final bool showPurchasePrice;

  @override
  Widget build(BuildContext context) {
    final status = resolveMedicationStatus(medication);
    final quantity = parseMedicationQuantity(medication);
    final expiry = parseMedicationExpiry(medication);
    final measurement = (medication['measurement'] ?? '').toString().trim();
    final brandName = (medication['brandName'] ?? 'No brand').toString();
    final drugName = (medication['drug'] ?? 'Unnamed').toString();
    final medicationType =
        (medication['medicationType'] ?? '').toString().trim();
    final strength = [
      (medication['strength'] ?? '').toString().trim(),
      (medication['strengthUnit'] ?? '').toString().trim(),
    ].where((value) => value.isNotEmpty).join(' ');

    final borderColor = selectionMode && isSelected
        ? AppColors.primary.withValues(alpha: 0.45)
        : AppColors.border;
    final highlightColor = selectionMode && isSelected
        ? AppColors.primary.withValues(alpha: 0.05)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        color: highlightColor,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.medication_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    AppSpacing.widthSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drugName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              brandName,
                              if (medicationType.isNotEmpty) medicationType,
                            ].join('  |  '),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          if (strength.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              strength,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (selectionMode)
                          Container(
                            height: 28,
                            width: 28,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              size: 18,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        if (selectionMode) const SizedBox(height: 8),
                        StatusChip(label: status.label, color: status.color),
                      ],
                    ),
                  ],
                ),
                AppSpacing.heightMd,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricPill(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stock',
                      value:
                          '$quantity ${measurement.isEmpty ? 'unit' : measurement}',
                    ),
                    _MetricPill(
                      icon: Icons.sell_outlined,
                      label: 'Sell',
                      value: '${_toMoney(medication['sellingPrice'])} Birr',
                      emphasize: true,
                    ),
                    if (showPurchasePrice)
                      _MetricPill(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Buy',
                        value: '${_toMoney(medication['purchasedPrice'])} Birr',
                      ),
                    _MetricPill(
                      icon: Icons.event_outlined,
                      label: 'Expiry',
                      value: expiry == null
                          ? 'N/A'
                          : DateFormat('dd MMM yyyy').format(expiry),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _toMoney(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }

    return (double.tryParse(value?.toString() ?? '') ?? 0.0).toStringAsFixed(2);
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: emphasize
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: emphasize ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: emphasize ? AppColors.primaryDark : null,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
