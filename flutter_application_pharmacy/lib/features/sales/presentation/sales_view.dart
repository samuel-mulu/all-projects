import 'package:flutter/material.dart';

import 'sell_medication_page.dart';

class SalesView extends StatelessWidget {
  const SalesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SellMedicationPage(
      showScaffold: false,
      autoCloseOnSuccess: false,
      showSheetChrome: false,
    );
  }
}
