import 'package:flutter_application_pharmacy/core/utils/sale_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sale pricing helpers', () {
    test('parses adjustment type values safely', () {
      expect(
        salePriceAdjustmentTypeFromValue('discount'),
        SalePriceAdjustmentType.discount,
      );
      expect(
        salePriceAdjustmentTypeFromValue('ADDITION'),
        SalePriceAdjustmentType.addition,
      );
      expect(
        salePriceAdjustmentTypeFromValue('unknown'),
        SalePriceAdjustmentType.none,
      );
      expect(
        salePriceAdjustmentTypeFromValue(null),
        SalePriceAdjustmentType.none,
      );
    });

    test('calculates adjusted unit price from base price', () {
      expect(
        calculateSaleUnitPrice(
          baseUnitPrice: 400,
          adjustmentType: SalePriceAdjustmentType.none,
          adjustmentAmount: 50,
        ),
        400,
      );
      expect(
        calculateSaleUnitPrice(
          baseUnitPrice: 400,
          adjustmentType: SalePriceAdjustmentType.discount,
          adjustmentAmount: 100,
        ),
        300,
      );
      expect(
        calculateSaleUnitPrice(
          baseUnitPrice: 400,
          adjustmentType: SalePriceAdjustmentType.addition,
          adjustmentAmount: 80,
        ),
        480,
      );
    });

    test('treats non-positive adjustments as no meaningful adjustment', () {
      expect(
        hasMeaningfulSaleAdjustment(
          adjustmentType: SalePriceAdjustmentType.discount,
          adjustmentAmount: 0,
        ),
        isFalse,
      );
      expect(
        normalizeSaleAdjustmentAmount(-25),
        0,
      );
    });
  });
}
