import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../controllers/inventory_controller.dart';
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

          final pendingItems = _controller.medications.where((m) => m['status'] == 'pending').toList();

          if (pendingItems.isEmpty) {
            return const AppEmptyState(
              title: 'No Pending Items',
              message: 'All medications in the system are currently active or processed.',
              icon: Icons.check_circle_outline,
            );
          }

          return ListView.builder(
            padding: AppSpacing.pagePadding,
            itemCount: pendingItems.length,
            itemBuilder: (context, index) => MedicationListItem(medication: pendingItems[index]),
          );
        },
      ),
    );
  }
}
