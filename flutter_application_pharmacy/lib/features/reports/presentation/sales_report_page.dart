import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../controllers/sales_report_controller.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  final _controller = SalesReportController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Report')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.filteredSales.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.errorMessage != null && _controller.filteredSales.isEmpty) {
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
                AppCard(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Revenue Summary',
                        subtitle: 'Total income for the selected period.',
                      ),
                      AppSpacing.heightMd,
                      Text(
                        '${_controller.totalRevenue.toStringAsFixed(2)} Birr',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.heightLg,
                      DropdownButtonFormField<String>(
                        value: _controller.selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Ethiopian Month',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'All', child: Text('All Months')),
                          ...SalesReportController.ethiopianMonths.values.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                        ],
                        onChanged: (v) => _controller.setMonth(v!),
                      ),
                    ],
                  ),
                ),
                AppSpacing.heightXl,
                const SectionHeader(title: 'Recent Transactions', subtitle: 'Detailed list of recorded sales.'),
                AppSpacing.heightSm,
                if (_controller.filteredSales.isEmpty)
                  const AppEmptyState(
                    title: 'No Transactions',
                    message: 'No sales were found for the selected month.',
                    icon: Icons.receipt_long_outlined,
                  )
                else
                  ..._controller.filteredSales.map((sale) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.receipt, color: AppColors.primary, size: 20),
                          ),
                          title: Text(sale['drugName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${sale['sellingPrice']} Birr • Qty ${sale['quantitySold']}'),
                              Text(
                                _controller.formatToEthiopian(sale['date']?.toString() ?? ''),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: sale['paymentMethod'] != 'Cash' 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.lowStock.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sale['paymentMethod'].toString(),
                                  style: const TextStyle(fontSize: 10, color: AppColors.lowStock, fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
