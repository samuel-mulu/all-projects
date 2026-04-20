import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/summary_metric_card.dart';
import '../controllers/profit_analytics_controller.dart';

class ProfitAnalyticsPage extends StatefulWidget {
  const ProfitAnalyticsPage({super.key});

  @override
  State<ProfitAnalyticsPage> createState() => _ProfitAnalyticsPageState();
}

class _ProfitAnalyticsPageState extends State<ProfitAnalyticsPage> {
  final _controller = ProfitAnalyticsController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profit Analytics')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.totalRevenue == 0) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.errorMessage != null && _controller.totalRevenue == 0) {
            return AppErrorState(
              message: _controller.errorMessage!,
              onRetry: _controller.calculateProfit,
            );
          }

          return RefreshIndicator(
            onRefresh: _controller.calculateProfit,
            child: ListView(
              padding: AppSpacing.pagePadding,
              children: [
                const SectionHeader(
                  title: 'Profit Report (All-time)',
                  subtitle: 'Revenue, stock cost, expenses, and net profit.',
                ),
                AppSpacing.heightMd,
                _buildSummaryCards(context),
                AppSpacing.heightMd,
                _buildFormulaCard(context),
                AppSpacing.heightXl,
                _buildSalesTableSection(context),
                AppSpacing.heightXl,
                _buildExpensesTableSection(context),
                AppSpacing.heightXl,
                AppCard(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Overheads & Extra Costs',
                        subtitle: 'Optional manual deductions (in addition to recorded expenses).',
                      ),
                      AppSpacing.heightMd,
                      if (_controller.dynamicControllers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                              AppSpacing.widthSm,
                              Expanded(child: Text('Add extra costs to calculate net profit.')),
                            ],
                          ),
                        )
                      else
                        ..._controller.dynamicControllers.asMap().entries.map((entry) {
                          final idx = entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: _controller.dynamicLabels[idx],
                                    controller: entry.value,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => _controller.calculateProfit(),
                                  ),
                                ),
                                AppSpacing.widthSm,
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                                  onPressed: () => _controller.removeExtraCost(idx),
                                ),
                              ],
                            ),
                          );
                        }),
                      AppSpacing.heightMd,
                      AppButton(
                        text: 'Add Extra Cost',
                        isOutlined: true,
                        onPressed: _controller.addExtraCost,
                      ),
                    ],
                  ),
                ),
                AppSpacing.heightMd,
                _buildFinalTotalsCard(context),
                AppSpacing.heightXl,
                AppButton(
                  text: 'Recalculate Totals',
                  onPressed: _controller.calculateProfit,
                  isLoading: _controller.isLoading,
                ),
                AppSpacing.heightMd,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final cards = [
      SummaryMetricCard(
        title: 'Total Revenue',
        value: '${_controller.totalRevenue.toStringAsFixed(2)} Birr',
        icon: Icons.payments_outlined,
        iconColor: AppColors.active,
      ),
      SummaryMetricCard(
        title: 'Cost of Goods Sold',
        value: '${_controller.costOfGoodsSold.toStringAsFixed(2)} Birr',
        icon: Icons.inventory_2_outlined,
        iconColor: AppColors.warning,
      ),
      SummaryMetricCard(
        title: 'Gross Profit',
        value: '${_controller.grossProfit.toStringAsFixed(2)} Birr',
        icon: Icons.trending_up_outlined,
        iconColor: AppColors.primary,
      ),
      SummaryMetricCard(
        title: 'Total Expenses',
        value: '${_controller.totalExpenses.toStringAsFixed(2)} Birr',
        icon: Icons.money_off_csred_outlined,
        iconColor: AppColors.expired,
      ),
      SummaryMetricCard(
        title: 'Net Profit',
        value: '${_controller.netProfit.toStringAsFixed(2)} Birr',
        icon: Icons.account_balance_wallet_outlined,
        iconColor: _controller.netProfit >= 0 ? AppColors.active : AppColors.error,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 800
                ? 3
                : constraints.maxWidth >= 500
                    ? 2
                    : 1;
        return GridView.builder(
          itemCount: cards.length,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 130,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
          ),
          itemBuilder: (_, index) => cards[index],
        );
      },
    );
  }

  Widget _buildFormulaCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Profit Formula',
            subtitle: 'This report uses a clear and consistent calculation.',
          ),
          AppSpacing.heightMd,
          _buildFormulaRow('Revenue', _controller.totalRevenue),
          _buildFormulaRow('minus Stock Cost', _controller.costOfGoodsSold),
          const Divider(),
          _buildFormulaRow('equals Gross Profit', _controller.grossProfit),
          _buildFormulaRow('minus Expenses', _controller.totalExpenses),
          const Divider(),
          Text(
            'equals Net Profit: ${_controller.netProfit.toStringAsFixed(2)} Birr',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: _controller.netProfit >= 0
                  ? AppColors.active
                  : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text('$label: ${value.toStringAsFixed(2)} Birr'),
    );
  }

  Widget _buildSalesTableSection(BuildContext context) {
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Sold Medicines',
            subtitle: 'All sold medicines with line-by-line profit details.',
          ),
          AppSpacing.heightMd,
          if (_controller.saleLines.isEmpty)
            const AppEmptyState(
              title: 'No Sales Data',
              message: 'No sales available to calculate profit.',
              icon: Icons.receipt_long_outlined,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowHeight: 44,
                dataRowMinHeight: 44,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Medicine')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Unit Sell')),
                  DataColumn(label: Text('Revenue')),
                  DataColumn(label: Text('Unit Purchase')),
                  DataColumn(label: Text('Cost')),
                  DataColumn(label: Text('Profit')),
                ],
                rows: _controller.saleLines.map((line) {
                  return DataRow(
                    cells: [
                      DataCell(Text(line.date)),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Text(
                            line.medicineName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(line.quantitySold.toString())),
                      DataCell(Text(line.unitSellPrice.toStringAsFixed(2))),
                      DataCell(Text(line.revenue.toStringAsFixed(2))),
                      DataCell(Text(line.unitPurchasePrice.toStringAsFixed(2))),
                      DataCell(Text(line.cost.toStringAsFixed(2))),
                      DataCell(Text(line.profit.toStringAsFixed(2))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpensesTableSection(BuildContext context) {
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Expenses',
            subtitle: 'Recorded expense entries used in net profit.',
          ),
          AppSpacing.heightMd,
          if (_controller.expenseLines.isEmpty)
            const AppEmptyState(
              title: 'No Expense Data',
              message: 'No expenses recorded yet.',
              icon: Icons.money_off_csred_outlined,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowHeight: 44,
                dataRowMinHeight: 44,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Amount')),
                ],
                rows: _controller.expenseLines.map((line) {
                  return DataRow(
                    cells: [
                      DataCell(Text(line.date)),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            line.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text('${line.amount.toStringAsFixed(2)} Birr')),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFinalTotalsCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Final Totals',
            subtitle: 'End-of-report reconciliation.',
          ),
          AppSpacing.heightSm,
          _buildFinalRow('Total Revenue', _controller.totalRevenue),
          _buildFinalRow('Cost of Goods Sold', _controller.costOfGoodsSold),
          _buildFinalRow('Gross Profit', _controller.grossProfit),
          _buildFinalRow('Recorded Expenses', _controller.recordedExpenses),
          _buildFinalRow('Extra Costs', _controller.extraCostsTotal),
          const Divider(),
          Text(
            'Net Profit: ${_controller.netProfit.toStringAsFixed(2)} Birr',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: _controller.netProfit >= 0
                  ? AppColors.active
                  : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text('${value.toStringAsFixed(2)} Birr'),
        ],
      ),
    );
  }
}
