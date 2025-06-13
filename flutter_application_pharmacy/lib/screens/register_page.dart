import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class RegisterPage extends StatefulWidget {
  final String medicationId;
  const RegisterPage({Key? key, this.medicationId = ''}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  String? _medicationType = 'Tablets'; // Default to 'Tablets'
  String? _drug,
      _strength,
      _batchNumber,
      _madeIn,
      _brandName; // Added _brandName for brand input

  double? _purchasedPrice, _sellingPrice;
  DateTime? _expirationDate;
  int? _quantity;
  bool _isLoading = false;

  String _strengthUnit = 'mg'; // Default to 'mg'
  String? _measurement = 'each'; // Default to 'each'

  String? _measurementDose;
  String _measurementDoseUnit = 'ML'; // Default unit is 'ML'

  final List<String> _medicationTypes = [
    'Tablets',
    'Injectable',
    'Cream',
    'Ointment',
    'Capsule',
    'Syrup',
    'Suspension',
    'Drop',
    'Reagent',
    'Medical Supplies',
    'Shampoo',
    'Gel',
    'Spray',
    'Sachet',
    'Pessary',
    'Cosmetics',
  ];

  final List<String> _strengthUnits = ['mg', 'g', 'ml', 'L', '%'];
  final List<String> _measurements = [
    'pack',
    'box',
    'each',
    'roll',
    'bag',
    'dozen',
    'tube',
    'amp',
    'bottle',
    'vial',
    'tin',
    'jar',
    'tab'
  ];

  final List<String> _measurementDoseUnits = ['BML', 'ML', '%'];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicationId.isEmpty
            ? 'Register Medication'
            : 'Update Medication'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0)),
            elevation: 10,
            shadowColor: Colors.deepPurpleAccent.withOpacity(0.4),
            color: Colors.deepPurple.shade50, // Light purple background
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildDropdownField(
                      value: _medicationType,
                      labelText: 'Medication Type',
                      icon: Icons.local_hospital,
                      items: _medicationTypes,
                      onChanged: (newValue) =>
                          setState(() => _medicationType = newValue),
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      labelText: 'Drug Name (must)',
                      onSave: (value) => _drug = value,
                      validator: (value) =>
                          value!.isEmpty ? 'Drug name is required' : null,
                    ),
                    _buildStrengthField(),
                    _buildMeasurementDoseField(),
                    _buildMeasurementDoseUnitField(),
                    _buildQuantityField(),
                    _buildTextFormField(
                      labelText: 'Purchased Price',
                      onSave: (value) =>
                          _purchasedPrice = double.tryParse(value!),
                      keyboardType: TextInputType.number,
                    ),
                    _buildTextFormField(
                      labelText: 'Selling Price',
                      onSave: (value) =>
                          _sellingPrice = double.tryParse(value!),
                      keyboardType: TextInputType.number,
                    ),
                    _buildExpirationDateField(), // Updated to add hint
                    _buildTextFormField(
                      labelText: 'Batch Number (must)',
                      onSave: (value) => _batchNumber = value,
                      validator: (value) =>
                          value!.isEmpty ? 'Batch number is required' : null,
                    ),
                    _buildTextFormField(
                      labelText: 'Made In',
                      onSave: (value) => _madeIn = value,
                    ),
                    _buildTextFormField(
                      labelText: 'Brand Name', // New Brand Name input field
                      onSave: (value) => _brandName = value,
                    ),
                    const SizedBox(height: 20),
                    _buildButtonRow(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.medical_services, color: Colors.deepPurple),
        const SizedBox(width: 10),
        Text(
          'Medication Details',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple),
        ),
      ],
    );
  }

  Widget _buildStrengthField() {
    return Row(
      children: [
        Expanded(
          child: _buildTextFormField(
            labelText: 'Strength (must)',
            onSave: (value) => _strength = value,
            validator: (value) =>
                value!.isEmpty ? 'Strength is required' : null,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDropdownField(
            value: _strengthUnit,
            labelText: 'Unit',
            icon: Icons.format_list_numbered,
            items: _strengthUnits,
            onChanged: (newValue) => setState(() => _strengthUnit = newValue!),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementDoseField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: 'Measurement Dose',
          border: OutlineInputBorder(),
        ),
        onSaved: (value) => _measurementDose = value,
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _buildMeasurementDoseUnitField() {
    return _buildDropdownField(
      value: _measurementDoseUnit,
      labelText: 'Measurement Dose Unit',
      icon: Icons.scale,
      items: _measurementDoseUnits,
      onChanged: (newValue) => setState(() => _measurementDoseUnit = newValue!),
    );
  }

  Widget _buildQuantityField() {
    return Row(
      children: [
        Expanded(
          child: _buildTextFormField(
            labelText: 'Quantity (must)',
            onSave: (value) => _quantity = int.tryParse(value!),
            validator: (value) =>
                value!.isEmpty ? 'Quantity is required' : null,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDropdownField(
            value: _measurement,
            labelText: 'Measurement',
            icon: Icons.scale,
            items: _measurements,
            onChanged: (newValue) => setState(() => _measurement = newValue),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String labelText,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: labelText,
        icon: Icon(icon),
        border: OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
            vertical: 10, horizontal: 12), // Adjusted padding
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select $labelText' : null,
    );
  }

  Widget _buildTextFormField({
    required String labelText,
    required FormFieldSetter<String> onSave,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Adjusted padding
      child: TextFormField(
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(),
        ),
        onSaved: onSave,
        validator: validator,
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildExpirationDateField() {
    return InkWell(
      onTap: _selectExpirationDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Expiration Date',
          border: OutlineInputBorder(),
        ),
        child: Text(
          _expirationDate == null
              ? 'Select date'
              : DateFormat.yMd().format(_expirationDate!),
          style: TextStyle(fontSize: 16, color: Colors.deepPurple),
        ),
      ),
    );
  }

  Future<void> _selectExpirationDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && pickedDate != _expirationDate)
      setState(() {
        _expirationDate = pickedDate;
      });
  }

  Widget _buildButtonRow() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _saveMedication,
          child: Text(
            widget.medicationId.isEmpty ? 'Register Medication' : 'Update',
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ],
    );
  }

  Future<void> _saveMedication() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      final medicationData = {
        'medicationType': _medicationType,
        'drug': _drug,
        'strength': _strength,
        'strengthUnit': _strengthUnit,
        'measurement': _measurement,
        'measurementDose': _measurementDose,
        'measurementDoseUnit': _measurementDoseUnit,
        'quantity': _quantity,
        'purchasedPrice': _purchasedPrice,
        'sellingPrice': _sellingPrice,
        'expirationDate': _expirationDate?.toIso8601String(),
        'batchNumber': _batchNumber,
        'madeIn': _madeIn,
        'brandName': _brandName,
        'status': 'pending',
      };

      // Save medication to Firebase
      if (widget.medicationId.isEmpty) {
        await _database.ref('medications').push().set(medicationData);
      } else {
        await _database
            .ref('medications/${widget.medicationId}')
            .update(medicationData);
      }

      setState(() => _isLoading = false);
      // Do not navigate back, keep the page open and show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.medicationId.isEmpty
                ? 'Medication Registered'
                : 'Medication Updated')),
      );
    }
  }
}
