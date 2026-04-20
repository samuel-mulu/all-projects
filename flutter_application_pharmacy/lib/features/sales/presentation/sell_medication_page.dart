import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/section_header.dart';
import '../controllers/sell_medication_controller.dart';

class SellMedicationPage extends StatefulWidget {
  const SellMedicationPage({
    super.key,
    this.initialMedication,
    this.showScaffold = true,
    this.autoCloseOnSuccess = false,
  });

  final Map<String, dynamic>? initialMedication;
  final bool showScaffold;
  final bool autoCloseOnSuccess;

  @override
  State<SellMedicationPage> createState() => _SellMedicationPageState();
}

class _SellMedicationPageState extends State<SellMedicationPage> {
  late final SellMedicationController _controller;
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<_CartSaleItem> _batchItems = [];

  @override
  void initState() {
    super.initState();
    _controller = SellMedicationController(
      initialMedication: widget.initialMedication,
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _controller.dispose();
    super.dispose();
  }

  int _selectedMedicationCartQty() {
    final id = (_controller.selectedMedication?['id'] ?? '').toString();
    if (id.isEmpty) {
      return 0;
    }
    var total = 0;
    for (final item in _batchItems) {
      final itemId = (item.medication['id'] ?? '').toString();
      if (itemId == id) {
        total += item.quantity;
      }
    }
    return total;
  }

  int _availableAfterBatchSelection() {
    final available = _controller.quantityAvailable ?? 0;
    return available - _selectedMedicationCartQty();
  }

  void _addSelectedToBatch() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedMedication = _controller.selectedMedication;
    if (selectedMedication == null) {
      return;
    }

    final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    final remainingForSelected = _availableAfterBatchSelection();
    if (qty <= 0 || qty > remainingForSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough stock for this quantity.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _batchItems.add(_CartSaleItem(medication: selectedMedication, quantity: qty));
    });
    _quantityController.clear();
    if (!_controller.hasLockedMedication) {
      _controller.clearSelection();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item added to batch sale.')),
    );
  }

  Future<void> _recordBatchSale() async {
    if (_batchItems.isEmpty) {
      return;
    }
    if (_controller.paymentMethod == 'Credit' &&
        _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reason is required for credit sales.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    var successCount = 0;
    for (final item in _batchItems) {
      await _controller.selectMedication(item.medication);
      final success = await _controller.sellMedication(
        quantityToSell: item.quantity,
        reason: _reasonController.text.trim(),
      );
      if (!success) {
        if (!mounted) {
          return;
        }
        final message =
            _controller.errorMessage ?? 'Batch sale failed on one item.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      successCount += 1;
    }

    if (!mounted) {
      return;
    }

    if (widget.autoCloseOnSuccess) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _batchItems.clear();
    });
    _quantityController.clear();
    _reasonController.clear();
    if (!_controller.hasLockedMedication) {
      _controller.clearSelection();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recorded $successCount sale item(s) successfully.')),
    );
  }

  Future<void> _processSale() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final qty = int.tryParse(_quantityController.text) ?? 0;
    final remainingForSelected = _availableAfterBatchSelection();
    if (qty > remainingForSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough stock available.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await _controller.sellMedication(
      quantityToSell: qty,
      reason: _reasonController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      if (_controller.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_controller.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (widget.autoCloseOnSuccess) {
      Navigator.of(context).pop(true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Sale Recorded'),
        content: Text(
          '${_controller.selectedMedication!['drug']} sold successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _quantityController.clear();
              _reasonController.clear();
              if (!_controller.hasLockedMedication) {
                _controller.clearSelection();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return LoadingOverlay(
          isLoading: _controller.isProcessing,
          message: 'Processing transaction...',
          child: Material(
            color: widget.showScaffold
                ? Colors.transparent
                : Theme.of(context).scaffoldBackgroundColor,
            child: ListView(
              padding: AppSpacing.pagePadding,
              children: [
                if (!widget.showScaffold) ...[
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  AppSpacing.heightMd,
                ],
                SectionHeader(
                  title: 'Process Sale',
                  subtitle: widget.initialMedication == null
                      ? 'Select medicines and record one or multiple sales.'
                      : 'Complete the sale for the selected medication.',
                ),
                AppSpacing.heightMd,
                if (_batchItems.isNotEmpty) ...[
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Items (${_batchItems.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        AppSpacing.heightSm,
                        ..._batchItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              (item.medication['drug'] ?? 'Medication')
                                  .toString(),
                            ),
                            subtitle: Text('Qty: ${item.quantity}'),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: () {
                                setState(() {
                                  _batchItems.removeAt(index);
                                });
                              },
                            ),
                          );
                        }),
                        AppSpacing.heightSm,
                        AppButton(
                          text: 'Record Batch Sale',
                          onPressed: _recordBatchSale,
                          isLoading: _controller.isProcessing,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.heightMd,
                ],
                if (_controller.selectedMedication == null) ...[
                  AppTextField(
                    label: 'Search',
                    hintText: 'Search by generic or brand name',
                    prefixIcon: const Icon(Icons.search),
                    onChanged: _controller.setSearchQuery,
                  ),
                  AppSpacing.heightMd,
                  if (_controller.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_controller.filteredMedications.isEmpty)
                    const AppEmptyState(
                      title: 'No Items Found',
                      message: 'No approved medications match your search.',
                      icon: Icons.search_off,
                    )
                  else
                    ..._controller.filteredMedications.map((medication) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => _controller.selectMedication(medication),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: const Icon(
                                Icons.medication,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              (medication['drug'] ?? '').toString(),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${medication['brandName'] ?? 'No Brand'} - Stock: '
                              '${medication['quantity']} ${medication['measurement']}',
                            ),
                            trailing: const Icon(
                              Icons.add_shopping_cart,
                              color: AppColors.primary,
                            ),
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
                                    Text(
                                      (_controller.selectedMedication!['drug'] ?? '')
                                          .toString(),
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    Text(
                                      (_controller.selectedMedication!['brandName'] ??
                                              'No Brand')
                                          .toString(),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (!_controller.hasLockedMedication)
                                IconButton(
                                  onPressed: _controller.clearSelection,
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.textSecondary,
                                  ),
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
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                AppSpacing.widthSm,
                                Text(
                                  'Stock: ${_controller.quantityAvailable} '
                                  '${_controller.selectedMedication!['measurement']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!widget.autoCloseOnSuccess && !widget.showScaffold)
                            AppSpacing.heightSm,
                          if (!widget.autoCloseOnSuccess && !widget.showScaffold)
                            Text(
                              'Remaining after batch: ${_availableAfterBatchSelection()}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          AppSpacing.heightLg,
                          AppTextField(
                            controller: _quantityController,
                            label: 'Quantity to Sell',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }

                              final qty = int.tryParse(value);
                              if (qty == null || qty <= 0) {
                                return 'Enter a valid quantity';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.heightSm,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Method',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                key: ValueKey(_controller.paymentMethod),
                                initialValue: _controller.paymentMethod,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Cash',
                                    child: Text('Cash'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Mobile Banking',
                                    child: Text('Mobile Banking'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Credit',
                                    child: Text('Credit'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    _controller.setPaymentMethod(value);
                                  }
                                },
                              ),
                            ],
                          ),
                          if (_controller.paymentMethod == 'Credit') ...[
                            AppSpacing.heightSm,
                            AppTextField(
                              controller: _reasonController,
                              label: 'Reason for Credit',
                              maxLines: 2,
                              validator: (value) {
                                if (_controller.paymentMethod == 'Credit' &&
                                    (value == null || value.isEmpty)) {
                                  return 'Required for credit';
                                }
                                return null;
                              },
                            ),
                          ],
                          AppSpacing.heightLg,
                          if (!widget.autoCloseOnSuccess && !widget.showScaffold) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    text: 'Add To Batch',
                                    isOutlined: true,
                                    onPressed: _addSelectedToBatch,
                                  ),
                                ),
                                AppSpacing.widthSm,
                                Expanded(
                                  child: AppButton(
                                    text: 'Record Now',
                                    onPressed: _processSale,
                                    isLoading: _controller.isProcessing,
                                  ),
                                ),
                              ],
                            ),
                          ] else
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

    if (!widget.showScaffold) {
      return SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: content,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sell Medication')),
      body: content,
    );
  }
}

class _CartSaleItem {
  const _CartSaleItem({
    required this.medication,
    required this.quantity,
  });

  final Map<String, dynamic> medication;
  final int quantity;
}
