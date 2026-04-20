import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/summary_metric_card.dart';
import '../controllers/sales_report_controller.dart';
import 'profit_analytics_page.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  final _controller = SalesReportController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _controller.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _controller.setSelectedDate(picked);
    }
  }

  Future<void> _showExpenseForm() async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var paymentMethod = 'Cash';
    var expenseDate = _controller.selectedDate;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
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
                      const SectionHeader(
                        title: 'Record Expense',
                        subtitle: 'Save an expense for the report.',
                      ),
                      AppSpacing.heightMd,
                      AppTextField(
                        controller: amountController,
                        label: 'Amount',
                        hintText: 'e.g. 250',
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.heightSm,
                      AppTextField(
                        controller: reasonController,
                        label: 'Reason',
                        hintText: 'e.g. Transport',
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Reason is required';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.heightSm,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Method',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: paymentMethod,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Cash',
                                child: Text('Cash'),
                              ),
                              DropdownMenuItem(
                                value: 'Mobile Banking',
                                child: Text('Mobile Banking'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() => paymentMethod = value);
                              }
                            },
                          ),
                        ],
                      ),
                      AppSpacing.heightSm,
                      AppTextField(
                        label: 'Date',
                        hintText: _controller
                            .formatSaleDate(expenseDate.toIso8601String()),
                        prefixIcon: const Icon(Icons.calendar_today),
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: expenseDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() => expenseDate = picked);
                          }
                        },
                      ),
                      AppSpacing.heightLg,
                      AppButton(
                        text: 'Save Expense',
                        isLoading: _controller.isRecordingExpense,
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          final success = await _controller.recordExpense(
                            amount:
                                double.tryParse(amountController.text.trim()) ??
                                    0,
                            reason: reasonController.text.trim(),
                            paymentMethod: paymentMethod,
                            date: expenseDate,
                          );

                          if (!context.mounted) {
                            return;
                          }

                          if (success) {
                            Navigator.of(context).pop(true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    amountController.dispose();
    reasonController.dispose();

    if (!mounted || saved != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense recorded successfully.')),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> sale) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final reason = (sale['reason'] ?? '').toString().trim();
        final unitPrice = (sale['unitPrice'] ?? 0).toString();
        final totalPrice = (sale['sellingPrice'] ?? 0).toString();

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.72,
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
                    title: 'Transaction Details',
                    subtitle: (sale['drugName'] ?? 'Medication').toString(),
                  ),
                  AppSpacing.heightMd,
                  Expanded(
                    child: AppCard(
                      padding: AppSpacing.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DetailRow(
                            label: 'Date',
                            value: _controller
                                .formatSaleDate((sale['date'] ?? '').toString()),
                          ),
                          _DetailRow(
                            label: 'Payment',
                            value:
                                (sale['paymentMethod'] ?? 'Unknown').toString(),
                          ),
                          _DetailRow(
                            label: 'Quantity',
                            value: (sale['quantitySold'] ?? 0).toString(),
                          ),
                          _DetailRow(
                            label: 'Unit Price',
                            value: '$unitPrice Birr',
                          ),
                          _DetailRow(
                            label: 'Total',
                            value: '$totalPrice Birr',
                          ),
                          if (reason.isNotEmpty)
                            _DetailRow(label: 'Reason', value: reason),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.filteredSales.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.errorMessage != null &&
            _controller.filteredSales.isEmpty) {
          return AppErrorState(
            message: _controller.errorMessage!,
            onRetry: _controller.loadData,
          );
        }

        final summaryCards = _controller.selectedPeriod == ReportPeriod.daily
            ? [
                SummaryMetricCard(
                  title: 'Transactions',
                  value: _controller.periodTransactions.toString(),
                  icon: Icons.receipt_long_outlined,
                  iconColor: AppColors.primary,
                ),
                SummaryMetricCard(
                  title: 'Revenue',
                  value: '${_controller.periodRevenue.toStringAsFixed(0)} Birr',
                  icon: Icons.payments_outlined,
                  iconColor: AppColors.active,
                ),
                SummaryMetricCard(
                  title: 'Day Expense',
                  value: '${_controller.periodExpense.toStringAsFixed(0)} Birr',
                  icon: Icons.money_off_csred_outlined,
                  iconColor: AppColors.expired,
                ),
                SummaryMetricCard(
                  title: 'Average Sale',
                  value:
                      '${_controller.averageTransactionValue.toStringAsFixed(0)} Birr',
                  icon: Icons.trending_up_outlined,
                  iconColor: AppColors.info,
                ),
              ]
            : [
                SummaryMetricCard(
                  title: 'Transactions',
                  value: _controller.periodTransactions.toString(),
                  icon: Icons.receipt_long_outlined,
                  iconColor: AppColors.primary,
                ),
                SummaryMetricCard(
                  title: 'Revenue',
                  value: '${_controller.periodRevenue.toStringAsFixed(0)} Birr',
                  icon: Icons.bar_chart_rounded,
                  iconColor: AppColors.active,
                ),
                SummaryMetricCard(
                  title: 'monthle report',
                  value: '${_controller.periodExpense.toStringAsFixed(0)} Birr',
                  icon: Icons.calendar_month_outlined,
                  iconColor: AppColors.expired,
                ),
                SummaryMetricCard(
                  title: 'Average Sale',
                  value:
                      '${_controller.averageTransactionValue.toStringAsFixed(0)} Birr',
                  icon: Icons.trending_up_outlined,
                  iconColor: AppColors.info,
                ),
              ];

        return RefreshIndicator(
          onRefresh: _controller.loadData,
          child: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              SectionHeader(
                title: 'Reports',
                subtitle:
                    'Track daily and monthly sales with a clear, date-based report.',
                trailing: null,
              ),
              AppSpacing.heightSm,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showExpenseForm,
                    icon: const Icon(Icons.add_card_outlined, size: 18),
                    label: const Text('Expense Record'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfitAnalyticsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.show_chart, size: 18),
                    label: const Text('Profit'),
                  ),
                ],
              ),
              AppSpacing.heightMd,
              AppCard(
                padding: AppSpacing.cardPadding,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _controller.goToPreviousPeriod,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        _controller.selectedPeriodLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                    IconButton(
                      onPressed: _controller.canMoveToNextPeriod
                          ? _controller.goToNextPeriod
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              AppSpacing.heightMd,
              SegmentedButton<ReportPeriod>(
                segments: const [
                  ButtonSegment<ReportPeriod>(
                    value: ReportPeriod.daily,
                    label: Text('Daily Report'),
                    icon: Icon(Icons.today_outlined),
                  ),
                  ButtonSegment<ReportPeriod>(
                    value: ReportPeriod.monthly,
                    label: Text('Monthly Report'),
                    icon: Icon(Icons.calendar_view_month_outlined),
                  ),
                ],
                selected: {_controller.selectedPeriod},
                onSelectionChanged: (selection) {
                  _controller.setPeriod(selection.first);
                },
              ),
              AppSpacing.heightMd,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: SalesReportController.paymentFilters.map((filter) {
                    final isSelected =
                        _controller.selectedPaymentFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) => _controller.setPaymentFilter(filter),
                      ),
                    );
                  }).toList(),
                ),
              ),
              AppSpacing.heightMd,
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 600
                          ? 2
                          : constraints.maxWidth >= 420
                              ? 2
                              : 1;

                  return GridView.builder(
                    itemCount: summaryCards.length,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisExtent: 132,
                    ),
                    itemBuilder: (context, index) => summaryCards[index],
                  );
                },
              ),
              AppSpacing.heightXl,
              const SectionHeader(
                title: 'Sales History',
                subtitle: 'Tap any transaction to see the full details.',
              ),
              AppSpacing.heightSm,
              if (_controller.filteredSales.isEmpty)
                AppEmptyState(
                  title: 'No Sales Found',
                  message: _controller.selectedPeriod == ReportPeriod.daily
                      ? 'No sales were recorded for the selected day.'
                      : 'No sales were recorded for the selected month.',
                  icon: Icons.receipt_long_outlined,
                )
              else
                ..._controller.filteredSales.map((sale) {
                  final amount = (sale['sellingPrice'] ?? 0).toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: () => _showTransactionDetails(sale),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          (sale['drugName'] ?? 'Medication').toString(),
                        ),
                        subtitle: Text(
                          'Qty ${sale['quantitySold'] ?? 0} - '
                          '${sale['paymentMethod'] ?? 'Unknown'} - '
                          '${_controller.formatSaleDate((sale['date'] ?? '').toString())}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          '$amount Birr',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
