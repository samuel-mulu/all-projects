import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../controllers/medication_form_controller.dart';

class AddMedicationPage extends StatefulWidget {
  final String? medicationId;
  const AddMedicationPage({super.key, this.medicationId});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = MedicationFormController();

  final _drugController = TextEditingController();
  final _strengthController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasedPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _madeInController = TextEditingController();

  String _medicationType = 'Tablets';
  String _strengthUnit = 'mg';
  String _measurement = 'each';
  String _status = 'pending';
  DateTime? _expirationDate;

  final List<String> _types = const ['Tablets', 'Syrup', 'Injectable', 'Cream', 'Capsule', 'Ointment', 'Drop', 'Medical Supplies', 'Cosmetics', 'Suppasitory'];
  final List<String> _measurements = const ['each', 'box', 'pack', 'bottle', 'vial', 'amp', 'tube'];
  final List<String> _strengthUnits = const ['mg', 'g', 'ml', 'L', '%'];

  @override
  void initState() {
    super.initState();
    if (widget.medicationId != null) {
      _loadMedication();
    }
  }

  @override
  void dispose() {
    _drugController.dispose();
    _strengthController.dispose();
    _quantityController.dispose();
    _purchasedPriceController.dispose();
    _sellingPriceController.dispose();
    _batchNumberController.dispose();
    _brandNameController.dispose();
    _madeInController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMedication() async {
    final data = await _controller.loadMedication(widget.medicationId!);
    if (data != null && mounted) {
      setState(() {
        _drugController.text = data['drug']?.toString() ?? '';
        _strengthController.text = data['strength']?.toString() ?? '';
        _quantityController.text = data['quantity']?.toString() ?? '';
        _purchasedPriceController.text = data['purchasedPrice']?.toString() ?? '';
        _sellingPriceController.text = data['sellingPrice']?.toString() ?? '';
        _batchNumberController.text = data['batchNumber']?.toString() ?? '';
        _brandNameController.text = data['brandName']?.toString() ?? '';
        _madeInController.text = data['madeIn']?.toString() ?? '';
        _medicationType = data['medicationType']?.toString() ?? _medicationType;
        _strengthUnit = data['strengthUnit']?.toString() ?? _strengthUnit;
        _measurement = data['measurement']?.toString() ?? _measurement;
        _status = data['status']?.toString() ?? _status;
        if (data['expirationDate'] != null) {
          _expirationDate = DateTime.tryParse(data['expirationDate']);
        }
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expirationDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _controller.saveMedication(
      id: widget.medicationId,
      data: {
        'drug': _drugController.text.trim(),
        'medicationType': _medicationType,
        'brandName': _brandNameController.text.trim(),
        'strength': _strengthController.text.trim(),
        'strengthUnit': _strengthUnit,
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 0,
        'measurement': _measurement,
        'purchasedPrice': double.tryParse(_purchasedPriceController.text.trim()) ?? 0.0,
        'sellingPrice': double.tryParse(_sellingPriceController.text.trim()) ?? 0.0,
        'batchNumber': _batchNumberController.text.trim(),
        'madeIn': _madeInController.text.trim(),
        'expirationDate': _expirationDate?.toIso8601String(),
        'status': widget.medicationId == null ? 'pending' : _status,
      },
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.medicationId == null ? 'Medication added' : 'Medication updated')),
      );
      Navigator.pop(context);
    } else if (mounted && _controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.errorMessage!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _controller.isLoading && widget.medicationId != null && _drugController.text.isNotEmpty,
      message: 'Saving medication...',
      child: Scaffold(
        appBar: AppBar(title: Text(widget.medicationId == null ? 'Add Medication' : 'Edit Medication')),
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.isLoading && widget.medicationId != null && _drugController.text.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.pagePadding,
                children: [
                  _buildSection(
                    title: 'Basic Information',
                    children: [
                      AppTextField(
                        controller: _drugController,
                        label: 'Generic Name',
                        hintText: 'e.g. Paracetamol',
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      AppSpacing.heightSm,
                      AppTextField(controller: _brandNameController, label: 'Brand Name', hintText: 'Optional'),
                      AppSpacing.heightSm,
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: 'Type',
                              value: _medicationType,
                              items: _dropdownOptions(_types, _medicationType),
                              onChanged: (v) => setState(() => _medicationType = v!),
                            ),
                          ),
                          AppSpacing.widthSm,
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: _strengthController,
                                    label: 'Strength',
                                    keyboardType: TextInputType.number,
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                ),
                                AppSpacing.widthXs,
                                SizedBox(
                                  width: 75,
                                  child: _buildDropdown(
                                    label: 'Unit',
                                    value: _strengthUnit,
                                    items: _dropdownOptions(_strengthUnits, _strengthUnit),
                                    onChanged: (v) => setState(() => _strengthUnit = v!),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  AppSpacing.heightMd,
                  _buildSection(
                    title: 'Stock & Pricing',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _quantityController,
                              label: 'Stock Quantity',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (int.tryParse(v) == null) return 'Invalid number';
                                return null;
                              },
                            ),
                          ),
                          AppSpacing.widthSm,
                          Expanded(
                            child: _buildDropdown(
                              label: 'Measurement',
                              value: _measurement,
                              items: _dropdownOptions(_measurements, _measurement),
                              onChanged: (v) => setState(() => _measurement = v!),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.heightSm,
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _purchasedPriceController,
                              label: 'Purchase Price (Birr)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          AppSpacing.widthSm,
                          Expanded(
                            child: AppTextField(
                              controller: _sellingPriceController,
                              label: 'Selling Price (Birr)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  AppSpacing.heightMd,
                  _buildSection(
                    title: 'Additional Details',
                    children: [
                      AppTextField(
                        controller: _batchNumberController,
                        label: 'Batch Number',
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      AppSpacing.heightSm,
                      AppTextField(
                        label: 'Expiry Date',
                        hintText: _expirationDate == null
                            ? 'Select Date'
                            : DateFormat('yyyy-MM-dd').format(_expirationDate!),
                        prefixIcon: const Icon(Icons.calendar_today),
                        readOnly: true,
                        onTap: _selectDate,
                      ),
                      AppSpacing.heightSm,
                      AppTextField(controller: _madeInController, label: 'Origin / Made In', hintText: 'Optional'),
                    ],
                  ),
                  AppSpacing.heightXl,
                  AppButton(
                    text: widget.medicationId == null ? 'Add Medication' : 'Save Changes',
                    onPressed: _save,
                    isLoading: _controller.isLoading,
                  ),
                  AppSpacing.heightMd,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
          AppSpacing.heightMd,
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<String> _dropdownOptions(List<String> defaults, String currentValue) {
    final options = <String>[
      ...defaults,
      if (currentValue.isNotEmpty && !defaults.contains(currentValue)) currentValue,
    ];
    return options;
  }
}
