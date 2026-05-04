import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/medication_status.dart';
import '../../../core/utils/sale_pricing.dart';
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
    this.initialBatchMedications = const [],
    this.showScaffold = true,
    this.autoCloseOnSuccess = false,
    this.showSheetChrome = true,
  });

  final Map<String, dynamic>? initialMedication;
  final List<Map<String, dynamic>> initialBatchMedications;
  final bool showScaffold;
  final bool autoCloseOnSuccess;
  final bool showSheetChrome;

  @override
  State<SellMedicationPage> createState() => _SellMedicationPageState();
}

class _SellMedicationPageState extends State<SellMedicationPage> {
  late final SellMedicationController _controller;
  final _quantityController = TextEditingController();
  final _priceAdjustmentController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<_CartSaleItem> _batchItems = [];
  SalePriceAdjustmentType _priceAdjustmentType = SalePriceAdjustmentType.none;

  @override
  void initState() {
    super.initState();
    _controller = SellMedicationController(
      initialMedication: widget.initialMedication,
    );
    _seedInitialBatchItems();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceAdjustmentController.dispose();
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

  void _seedInitialBatchItems() {
    if (widget.initialBatchMedications.isEmpty || _batchItems.isNotEmpty) {
      return;
    }

    final seenIds = <String>{};
    for (final medication in widget.initialBatchMedications) {
      final medicationId = (medication['id'] ?? '').toString();
      if (medicationId.isEmpty || seenIds.contains(medicationId)) {
        continue;
      }

      seenIds.add(medicationId);
      _batchItems.add(
        _CartSaleItem(
          medication: medication,
          quantity: 1,
          priceAdjustmentType: SalePriceAdjustmentType.none,
          priceAdjustmentAmount: 0,
        ),
      );
    }
  }

  double _selectedBaseUnitPrice() {
    return salePricingToDouble(_controller.selectedMedication?['sellingPrice']);
  }

  double _currentPriceAdjustmentAmount() {
    return salePricingToDouble(_priceAdjustmentController.text.trim());
  }

  SalePriceAdjustmentType _effectivePriceAdjustmentType() {
    final adjustmentAmount = _currentPriceAdjustmentAmount();
    return hasMeaningfulSaleAdjustment(
      adjustmentType: _priceAdjustmentType,
      adjustmentAmount: adjustmentAmount,
    )
        ? _priceAdjustmentType
        : SalePriceAdjustmentType.none;
  }

  double _effectivePriceAdjustmentAmount() {
    return _effectivePriceAdjustmentType().hasAdjustment
        ? normalizeSaleAdjustmentAmount(_currentPriceAdjustmentAmount())
        : 0.0;
  }

  double _currentFinalUnitPrice() {
    return calculateSaleUnitPrice(
      baseUnitPrice: _selectedBaseUnitPrice(),
      adjustmentType: _effectivePriceAdjustmentType(),
      adjustmentAmount: _effectivePriceAdjustmentAmount(),
    );
  }

  void _resetPricingInputs() {
    _priceAdjustmentType = SalePriceAdjustmentType.none;
    _priceAdjustmentController.clear();
  }

  Future<void> _selectMedication(Map<String, dynamic> medication) async {
    setState(_resetPricingInputs);
    await _controller.selectMedication(medication);
  }

  void _clearCurrentSelection() {
    setState(_resetPricingInputs);
    _controller.clearSelection();
  }

  int _availableForBatchItem(int index) {
    final item = _batchItems[index];
    final medicationId = (item.medication['id'] ?? '').toString();
    final stock = parseMedicationQuantity(item.medication);

    var reservedByOthers = 0;
    for (var i = 0; i < _batchItems.length; i++) {
      if (i == index) {
        continue;
      }

      final otherId = (_batchItems[i].medication['id'] ?? '').toString();
      if (otherId == medicationId) {
        reservedByOthers += _batchItems[i].quantity;
      }
    }

    return stock - reservedByOthers;
  }

  String _buildBatchItemSubtitle(_CartSaleItem item) {
    final baseUnitPrice = salePricingToDouble(item.medication['sellingPrice']);
    final finalUnitPrice = calculateSaleUnitPrice(
      baseUnitPrice: baseUnitPrice,
      adjustmentType: item.priceAdjustmentType,
      adjustmentAmount: item.priceAdjustmentAmount,
    );

    final details = <String>[
      'Qty: ${item.quantity}',
      'Unit: ${finalUnitPrice.toStringAsFixed(2)} Birr',
    ];

    if (hasMeaningfulSaleAdjustment(
      adjustmentType: item.priceAdjustmentType,
      adjustmentAmount: item.priceAdjustmentAmount,
    )) {
      details.add(
        '${item.priceAdjustmentType.label}: '
        '${item.priceAdjustmentAmount.toStringAsFixed(2)}',
      );
    }

    return details.join(' | ');
  }

  Widget _buildSpecialPricingSection(BuildContext context) {
    final baseUnitPrice = _selectedBaseUnitPrice();
    final enteredAdjustmentAmount = _currentPriceAdjustmentAmount();
    final finalUnitPrice = calculateSaleUnitPrice(
      baseUnitPrice: baseUnitPrice,
      adjustmentType: _priceAdjustmentType,
      adjustmentAmount: enteredAdjustmentAmount,
    );
    final effectiveAdjustmentType = _effectivePriceAdjustmentType();
    final effectiveAdjustmentAmount = _effectivePriceAdjustmentAmount();
    final estimatedQuantity =
        int.tryParse(_quantityController.text.trim()) ?? 0;
    final estimatedTotal = estimatedQuantity > 0
        ? _currentFinalUnitPrice() * estimatedQuantity
        : 0.0;
    final hasInvalidDiscount =
        _priceAdjustmentType == SalePriceAdjustmentType.discount &&
            enteredAdjustmentAmount > baseUnitPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Special Pricing',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Optional discount or addition for this sale only.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SalePriceAdjustmentType.values.map((type) {
            final isSelected = _priceAdjustmentType == type;
            final label = type == SalePriceAdjustmentType.none
                ? 'Default Price'
                : type.label;
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _priceAdjustmentType = type;
                  if (type == SalePriceAdjustmentType.none) {
                    _priceAdjustmentController.clear();
                  }
                });
              },
            );
          }).toList(),
        ),
        if (_priceAdjustmentType.hasAdjustment) ...[
          AppSpacing.heightSm,
          AppTextField(
            controller: _priceAdjustmentController,
            label: '${_priceAdjustmentType.label} Amount Per Unit',
            hintText: 'e.g. 20',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              if (!_priceAdjustmentType.hasAdjustment) {
                return null;
              }

              final parsed = double.tryParse((value ?? '').trim());
              if (parsed == null || parsed <= 0) {
                return 'Enter a valid amount';
              }

              if (_priceAdjustmentType == SalePriceAdjustmentType.discount &&
                  finalUnitPrice < 0) {
                return 'Discount is larger than the base price';
              }

              return null;
            },
          ),
        ],
        AppSpacing.heightSm,
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PricingSummaryRow(
                label: 'Base Unit Price',
                value: '${baseUnitPrice.toStringAsFixed(2)} Birr',
              ),
              if (hasMeaningfulSaleAdjustment(
                adjustmentType: effectiveAdjustmentType,
                adjustmentAmount: effectiveAdjustmentAmount,
              ))
                _PricingSummaryRow(
                  label: effectiveAdjustmentType.label,
                  value:
                      '${effectiveAdjustmentAmount.toStringAsFixed(2)} Birr / unit',
                ),
              _PricingSummaryRow(
                label: 'Final Unit Price',
                value: '${_currentFinalUnitPrice().toStringAsFixed(2)} Birr',
                valueColor: hasInvalidDiscount ? AppColors.error : null,
              ),
              if (estimatedQuantity > 0)
                _PricingSummaryRow(
                  label: 'Estimated Total',
                  value: '${estimatedTotal.toStringAsFixed(2)} Birr',
                ),
              if (hasInvalidDiscount) ...[
                AppSpacing.heightXs,
                Text(
                  'The discount is larger than the base unit price.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showBatchItemEditor(int index) async {
    final item = _batchItems[index];
    final quantityController =
        TextEditingController(text: item.quantity.toString());
    final adjustmentController = TextEditingController(
      text: item.priceAdjustmentAmount > 0
          ? item.priceAdjustmentAmount.toStringAsFixed(2)
          : '',
    );
    final formKey = GlobalKey<FormState>();
    var adjustmentType = item.priceAdjustmentType;

    final availableForItem = _availableForBatchItem(index);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final adjustmentAmount =
              salePricingToDouble(adjustmentController.text.trim());
          final previewUnitPrice = calculateSaleUnitPrice(
            baseUnitPrice: salePricingToDouble(item.medication['sellingPrice']),
            adjustmentType: adjustmentType,
            adjustmentAmount: adjustmentAmount,
          );

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      SectionHeader(
                        title: 'Edit Batch Item',
                        subtitle: (item.medication['drug'] ?? 'Medication')
                            .toString(),
                      ),
                      AppSpacing.heightMd,
                      AppTextField(
                        controller: quantityController,
                        label: 'Quantity',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final qty = int.tryParse((value ?? '').trim());
                          if (qty == null || qty <= 0) {
                            return 'Enter a valid quantity';
                          }
                          if (qty > availableForItem) {
                            return 'Only $availableForItem item(s) available';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.heightSm,
                      Text(
                        'Price Adjustment',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SalePriceAdjustmentType.values.map((type) {
                          return ChoiceChip(
                            label: Text(
                              type == SalePriceAdjustmentType.none
                                  ? 'Default Price'
                                  : type.label,
                            ),
                            selected: adjustmentType == type,
                            onSelected: (_) {
                              setModalState(() {
                                adjustmentType = type;
                                if (type == SalePriceAdjustmentType.none) {
                                  adjustmentController.clear();
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      if (adjustmentType.hasAdjustment) ...[
                        AppSpacing.heightSm,
                        AppTextField(
                          controller: adjustmentController,
                          label: '${adjustmentType.label} Amount Per Unit',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (value) {
                            if (!adjustmentType.hasAdjustment) {
                              return null;
                            }
                            final parsed =
                                double.tryParse((value ?? '').trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid amount';
                            }
                            if (adjustmentType ==
                                    SalePriceAdjustmentType.discount &&
                                previewUnitPrice < 0) {
                              return 'Discount is larger than the base price';
                            }
                            return null;
                          },
                        ),
                      ],
                      AppSpacing.heightSm,
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _PricingSummaryRow(
                          label: 'Preview Unit Price',
                          value: '${previewUnitPrice.toStringAsFixed(2)} Birr',
                          valueColor: previewUnitPrice < 0
                              ? AppColors.error
                              : AppColors.primaryDark,
                        ),
                      ),
                      AppSpacing.heightLg,
                      FilledButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          Navigator.of(context).pop(true);
                        },
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _batchItems[index] = item.copyWith(
          quantity:
              int.tryParse(quantityController.text.trim()) ?? item.quantity,
          priceAdjustmentType: hasMeaningfulSaleAdjustment(
            adjustmentType: adjustmentType,
            adjustmentAmount:
                salePricingToDouble(adjustmentController.text.trim()),
          )
              ? adjustmentType
              : SalePriceAdjustmentType.none,
          priceAdjustmentAmount: adjustmentType.hasAdjustment
              ? salePricingToDouble(adjustmentController.text.trim())
              : 0.0,
        );
      });
    }

    quantityController.dispose();
    adjustmentController.dispose();
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
      _batchItems.add(
        _CartSaleItem(
          medication: selectedMedication,
          quantity: qty,
          priceAdjustmentType: _effectivePriceAdjustmentType(),
          priceAdjustmentAmount: _effectivePriceAdjustmentAmount(),
        ),
      );
      _resetPricingInputs();
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
        priceAdjustmentType: item.priceAdjustmentType,
        priceAdjustmentAmount: item.priceAdjustmentAmount,
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
      _resetPricingInputs();
    });
    _quantityController.clear();
    _reasonController.clear();
    if (!_controller.hasLockedMedication) {
      _controller.clearSelection();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Recorded $successCount sale item(s) successfully.')),
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
      priceAdjustmentType: _effectivePriceAdjustmentType(),
      priceAdjustmentAmount: _effectivePriceAdjustmentAmount(),
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
              setState(_resetPricingInputs);
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
                if (!widget.showScaffold && widget.showSheetChrome) ...[
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
                  subtitle: widget.initialMedication != null
                      ? 'Complete the sale for the selected medication.'
                      : widget.initialBatchMedications.isNotEmpty
                          ? 'Review the selected medicines and complete one batch sale.'
                          : 'Select medicines and record one or multiple sales.',
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
                            onTap: () => _showBatchItemEditor(index),
                            title: Text(
                              (item.medication['drug'] ?? 'Medication')
                                  .toString(),
                            ),
                            subtitle: Text(_buildBatchItemSubtitle(item)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.primary,
                                  ),
                                  onPressed: () => _showBatchItemEditor(index),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
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
                              ],
                            ),
                          );
                        }),
                        AppSpacing.heightSm,
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                text: 'Clear Batch',
                                onPressed: () {
                                  setState(() {
                                    _batchItems.clear();
                                  });
                                },
                                isOutlined: true,
                              ),
                            ),
                            AppSpacing.widthSm,
                            Expanded(
                              child: AppButton(
                                text: 'Record Batch Sale',
                                onPressed: _recordBatchSale,
                                isLoading: _controller.isProcessing,
                              ),
                            ),
                          ],
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
                          onTap: () => _selectMedication(medication),
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${medication['brandName'] ?? 'No Brand'} - ${medication['strength'] ?? ''} ${medication['strengthUnit'] ?? ''} - Stock: '
                              '${medication['quantity']} ${medication['measurement']}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Select for sale',
                              onPressed: () => _selectMedication(medication),
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                color: AppColors.primary,
                              ),
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
                                      (_controller.selectedMedication![
                                                  'drug'] ??
                                              '')
                                          .toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    Text(
                                      (_controller.selectedMedication![
                                                  'brandName'] ??
                                              'No Brand')
                                          .toString(),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (!_controller.hasLockedMedication)
                                IconButton(
                                  onPressed: _clearCurrentSelection,
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
                          if (!widget.autoCloseOnSuccess &&
                              !widget.showScaffold)
                            AppSpacing.heightSm,
                          if (!widget.autoCloseOnSuccess &&
                              !widget.showScaffold)
                            Text(
                              'Remaining after batch: ${_availableAfterBatchSelection()}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          AppSpacing.heightLg,
                          AppTextField(
                            controller: _quantityController,
                            label: 'Quantity to Sell',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
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
                          _buildSpecialPricingSection(context),
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
                          if (!widget.autoCloseOnSuccess &&
                              !widget.showScaffold) ...[
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

    if (!widget.showScaffold && widget.showSheetChrome) {
      return SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: content,
        ),
      );
    }

    if (!widget.showScaffold) {
      return content;
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
    required this.priceAdjustmentType,
    required this.priceAdjustmentAmount,
  });

  final Map<String, dynamic> medication;
  final int quantity;
  final SalePriceAdjustmentType priceAdjustmentType;
  final double priceAdjustmentAmount;

  _CartSaleItem copyWith({
    Map<String, dynamic>? medication,
    int? quantity,
    SalePriceAdjustmentType? priceAdjustmentType,
    double? priceAdjustmentAmount,
  }) {
    return _CartSaleItem(
      medication: medication ?? this.medication,
      quantity: quantity ?? this.quantity,
      priceAdjustmentType: priceAdjustmentType ?? this.priceAdjustmentType,
      priceAdjustmentAmount:
          priceAdjustmentAmount ?? this.priceAdjustmentAmount,
    );
  }
}

class _PricingSummaryRow extends StatelessWidget {
  const _PricingSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
