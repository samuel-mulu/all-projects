import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../controllers/inventory_controller.dart';
import 'add_medication_page.dart';
import 'pending_items_page.dart';
import 'widgets/medication_details_sheet.dart';
import 'widgets/medication_list_item.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({
    super.key,
    this.initialMedicationId,
    this.onMedicationFocusHandled,
  });

  final String? initialMedicationId;
  final VoidCallback? onMedicationFocusHandled;

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final _controller = InventoryController();
  final _searchController = TextEditingController();
  String? _handledMedicationId;

  @override
  void didUpdateWidget(covariant InventoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMedicationId != widget.initialMedicationId) {
      _handledMedicationId = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openAddMedicationForm({String? medicationId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMedicationPage(medicationId: medicationId),
      ),
    );
    if (!mounted) {
      return;
    }
    await _controller.loadData();
  }

  Future<void> _updateMedicationStatus(
    Map<String, dynamic> medication,
    bool approve,
  ) async {
    Navigator.of(context).pop();

    final medicationId = medication['id']?.toString();
    if (medicationId == null || medicationId.isEmpty) {
      return;
    }

    final success = approve
        ? await _controller.approveMedication(medicationId)
        : await _controller.rejectMedication(medicationId);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? approve
                  ? 'Medication approved.'
                  : 'Medication rejected.'
              : 'Failed to update medication status.',
        ),
      ),
    );
  }

  Future<void> _editMedication(Map<String, dynamic> medication) async {
    Navigator.of(context).pop();
    final medicationId = medication['id']?.toString();
    if (medicationId == null || medicationId.isEmpty) {
      return;
    }

    await _openAddMedicationForm(medicationId: medicationId);
  }

  void _showMedicationDetails(Map<String, dynamic> medication) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MedicationDetailsSheet(
        medication: medication,
        onEdit: () => _editMedication(medication),
        onApprove: _controller.isPending(medication)
            ? () => _updateMedicationStatus(medication, true)
            : null,
        onReject: _controller.isPending(medication)
            ? () => _updateMedicationStatus(medication, false)
            : null,
      ),
    );
  }

  void _openFocusedMedicationIfNeeded() {
    final medicationId = widget.initialMedicationId;
    if (medicationId == null ||
        _controller.isLoading ||
        medicationId == _handledMedicationId) {
      return;
    }

    Map<String, dynamic>? medicationToOpen;
    for (final medication in _controller.approvedMedications) {
      if (medication['id']?.toString() == medicationId) {
        medicationToOpen = medication;
        break;
      }
    }

    _handledMedicationId = medicationId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.onMedicationFocusHandled?.call();
      if (medicationToOpen != null) {
        _showMedicationDetails(medicationToOpen);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        _openFocusedMedicationIfNeeded();

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
                subtitle: 'Manage approved medications, inspect full details, and edit stock records.',
              ),
              AppSpacing.heightMd,
              AppButton(
                text: 'Add Medication',
                onPressed: () => _openAddMedicationForm(),
              ),
              AppSpacing.heightSm,
              AppButton(
                text: 'Pending',
                isOutlined: true,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PendingItemsPage(),
                    ),
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
                  title: 'No Approved Medications',
                  message: _searchController.text.isEmpty
                      ? 'Approved medications will appear here after review.'
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
                  return MedicationListItem(
                    medication: medication,
                    onTap: () => _showMedicationDetails(medication),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
