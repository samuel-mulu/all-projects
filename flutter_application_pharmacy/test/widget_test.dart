import 'package:flutter/material.dart';
import 'package:flutter_application_pharmacy/features/inventory/presentation/widgets/medication_details_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('medication details sheet shows record actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MedicationDetailsSheet(
            medication: const {
              'id': 'med-1',
              'drug': 'Paracetamol',
              'brandName': 'Panadol',
              'medicationType': 'Tablets',
              'strength': '500',
              'strengthUnit': 'mg',
              'quantity': 20,
              'measurement': 'each',
              'purchasedPrice': 5,
              'sellingPrice': 8,
              'batchNumber': 'B-100',
              'madeIn': 'Ethiopia',
              'expirationDate': '2026-12-31',
              'status': 'pending',
            },
            onEdit: () {},
            onApprove: () {},
            onReject: () {},
          ),
        ),
      ),
    );

    expect(find.text('Paracetamol'), findsOneWidget);
    expect(find.text('Approve Medication'), findsOneWidget);
    expect(find.text('Reject Medication'), findsOneWidget);
    expect(find.text('Edit Medication'), findsOneWidget);
  });
}
