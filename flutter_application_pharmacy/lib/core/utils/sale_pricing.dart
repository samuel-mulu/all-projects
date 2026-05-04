enum SalePriceAdjustmentType {
  none('none', 'No Change'),
  discount('discount', 'Discount'),
  addition('addition', 'Addition');

  const SalePriceAdjustmentType(this.storageValue, this.label);

  final String storageValue;
  final String label;

  bool get hasAdjustment => this != SalePriceAdjustmentType.none;
}

SalePriceAdjustmentType salePriceAdjustmentTypeFromValue(dynamic value) {
  final normalized = (value ?? '').toString().trim().toLowerCase();

  for (final type in SalePriceAdjustmentType.values) {
    if (type.storageValue == normalized) {
      return type;
    }
  }

  return SalePriceAdjustmentType.none;
}

double salePricingToDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

bool hasMeaningfulSaleAdjustment({
  required SalePriceAdjustmentType adjustmentType,
  required double adjustmentAmount,
}) {
  return adjustmentType.hasAdjustment && adjustmentAmount > 0;
}

double normalizeSaleAdjustmentAmount(double adjustmentAmount) {
  if (adjustmentAmount.isNaN || adjustmentAmount.isInfinite) {
    return 0.0;
  }

  return adjustmentAmount < 0 ? 0.0 : adjustmentAmount;
}

double calculateSaleUnitPrice({
  required double baseUnitPrice,
  required SalePriceAdjustmentType adjustmentType,
  required double adjustmentAmount,
}) {
  final normalizedAmount = normalizeSaleAdjustmentAmount(adjustmentAmount);

  switch (adjustmentType) {
    case SalePriceAdjustmentType.none:
      return baseUnitPrice;
    case SalePriceAdjustmentType.discount:
      return baseUnitPrice - normalizedAmount;
    case SalePriceAdjustmentType.addition:
      return baseUnitPrice + normalizedAmount;
  }
}
