import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../inventory/presentation/widgets/medication_list_item.dart';
import '../controllers/sales_controller.dart';
import 'sell_medication_page.dart';

class SalesView extends StatefulWidget {
  const SalesView({super.key});

  @override
  State<SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends State<SalesView> {
  final _controller = SalesController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSellModal(Map<String, dynamic> medication) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SellMedicationPage(
        initialMedication: medication,
        showScaffold: false,
        autoCloseOnSuccess: true,
      ),
    );

    if (!mounted || result != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale recorded successfully.')),
    );
    await _controller.loadData();
  }

  Future<void> _openBatchSellModal() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SellMedicationPage(
        showScaffold: false,
        autoCloseOnSuccess: true,
      ),
    );

    if (!mounted || result != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Batch sale recorded successfully.')),
    );
    await _controller.loadData();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.medications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _controller.loadData,
          child: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Batch Sell',
                  onPressed: _openBatchSellModal,
                  icon: const Icon(Icons.playlist_add_check_circle_outlined),
                ),
              ),
              AppSpacing.heightSm,
              AppTextField(
                controller: _searchController,
                label: 'Search',
                hintText: 'Search by drug or brand name',
                prefixIcon: const Icon(Icons.search),
                onChanged: _controller.setSearchQuery,
              ),
              AppSpacing.heightSm,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _controller.filterTypes.map((type) {
                    final isSelected = _controller.selectedFilter == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (_) => _controller.setFilter(type),
                      ),
                    );
                  }).toList(),
                ),
              ),
              AppSpacing.heightMd,
              if (_controller.filteredMedications.isEmpty)
                AppEmptyState(
                  title: 'No Medications Ready',
                  message: _searchController.text.isEmpty
                      ? 'Approved medications with stock will appear here.'
                      : 'No results for "${_searchController.text}".',
                  actionLabel: 'Clear Search',
                  onAction: _searchController.text.isNotEmpty
                      ? () {
                          _searchController.clear();
                          _controller.setSearchQuery('');
                        }
                      : null,
                )
              else
                ..._controller.filteredMedications.map((medication) {
                  return MedicationListItem(
                    medication: medication,
                    onTap: () => _openSellModal(medication),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
