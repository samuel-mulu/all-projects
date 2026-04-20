import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../controllers/inventory_controller.dart';
import 'add_medication_page.dart';
import 'pending_items_page.dart';
import 'inactive_items_page.dart';
import 'widgets/medication_list_item.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final _controller = InventoryController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
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

        return RefreshIndicator(
          onRefresh: _controller.loadData,
          child: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              const SectionHeader(
                title: 'Inventory',
                subtitle: 'Review stock, add new items, and monitor records.',
              ),
              AppSpacing.heightMd,
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Add Medication',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddMedicationPage()),
                        );
                      },
                    ),
                  ),
                  AppSpacing.widthSm,
                  Expanded(
                    child: AppButton(
                      text: 'Pending',
                      isOutlined: true,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PendingItemsPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              AppSpacing.heightSm,
              AppButton(
                text: 'View Inactive Items',
                isOutlined: true,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InactiveItemsPage()),
                  );
                },
              ),
              AppSpacing.heightLg,
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
                  title: 'No Medications Found',
                  message: _searchController.text.isEmpty
                      ? 'Start by adding a new medication to your inventory.'
                      : 'No results for "${_searchController.text}".',
                  onAction: _searchController.text.isNotEmpty
                      ? () {
                          _searchController.clear();
                          _controller.setSearchQuery('');
                        }
                      : null,
                  actionLabel: 'Clear Search',
                )
              else
                ..._controller.filteredMedications.map((medication) {
                  return MedicationListItem(medication: medication);
                }),
            ],
          ),
        );
      },
    );
  }
}
