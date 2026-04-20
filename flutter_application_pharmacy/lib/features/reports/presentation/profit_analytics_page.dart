import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/app_error_state.dart';
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
          if (_controller.isLoading && _controller.grossProfit == 0) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.errorMessage != null && _controller.grossProfit == 0) {
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
                AppCard(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Profit Summary',
                        subtitle: 'Overview of income after deducting stock costs.',
                      ),
                      AppSpacing.heightMd,
                      _buildProfitTile('Gross Profit', _controller.grossProfit, AppColors.active),
                      AppSpacing.heightMd,
                      _buildProfitTile('Net Profit', _controller.netProfit, AppColors.primary),
                      AppSpacing.heightMd,
                      const Divider(),
                      AppSpacing.heightSm,
                      Text(
                        'Gross profit is calculated as (Selling Price - Purchase Price) × Quantity Sold for all transactions.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                AppSpacing.heightXl,
                AppCard(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Overheads & Extra Costs',
                        subtitle: 'Deduct rent, salary, or other expenses.',
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

  Widget _buildProfitTile(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(
          '${value.toStringAsFixed(2)} Birr',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
