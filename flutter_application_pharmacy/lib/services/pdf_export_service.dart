import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/medication_status.dart';
import '../core/utils/sale_pricing.dart';

class PdfExportService {
  const PdfExportService();

  static Future<pw.ThemeData>? _themeFuture;

  Future<void> exportSalesReportPdf({
    required String title,
    required String periodLabel,
    required String paymentFilter,
    required int transactionCount,
    required double totalRevenue,
    required double totalExpense,
    required double averageSale,
    required List<Map<String, dynamic>> sales,
  }) async {
    final fileName = _buildFileName(
      baseName: title,
      suffix: periodLabel,
    );
    final bytes = await buildSalesReportPdf(
      title: title,
      periodLabel: periodLabel,
      paymentFilter: paymentFilter,
      transactionCount: transactionCount,
      totalRevenue: totalRevenue,
      totalExpense: totalExpense,
      averageSale: averageSale,
      sales: sales,
    );

    await Printing.layoutPdf(
      name: fileName,
      onLayout: (_) async => bytes,
    );
  }

  Future<void> exportInventoryPdf({
    required String title,
    required List<Map<String, dynamic>> medications,
  }) async {
    final fileName = _buildFileName(baseName: title);
    final bytes = await buildInventoryPdf(
      title: title,
      medications: medications,
    );

    await Printing.layoutPdf(
      name: fileName,
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> buildSalesReportPdf({
    required String title,
    required String periodLabel,
    required String paymentFilter,
    required int transactionCount,
    required double totalRevenue,
    required double totalExpense,
    required double averageSale,
    required List<Map<String, dynamic>> sales,
  }) async {
    final theme = await _buildTheme();
    final document = pw.Document(
      theme: theme,
      title: title,
      subject: '$periodLabel sales report',
      creator: 'Pharmacy App',
    );
    final generatedAt = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
    final rows = sales.map((sale) {
      final adjustmentType =
          salePriceAdjustmentTypeFromValue(sale['priceAdjustmentType']);
      final adjustmentAmount =
          salePricingToDouble(sale['priceAdjustmentAmount']);
      final hasAdjustment = hasMeaningfulSaleAdjustment(
        adjustmentType: adjustmentType,
        adjustmentAmount: adjustmentAmount,
      );

      final adjustmentLabel = hasAdjustment
          ? '${adjustmentType.label} ${_currency(adjustmentAmount)}'
          : '-';

      return [
        _formatDate(sale['date']),
        (sale['drugName'] ?? 'Medication').toString(),
        (sale['quantitySold'] ?? 0).toString(),
        _currency(salePricingToDouble(sale['unitPrice'])),
        adjustmentLabel,
        (sale['paymentMethod'] ?? 'Unknown').toString(),
        _currency(salePricingToDouble(sale['sellingPrice'])),
      ];
    }).toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _buildDocumentHeader(
            title: title,
            subtitle: 'Period: $periodLabel',
            generatedAt: generatedAt,
          ),
          pw.SizedBox(height: 14),
          _buildInfoTable(
            entries: [
              _PdfInfoEntry(label: 'Payment Filter', value: paymentFilter),
              _PdfInfoEntry(
                label: 'Transactions',
                value: transactionCount.toString(),
              ),
              _PdfInfoEntry(
                label: 'Revenue',
                value: _currency(totalRevenue),
              ),
              _PdfInfoEntry(
                label: 'Expenses',
                value: _currency(totalExpense),
              ),
              _PdfInfoEntry(
                label: 'Average Sale',
                value: _currency(averageSale),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Sales Transactions',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _buildTable(
            headers: const [
              'Date',
              'Medicine',
              'Qty',
              'Unit Price',
              'Adjustment',
              'Payment',
              'Total',
            ],
            rows: rows,
            flexColumnWidths: const {
              0: 2,
              1: 4,
              2: 1,
              3: 2,
              4: 3,
              5: 2,
              6: 2,
            },
          ),
          if (rows.isEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'No sales were recorded for the selected report.',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
        ],
      ),
    );

    return document.save();
  }

  Future<Uint8List> buildInventoryPdf({
    required String title,
    required List<Map<String, dynamic>> medications,
  }) async {
    final theme = await _buildTheme();
    final document = pw.Document(
      theme: theme,
      title: title,
      subject: 'Inventory report',
      creator: 'Pharmacy App',
    );
    final generatedAt = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
    final lowStockCount = medications.where(isMedicationStockAlert).length;
    final expiryAlertCount = medications.where(isMedicationExpiryAlert).length;

    final rows = medications.map((medication) {
      final expiry = parseMedicationExpiry(medication);
      return [
        (medication['drug'] ?? 'Unnamed').toString(),
        (medication['brandName'] ?? 'No brand').toString(),
        (medication['medicationType'] ?? '').toString(),
        '${parseMedicationQuantity(medication)} ${(medication['measurement'] ?? '').toString().trim()}'
            .trim(),
        _currency(salePricingToDouble(medication['purchasedPrice'])),
        _currency(salePricingToDouble(medication['sellingPrice'])),
        expiry == null ? 'N/A' : DateFormat('dd MMM yyyy').format(expiry),
        resolveMedicationStatus(medication).label,
      ];
    }).toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _buildDocumentHeader(
            title: title,
            subtitle: 'Approved inventory snapshot',
            generatedAt: generatedAt,
          ),
          pw.SizedBox(height: 14),
          _buildInfoTable(
            entries: [
              _PdfInfoEntry(
                label: 'Approved Items',
                value: medications.length.toString(),
              ),
              _PdfInfoEntry(
                label: 'Low Stock Alerts',
                value: lowStockCount.toString(),
              ),
              _PdfInfoEntry(
                label: 'Expiry Alerts',
                value: expiryAlertCount.toString(),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Medication Table',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _buildTable(
            headers: const [
              'Drug',
              'Brand',
              'Type',
              'Stock',
              'Purchase',
              'Sell',
              'Expiry',
              'Status',
            ],
            rows: rows,
            flexColumnWidths: const {
              0: 3,
              1: 3,
              2: 2,
              3: 2,
              4: 2,
              5: 2,
              6: 2,
              7: 2,
            },
          ),
          if (rows.isEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'No approved medications are available to export.',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _buildDocumentHeader({
    required String title,
    required String subtitle,
    required String generatedAt,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.blueGrey700,
              ),
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const pw.BoxDecoration(
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
            color: PdfColors.grey100,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Generated',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                generatedAt,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInfoTable({required List<_PdfInfoEntry> entries}) {
    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: entries.map((entry) {
        return pw.Container(
          width: 170,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: PdfColors.teal100),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                entry.label,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                entry.value,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildTable({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, int>? flexColumnWidths,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.teal700,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      columnWidths: flexColumnWidths?.map(
        (index, flex) => MapEntry(index, pw.FlexColumnWidth(flex.toDouble())),
      ),
    );
  }

  String _buildFileName({
    required String baseName,
    String? suffix,
  }) {
    final formatter = DateFormat('yyyyMMdd_HHmm');
    final cleanedBase = _cleanFileName(baseName);
    final cleanedSuffix = suffix == null ? '' : '_${_cleanFileName(suffix)}';
    return '$cleanedBase${cleanedSuffix}_${formatter.format(DateTime.now())}.pdf';
  }

  String _cleanFileName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _currency(double value) => '${value.toStringAsFixed(2)} Birr';

  String _formatDate(dynamic rawDate) {
    final parsed = DateTime.tryParse((rawDate ?? '').toString());
    if (parsed == null) {
      return 'Unknown';
    }

    return DateFormat('dd MMM yyyy').format(parsed);
  }

  Future<pw.ThemeData> _buildTheme() async {
    return _themeFuture ??= _loadTheme();
  }

  Future<pw.ThemeData> _loadTheme() async {
    final base = await PdfGoogleFonts.openSansRegular();
    final bold = await PdfGoogleFonts.openSansBold();
    final italic = await PdfGoogleFonts.openSansItalic();
    final boldItalic = await PdfGoogleFonts.openSansBoldItalic();
    final unicodeFallback = await PdfGoogleFonts.notoSansRegular();
    final unicodeBoldFallback = await PdfGoogleFonts.notoSansBold();
    final emoji = await PdfGoogleFonts.notoColorEmoji();
    final icons = await PdfGoogleFonts.materialIcons();

    return pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
      icons: icons,
      fontFallback: [
        unicodeFallback,
        unicodeBoldFallback,
        emoji,
        base,
      ],
    );
  }
}

class _PdfInfoEntry {
  const _PdfInfoEntry({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}
