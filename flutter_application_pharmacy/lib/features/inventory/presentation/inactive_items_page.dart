import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../controllers/inventory_controller.dart';
import 'widgets/medication_list_item.dart';

class InactiveItemsPage extends StatefulWidget {
  const InactiveItemsPage({super.key});

  @override
  State<InactiveItemsPage> createState() => _InactiveItemsPageState();
}

class _InactiveItemsPageState extends State<InactiveItemsPage> {
  final _controller = InventoryController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inactive Items')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final inactiveItems = _controller.medications.where((m) => m['status'] == 'inactive').toList();

          if (inactiveItems.isEmpty) {
            return const AppEmptyState(
              title: 'No Inactive Items',
              message: 'There are no medications marked as inactive in the system.',
              icon: Icons.archive_outlined,
            );
          }

          return ListView.builder(
            padding: AppSpacing.pagePadding,
            itemCount: inactiveItems.length,
            itemBuilder: (context, index) => MedicationListItem(medication: inactiveItems[index]),
          );
        },
      ),
    );
  }
}
