import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../controllers/inventory_controller.dart';
import 'add_medication_page.dart';
import 'widgets/medication_details_sheet.dart';
import 'widgets/medication_list_item.dart';

class PendingItemsPage extends StatefulWidget {
  const PendingItemsPage({super.key});

  @override
  State<PendingItemsPage> createState() => _PendingItemsPageState();
}

class _PendingItemsPageState extends State<PendingItemsPage> {
  final _controller = InventoryController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _approveMedication(Map<String, dynamic> medication) async {
    Navigator.of(context).pop();
    final medicationId = medication['id']?.toString();
    if (medicationId == null || medicationId.isEmpty) {
      return;
    }

    final success = await _controller.approveMedication(medicationId);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Medication approved.' : 'Failed to approve medication.',
        ),
      ),
    );
  }

  Future<void> _rejectMedication(Map<String, dynamic> medication) async {
    Navigator.of(context).pop();
    final medicationId = medication['id']?.toString();
    if (medicationId == null || medicationId.isEmpty) {
      return;
    }

    final success = await _controller.rejectMedication(medicationId);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Medication rejected.' : 'Failed to reject medication.',
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

  void _showPendingDetails(Map<String, dynamic> medication) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MedicationDetailsSheet(
        medication: medication,
        onEdit: () => _editMedication(medication),
        onApprove: () => _approveMedication(medication),
        onReject: () => _rejectMedication(medication),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Items')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final pendingItems = _controller.medications
              .where(_controller.isPending)
              .toList();

          if (pendingItems.isEmpty) {
            return const AppEmptyState(
              title: 'No Pending Items',
              message: 'Every registered medication has already been reviewed.',
              icon: Icons.check_circle_outline,
            );
          }

          return ListView.builder(
            padding: AppSpacing.pagePadding,
            itemCount: pendingItems.length,
            itemBuilder: (context, index) => MedicationListItem(
              medication: pendingItems[index],
              onTap: () => _showPendingDetails(pendingItems[index]),
            ),
          );
        },
      ),
    );
  }
}
