import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/summary_metric_card.dart';
import '../controllers/reports_controller.dart';
import 'sales_report_page.dart';
import 'profit_analytics_page.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  final _controller = ReportsController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _controller.loadReports,
          child: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              const SectionHeader(
                title: 'Reports',
                subtitle: 'Open detailed reports and review high-level sales performance.',
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
                    title: 'Total Revenue',
                    value: '${_controller.totalRevenue.toStringAsFixed(0)} Birr',
                    icon: Icons.bar_chart_rounded,
                    iconColor: AppColors.primary,
                  ),
                  SummaryMetricCard(
                    title: 'Credit Sales',
                    value: _controller.creditSalesCount.toString(),
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.lowStock,
                  ),
                ],
              ),
              AppSpacing.heightXl,
              AppCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SalesReportPage()),
                  );
                },
                padding: AppSpacing.cardPadding,
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Color(0x140F8F83),
                    child: Icon(Icons.insert_chart_outlined, color: AppColors.primary),
                  ),
                  title: Text('Sales Report'),
                  subtitle: Text('View sales totals, monthly filters, and transaction details.'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ),
              AppSpacing.heightSm,
              AppCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfitAnalyticsPage()),
                  );
                },
                padding: AppSpacing.cardPadding,
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Color(0x142E9B53),
                    child: Icon(Icons.show_chart, color: AppColors.active),
                  ),
                  title: Text('Profit Analytics'),
                  subtitle: Text('Calculate gross and net profit with custom extra costs.'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
