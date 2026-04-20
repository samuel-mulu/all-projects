import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/summary_metric_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

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
                subtitle: 'A quick look at your pharmacy metrics.',
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
                    title: 'Low Stock',
                    value: _controller.lowStockCount.toString(),
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.lowStock,
                  ),
                  SummaryMetricCard(
                    title: 'Expiring Soon',
                    value: _controller.expiringSoonCount.toString(),
                    icon: Icons.event_busy_rounded,
                    iconColor: AppColors.expired,
                  ),
                  SummaryMetricCard(
                    title: 'Total Items',
                    value: _controller.medications.length.toString(),
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppColors.primary,
                  ),
                  SummaryMetricCard(
                    title: 'Today Sales',
                    value: _controller.todaySalesCount.toString(),
                    icon: Icons.shopping_cart_outlined,
                    iconColor: AppColors.active,
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
                          child: Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
                        ),
                        title: Text((activity['drugName'] ?? 'Medication').toString()),
                        subtitle: Text('${activity['quantitySold'] ?? 0} units • ${activity['paymentMethod'] ?? ''}'),
                        trailing: Text(
                          '${activity['sellingPrice'] ?? 0} Birr',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
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
