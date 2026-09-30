import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../financial_engine/domain/models/incoming_remittance.dart';
import '../../financial_engine/domain/services/financial_engine.dart';

/// PDF export service with Arabic typography support.
class PdfExporter {
  static Future<void> exportAndPrintIncomingReport({
    required String batchLabel,
    required List<IncomingRemittance> remittances,
    required String bureauName,
    bool enableClassification = true,
    double largeThreshold = 100000.0,
  }) async {
    final pdf = pw.Document();
    final totals = FinancialEngine.calculateTotals(remittances, largeThreshold);

    // Load bundled Arabic font (Amiri) offline for guaranteed Arabic rendering
    pw.Font font;
    pw.Font fontBold;
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final fontBoldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
      font = pw.Font.ttf(fontData);
      fontBold = pw.Font.ttf(fontBoldData);
    } catch (_) {
      try {
        font = await PdfGoogleFonts.cairoRegular();
        fontBold = await PdfGoogleFonts.cairoBold();
      } catch (_) {
        font = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
      }
    }

    final resolvedBureauName = bureauName.trim().isEmpty || bureauName.trim() == 'Smart Paster'
        ? 'نظام القسام للصرافة والتحويلات'
        : bureauName.trim();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        textDirection: pw.TextDirection.rtl,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              resolvedBureauName,
              style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.teal800),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'تقرير كشف الحوالات الواردة - $batchLabel',
              style: pw.TextStyle(font: fontBold, fontSize: 14),
            ),
            pw.Text(
              'تاريخ التقرير: ${DateTime.now().toString().split('.')[0]}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Divider(thickness: 1, color: PdfColors.teal),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          // Table of remittances (Arranged for strict Right-to-Left visual rendering)
          pw.TableHelper.fromTextArray(
            headers: [
              'المقابل بالبر',
              'سعر الصرف',
              'العملة',
              'المبلغ',
              'رقم الحساب',
              'اسم المستفيد',
              'م',
            ],
            data: remittances.map((r) => [
              FinancialEngine.formatNumber(r.birr),
              r.rate.toString(),
              FinancialEngine.normalizeCurrency(r.currency),
              FinancialEngine.formatNumber(r.amount),
              r.account,
              _cleanBeneficiaryName(r.name),
              r.sequence.toString(),
            ]).toList(),
            columnWidths: {
              0: const pw.FlexColumnWidth(16),
              1: const pw.FlexColumnWidth(15),
              2: const pw.FlexColumnWidth(15),
              3: const pw.FlexColumnWidth(12),
              4: const pw.FlexColumnWidth(18),
              5: const pw.FlexColumnWidth(20),
              6: const pw.FlexColumnWidth(4),
            },
            headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            headerAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
            cellStyle: pw.TextStyle(font: font, fontSize: 8.5),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          ),
          pw.SizedBox(height: 15),

          // Subtotals Box
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.teal, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              color: PdfColors.teal50,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ملخص العمليات الحسابية:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                pw.SizedBox(height: 6),
                if (enableClassification) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('الحوالات الصغيرة (< ${FinancialEngine.formatNumber(largeThreshold)} بر): ${totals.smallCount} حوالة'),
                      pw.Text('${FinancialEngine.formatNumber(totals.smallBirr)} بر', style: pw.TextStyle(font: fontBold)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('الحوالات الكبيرة (>= ${FinancialEngine.formatNumber(largeThreshold)} بر): ${totals.largeCount} حوالة'),
                      pw.Text('${FinancialEngine.formatNumber(totals.largeBirr)} بر', style: pw.TextStyle(font: fontBold)),
                    ],
                  ),
                ],
                pw.Divider(color: PdfColors.teal),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('إجمالي البر الإثيوبي العام (${totals.totalCount} حوالة):', style: pw.TextStyle(font: fontBold, color: PdfColors.teal900)),
                    pw.Text('${FinancialEngine.formatNumber(totals.totalBirr)} بر', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.teal900)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('إجمالي السنتات المقطوعة:'),
                    pw.Text('${totals.totalCutCents.toStringAsFixed(2)} سنت'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'كشف_$batchLabel.pdf',
    );
  }

  static String _cleanBeneficiaryName(String name) {
    var cleaned = name.trim();
    cleaned = cleaned.replaceAll(
      RegExp(
        r'^\*?(?:اسم\s*المستفيد|اسم\s*المستلم|اسم\s*العميل|المستفيد|المستلم|العميل|الاسم|إلى|إلي|to|name|beneficiary|recipient)\*?\s*[:=؛\-/]?\s*',
        caseSensitive: false,
      ),
      '',
    ).replaceAll(
      RegExp(
        r'\s*[:=؛\-/]?\s*\*?(?:اسم\s*المستفيد|اسم\s*المستلم|اسم\s*العميل|المستفيد|المستلم|العميل|الاسم|إلى|إلي|to|name|beneficiary|recipient)\*?$',
        caseSensitive: false,
      ),
      '',
    ).trim();
    return cleaned.isNotEmpty ? cleaned : name;
  }
}
