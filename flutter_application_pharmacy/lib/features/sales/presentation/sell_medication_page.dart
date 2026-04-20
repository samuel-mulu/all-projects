import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../controllers/sell_medication_controller.dart';

class SellMedicationPage extends StatefulWidget {
  const SellMedicationPage({super.key});

  @override
  State<SellMedicationPage> createState() => _SellMedicationPageState();
}

class _SellMedicationPageState extends State<SellMedicationPage> {
  final _controller = SellMedicationController();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processSale() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_quantityController.text) ?? 0;
    
    // Additional validation: Stock check
    if (qty > (_controller.quantityAvailable ?? 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough stock available.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final success = await _controller.sellMedication(
      quantityToSell: qty,
      reason: _reasonController.text.trim(),
    );

    if (success && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Sale Recorded'),
          content: Text('${_controller.selectedMedication!['drug']} sold successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _quantityController.clear();
                _reasonController.clear();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else if (mounted && _controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.errorMessage!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return LoadingOverlay(
          isLoading: _controller.isProcessing,
          message: 'Processing transaction...',
          child: Scaffold(
            appBar: AppBar(title: const Text('Sell Medication')),
            body: ListView(
              padding: AppSpacing.pagePadding,
              children: [
                const SectionHeader(
                  title: 'Process Sale',
                  subtitle: 'Select an item and enter sale details.',
                ),
                AppSpacing.heightMd,
                if (_controller.selectedMedication == null) ...[
                  AppTextField(
                    label: 'Search',
                    hintText: 'Search by generic or brand name',
                    prefixIcon: const Icon(Icons.search),
                    onChanged: _controller.setSearchQuery,
                  ),
                  AppSpacing.heightMd,
                  if (_controller.isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (_controller.filteredMedications.isEmpty)
                    const AppEmptyState(
                      title: 'No Items Found',
                      message: 'No active medications match your search.',
                      icon: Icons.search_off,
                    )
                  else
                    ..._controller.filteredMedications.map((med) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => _controller.selectMedication(med),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.medication, color: AppColors.primary),
                            ),
                            title: Text(med['drug'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${med['brandName'] ?? 'No Brand'} • Stock: ${med['quantity']} ${med['measurement']}'),
                            trailing: const Icon(Icons.add_shopping_cart, color: AppColors.primary),
                          ),
                        ),
                      );
                    }),
                ] else ...[
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_controller.selectedMedication!['drug'], style: Theme.of(context).textTheme.titleLarge),
                                    Text(_controller.selectedMedication!['brandName'] ?? 'No Brand', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _controller.clearSelection,
                                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          AppSpacing.heightMd,
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.primary),
                                AppSpacing.widthSm,
                                Text(
                                  'Stock: ${_controller.quantityAvailable} ${_controller.selectedMedication!['measurement']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.heightLg,
                          AppTextField(
                            controller: _quantityController,
                            label: 'Quantity to Sell',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final qty = int.tryParse(v);
                              if (qty == null || qty <= 0) return 'Enter a valid quantity';
                              return null;
                            },
                          ),
                          AppSpacing.heightSm,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Payment Method', style: Theme.of(context).textTheme.labelLarge),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _controller.paymentMethod,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                items: const [
                                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                  DropdownMenuItem(value: 'Mobile Banking', child: Text('Mobile Banking')),
                                  DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                                ],
                                onChanged: (v) => _controller.setPaymentMethod(v!),
                              ),
                            ],
                          ),
                          if (_controller.paymentMethod == 'Credit') ...[
                            AppSpacing.heightSm,
                            AppTextField(
                              controller: _reasonController,
                              label: 'Reason for Credit',
                              maxLines: 2,
                              validator: (v) => _controller.paymentMethod == 'Credit' && (v == null || v.isEmpty) ? 'Required for credit' : null,
                            ),
                          ],
                          AppSpacing.heightLg,
                          AppButton(
                            text: 'Record Transaction',
                            onPressed: _processSale,
                            isLoading: _controller.isProcessing,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
