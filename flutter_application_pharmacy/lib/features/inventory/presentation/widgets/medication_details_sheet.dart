import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/medication_status.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_chip.dart';

class MedicationDetailsSheet extends StatelessWidget {
  const MedicationDetailsSheet({
    super.key,
    required this.medication,
    this.onEdit,
    this.onSell,
    this.onApprove,
    this.onReject,
  });

  final Map<String, dynamic> medication;
  final VoidCallback? onEdit;
  final VoidCallback? onSell;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final status = resolveMedicationStatus(medication);
    final quantity = parseMedicationQuantity(medication);
    final expiry = parseMedicationExpiry(medication);
    final strength = [
      (medication['strength'] ?? '').toString().trim(),
      (medication['strengthUnit'] ?? '').toString().trim(),
    ].where((value) => value.isNotEmpty).join(' ');

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              AppSpacing.heightMd,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (medication['drug'] ?? 'Unnamed medication').toString(),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        AppSpacing.heightXs,
                        Text(
                          (medication['brandName'] ?? 'No brand name').toString(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(label: status.label, color: status.color),
                ],
              ),
              AppSpacing.heightLg,
              Expanded(
                child: ListView(
                  children: [
                    _DetailCard(
                      title: 'Registered Details',
                      children: [
                        _DetailItem(label: 'Medication Type', value: (medication['medicationType'] ?? 'N/A').toString()),
                        _DetailItem(label: 'Strength', value: strength.isEmpty ? 'N/A' : strength),
                        _DetailItem(
                          label: 'Stock',
                          value: '$quantity ${(medication['measurement'] ?? '').toString().trim()}'.trim(),
                        ),
                        _DetailItem(
                          label: 'Expiry Date',
                          value: expiry == null ? 'Not set' : DateFormat('dd MMM yyyy').format(expiry),
                        ),
                        _DetailItem(label: 'Batch Number', value: (medication['batchNumber'] ?? 'N/A').toString()),
                        _DetailItem(label: 'Origin', value: (medication['madeIn'] ?? 'N/A').toString()),
                      ],
                    ),
                    AppSpacing.heightMd,
                    _DetailCard(
                      title: 'Pricing',
                      children: [
                        _DetailItem(label: 'Purchase Price', value: '${medication['purchasedPrice'] ?? 0} Birr'),
                        _DetailItem(label: 'Selling Price', value: '${medication['sellingPrice'] ?? 0} Birr'),
                      ],
                    ),
                  ],
                ),
              ),
              if (_hasActions) ...[
                AppSpacing.heightMd,
                if (onApprove != null) ...[
                  AppButton(
                    text: 'Approve Medication',
                    onPressed: onApprove,
                    backgroundColor: AppColors.active,
                  ),
                  AppSpacing.heightSm,
                ],
                if (onReject != null) ...[
                  AppButton(
                    text: 'Reject Medication',
                    onPressed: onReject,
                    isOutlined: true,
                    foregroundColor: AppColors.error,
                  ),
                  AppSpacing.heightSm,
                ],
                if (onSell != null) ...[
                  AppButton(
                    text: 'Sell Medication',
                    onPressed: onSell,
                  ),
                  AppSpacing.heightSm,
                ],
                if (onEdit != null)
                  AppButton(
                    text: 'Edit Medication',
                    onPressed: onEdit,
                    isOutlined: true,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasActions =>
      onEdit != null || onSell != null || onApprove != null || onReject != null;
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          AppSpacing.heightMd,
          ...children,
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
