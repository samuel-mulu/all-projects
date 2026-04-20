import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/summary_metric_card.dart';
import '../controllers/sales_controller.dart';
import 'sell_medication_page.dart';

class SalesView extends StatefulWidget {
  const SalesView({super.key});

  @override
  State<SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends State<SalesView> {
  final _controller = SalesController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _controller.loadSales,
          child: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              const SectionHeader(
                title: 'Sales',
                subtitle: 'Process new sales and review transaction history.',
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
                    title: 'Today Revenue',
                    value: '${_controller.todayRevenue.toStringAsFixed(0)} Birr',
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.active,
                  ),
                  SummaryMetricCard(
                    title: 'Transactions',
                    value: _controller.todayTransactions.toString(),
                    icon: Icons.receipt_long_outlined,
                    iconColor: AppColors.primary,
                  ),
                ],
              ),
              AppSpacing.heightLg,
              AppButton(
                text: 'Sell Medication',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SellMedicationPage()),
                  );
                },
              ),
              AppSpacing.heightXl,
              const SectionHeader(
                title: 'Sales History',
                subtitle: 'Most recent transactions.',
              ),
              AppSpacing.heightSm,
              if (_controller.sales.isEmpty)
                const AppCard(
                  padding: AppSpacing.cardPadding,
                  child: Center(child: Text('No sales recorded yet.')),
                )
              else
                ..._controller.sales.take(20).map((sale) {
                  final amount = (sale['sellingPrice'] ?? 0).toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x1F0F8F83),
                          child: Icon(Icons.medication_liquid, color: AppColors.primary),
                        ),
                        title: Text((sale['drugName'] ?? 'Medication').toString()),
                        subtitle: Text(
                          'Qty ${sale['quantitySold'] ?? 0} • '
                          '${sale['paymentMethod'] ?? 'Unknown'} • '
                          '${sale['date'] ?? ''}',
                        ),
                        trailing: Text(
                          '$amount Birr',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary),
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
