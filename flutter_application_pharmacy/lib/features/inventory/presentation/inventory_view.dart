import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../services/pdf_export_service.dart';
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
  final _pdfExportService = const PdfExportService();
  String? _handledMedicationId;
  bool _isExportingPdf = false;

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

  Future<void> _openPendingPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PendingItemsPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _controller.loadData();
  }

  Future<void> _exportInventoryPdf() async {
    if (_isExportingPdf) {
      return;
    }

    setState(() => _isExportingPdf = true);
    try {
      await _pdfExportService.exportInventoryPdf(
        title: 'Inventory Report',
        medications: _controller.filteredMedications,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory PDF is ready.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export inventory PDF.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
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
                title: 'Inventory Control',
                subtitle:
                    'Review stock, scan pricing, and export a clean inventory table.',
              ),
              AppSpacing.heightMd,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionPill(
                    icon: Icons.add_box_outlined,
                    label: 'Add Medication',
                    onPressed: () => _openAddMedicationForm(),
                    filled: true,
                  ),
                  _ActionPill(
                    icon: Icons.picture_as_pdf_outlined,
                    label: _isExportingPdf ? 'Preparing PDF...' : 'Export PDF',
                    onPressed: _isExportingPdf ? null : _exportInventoryPdf,
                  ),
                  _ActionPill(
                    icon: Icons.pending_actions_outlined,
                    label: 'Pending (${_controller.pendingCount})',
                    onPressed: _openPendingPage,
                  ),
                ],
              ),
              AppSpacing.heightMd,
              AppCard(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Medication Browser',
                      subtitle:
                          'Search quickly, change sort order, and keep the list easy to scan.',
                    ),
                    AppSpacing.heightMd,
                    AppTextField(
                      controller: _searchController,
                      label: 'Search',
                      hintText: 'Search by drug or brand name',
                      prefixIcon: const Icon(Icons.search),
                      onChanged: _controller.setSearchQuery,
                    ),
                    AppSpacing.heightSm,
                    DropdownButtonFormField<String>(
                      initialValue: _controller.selectedSort,
                      decoration: const InputDecoration(
                        labelText: 'Sort By',
                      ),
                      items:
                          InventoryController.sortOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _controller.setSort(value);
                        }
                      },
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
                  ],
                ),
              ),
              AppSpacing.heightMd,
              Text(
                'Showing ${_controller.filteredMedications.length} medication(s)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              AppSpacing.heightSm,
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
                    showPurchasePrice: false,
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : AppColors.primary;
    final background = filled ? AppColors.primary : AppColors.surface;

    return SizedBox(
      height: 40,
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: filled ? null : const BorderSide(color: AppColors.border),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
