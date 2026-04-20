import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/summary_metric_card.dart';
import '../../inventory/presentation/widgets/medication_list_item.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.onOpenInventory,
    required this.onOpenSales,
  });

  final void Function({String? medicationId}) onOpenInventory;
  final VoidCallback onOpenSales;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final _controller = DashboardController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMedicationGroup({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> medications,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
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
                SectionHeader(
                  title: title,
                  subtitle: subtitle,
                ),
                AppSpacing.heightMd,
                Expanded(
                  child: medications.isEmpty
                      ? const AppEmptyState(
                          title: 'No Medications',
                          message: 'There are no medications in this category right now.',
                          icon: Icons.inventory_2_outlined,
                        )
                      : ListView.builder(
                          itemCount: medications.length,
                          itemBuilder: (context, index) {
                            final medication = medications[index];
                            return MedicationListItem(
                              medication: medication,
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onOpenInventory(
                                  medicationId: medication['id']?.toString(),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.medications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.errorMessage != null && _controller.medications.isEmpty) {
          return AppErrorState(
            message: _controller.errorMessage!,
            onRetry: _controller.loadData,
          );
        }

        return RefreshIndicator(
          onRefresh: _controller.loadData,
          child: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              const SectionHeader(
                title: 'Overview',
                subtitle: 'Track medicines that need attention and jump straight into inventory management.',
              ),
              AppSpacing.heightMd,
              GridView.count(
                crossAxisCount: 2,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.1,
                children: [
                  SummaryMetricCard(
                    title: 'Stock Alert',
                    value: _controller.stockAlertCount.toString(),
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.lowStock,
                    onTap: () => _showMedicationGroup(
                      title: 'Stock Alert Medications',
                      subtitle:
                          'Out of stock items and medications at or below ${_controller.stockAlertThreshold} units.',
                      medications: _controller.stockAlertMedications,
                    ),
                  ),
                  SummaryMetricCard(
                    title: 'Expiry Alert',
                    value: _controller.expiryAlertCount.toString(),
                    icon: Icons.event_busy_rounded,
                    iconColor: AppColors.expired,
                    onTap: () => _showMedicationGroup(
                      title: 'Expiry Alert Medications',
                      subtitle:
                          'Expired items and medications expiring within ${_controller.expiryAlertDays} days.',
                      medications: _controller.expiryAlertMedications,
                    ),
                  ),
                  SummaryMetricCard(
                    title: 'Total Inventory',
                    value: _controller.approvedInventoryCount.toString(),
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppColors.primary,
                    onTap: () => widget.onOpenInventory(),
                  ),
                  SummaryMetricCard(
                    title: 'Today Sales',
                    value: _controller.todaySalesCount.toString(),
                    icon: Icons.shopping_cart_outlined,
                    iconColor: AppColors.active,
                    onTap: widget.onOpenSales,
                  ),
                ],
              ),
              AppSpacing.heightXl,
              const SectionHeader(
                title: 'Recent Activity',
                subtitle: 'Most recent transactions recorded today.',
              ),
              AppSpacing.heightSm,
              if (_controller.recentActivity.isEmpty)
                const AppCard(
                  padding: AppSpacing.cardPadding,
                  child: Center(child: Text('No recent activity recorded.')),
                )
              else
                ..._controller.recentActivity.map((activity) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x1F0F8F83),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text((activity['drugName'] ?? 'Medication').toString()),
                        subtitle: Text(
                          '${activity['quantitySold'] ?? 0} units - ${activity['paymentMethod'] ?? ''}',
                        ),
                        trailing: Text(
                          '${activity['sellingPrice'] ?? 0} Birr',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
