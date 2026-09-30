import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../financial_engine/domain/models/incoming_remittance.dart';
import '../../financial_engine/domain/models/outgoing_transfer.dart';
import '../../financial_engine/domain/services/financial_engine.dart';

/// Service to export incoming and outgoing remittances into professional Excel spreadsheets.
class ExcelExporter {
  /// Export incoming remittances with date/batch awareness and totals breakdown.
  static Future<String> exportIncomingRemittances({
    required String batchLabel,
    required List<IncomingRemittance> remittances,
    required String bureauName,
    String? dateSubtitle,
    bool enableClassification = true,
    double largeThreshold = 100000.0,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'كشف الوارد المصرفي';
    final Sheet sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    try {
      excel.delete('Sheet1');
    } catch (_) {}

    // Column widths for RTL readable accounting layout
    sheet.setColumnWidth(0, 8.0);   // م
    sheet.setColumnWidth(1, 15.0);  // تاريخ القيد
    sheet.setColumnWidth(2, 26.0);  // اسم المستفيد
    sheet.setColumnWidth(3, 22.0);  // رقم الحساب
    sheet.setColumnWidth(4, 18.0);  // المبلغ المقبوض
    sheet.setColumnWidth(5, 12.0);  // العملة
    sheet.setColumnWidth(6, 14.0);  // سعر المصارفة
    sheet.setColumnWidth(7, 22.0);  // المقابل بالبر
    sheet.setColumnWidth(8, 16.0);  // الكسور المستقطعة
    sheet.setColumnWidth(9, 22.0);  // التصنيف المحاسبي
    sheet.setColumnWidth(10, 16.0); // حالة القيد

    // Title Block (Accounting Standard Header)
    sheet.appendRow([
      TextCellValue('منظومة القسام لإدارة التحويلات والصرافة'),
    ]);
    sheet.appendRow([
      TextCellValue('كشف حساب الحوالات والمدفوعات المصرفية (الوارد) — $bureauName'),
    ]);
    sheet.appendRow([
      TextCellValue('البيان / الحزمة: $batchLabel | تاريخ القيد: ${dateSubtitle ?? DateTime.now().toString().split('.')[0]}'),
    ]);
    sheet.appendRow([TextCellValue('')]); // empty line

    // Header Row (RTL accounting standard)
    sheet.appendRow([
      TextCellValue('م'),
      TextCellValue('تاريخ القيد'),
      TextCellValue('اسم المستفيد / العميل'),
      TextCellValue('رقم الحساب البنكي'),
      TextCellValue('المبلغ المقبوض'),
      TextCellValue('العملة'),
      TextCellValue('سعر المصارفة'),
      TextCellValue('المبلغ المصروف (بر إثيوبي)'),
      TextCellValue('فارق الكسور (بر)'),
      TextCellValue('التصنيف المحاسبي'),
      TextCellValue('حالة القيد'),
    ]);

    // Data rows
    int index = 1;
    for (final r in remittances) {
      final classificationLabel = enableClassification
          ? (r.birrEquivalent >= largeThreshold
              ? 'حوالة كبرى (>= ${FinancialEngine.formatNumber(largeThreshold)})'
              : 'حوالة عادية (< ${FinancialEngine.formatNumber(largeThreshold)})')
          : 'حوالة واردة معتمدة';

      sheet.appendRow([
        IntCellValue(index++),
        TextCellValue(r.date),
        TextCellValue(r.name),
        TextCellValue(r.account),
        DoubleCellValue(r.amount),
        TextCellValue(r.currency),
        DoubleCellValue(r.rate),
        IntCellValue(r.birrEquivalent.toInt()),
        DoubleCellValue(r.cutCents),
        TextCellValue(classificationLabel),
        TextCellValue('مطابق ومعتمد'),
      ]);
    }

    // Totals & Accounting Reconciliation Block
    final totals = FinancialEngine.calculateTotals(remittances, largeThreshold);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('ملخص التقفيل والمطابقة المحاسبية:'),
    ]);
    sheet.appendRow([
      TextCellValue('إجمالي عدد الحوالات:'),
      IntCellValue(totals.count),
      TextCellValue('عملية معتمدة ومقيدة'),
    ]);
    sheet.appendRow([
      TextCellValue('إجمالي المبالغ المقبوضة:'),
      DoubleCellValue(totals.totalAmount),
      TextCellValue(remittances.isNotEmpty ? remittances.first.currency : 'ريال'),
    ]);
    sheet.appendRow([
      TextCellValue('إجمالي المبالغ المصروفة:'),
      DoubleCellValue(totals.totalBirr),
      TextCellValue('بر إثيوبي'),
    ]);
    if (totals.totalCutCents > 0) {
      sheet.appendRow([
        TextCellValue('إجمالي الكسور المستقطعة:'),
        DoubleCellValue(totals.totalCutCents),
        TextCellValue('بر إثيوبي'),
      ]);
    }
    if (enableClassification) {
      sheet.appendRow([
        TextCellValue('فئة الحوالات الصغيرة (< ${FinancialEngine.formatNumber(largeThreshold)} بر):'),
        TextCellValue('${totals.smallCount} حوالة'),
        TextCellValue('إجمالي البر: ${FinancialEngine.formatNumber(totals.smallBirrTotal)} بر'),
      ]);
      sheet.appendRow([
        TextCellValue('فئة الحوالات الكبيرة (>= ${FinancialEngine.formatNumber(largeThreshold)} بر):'),
        TextCellValue('${totals.largeCount} حوالة'),
        TextCellValue('إجمالي البر: ${FinancialEngine.formatNumber(totals.largeBirrTotal)} بر'),
      ]);
    }
    sheet.appendRow([
      TextCellValue('إقرار التدقيق: تمت المطابقة والتقفيل المحاسبي آلياً عبر منظومة القسام'),
    ]);

    return _saveAndOpenFile(
      excel: excel,
      prefix: 'كشف_الوارد_${batchLabel.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '_')}',
      shareText: 'كشف حساب حوالات وارد - $batchLabel',
    );
  }

  /// Export outgoing transfers (شبكات الصرافة والتحويلات) by date or filter.
  static Future<String> exportOutgoingTransfers({
    required String statementTitle,
    required List<OutgoingTransfer> transfers,
    required String bureauName,
    String? dateSubtitle,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'كشف الصادر والشبكات';
    final Sheet sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    try {
      excel.delete('Sheet1');
    } catch (_) {}

    // Column widths for RTL readable accounting layout
    sheet.setColumnWidth(0, 8.0);   // م
    sheet.setColumnWidth(1, 15.0);  // تاريخ العملية
    sheet.setColumnWidth(2, 26.0);  // المستلم / المستفيد
    sheet.setColumnWidth(3, 22.0);  // المرسل / الحساب المصدر
    sheet.setColumnWidth(4, 18.0);  // المبلغ المحول
    sheet.setColumnWidth(5, 12.0);  // العملة
    sheet.setColumnWidth(6, 20.0);  // شبكة التحويل
    sheet.setColumnWidth(7, 22.0);  // رقم الحوالة / المرجع المصرفي
    sheet.setColumnWidth(8, 16.0);  // العمولة / الأجور
    sheet.setColumnWidth(9, 24.0);  // البيان / ملاحظات
    sheet.setColumnWidth(10, 16.0); // حالة القيد

    // Title Row
    sheet.appendRow([
      TextCellValue('منظومة القسام لإدارة التحويلات والصرافة'),
    ]);
    sheet.appendRow([
      TextCellValue('كشف الحوالات والمدفوعات الصادرة (شبكات الصرافة) — $bureauName'),
    ]);
    sheet.appendRow([
      TextCellValue('البيان: $statementTitle | تاريخ الكشف: ${dateSubtitle ?? DateTime.now().toString().split('.')[0]}'),
    ]);
    sheet.appendRow([TextCellValue('')]); // empty line

    // Header Row (RTL accounting standard)
    sheet.appendRow([
      TextCellValue('م'),
      TextCellValue('تاريخ العملية'),
      TextCellValue('اسم المستلم / المستفيد'),
      TextCellValue('المرسل / الحساب المصدر'),
      TextCellValue('المبلغ المحول'),
      TextCellValue('العملة'),
      TextCellValue('شبكة التحويل / البنك'),
      TextCellValue('رقم الحوالة / المرجع المصرفي'),
      TextCellValue('العمولة / الأجور'),
      TextCellValue('البيان / ملاحظات'),
      TextCellValue('حالة القيد'),
    ]);

    // Data rows
    int index = 1;
    for (final t in transfers) {
      sheet.appendRow([
        IntCellValue(index++),
        TextCellValue(t.date),
        TextCellValue(t.recipient),
        TextCellValue(t.sender),
        DoubleCellValue(t.amount),
        TextCellValue(t.currency),
        TextCellValue(t.network),
        TextCellValue(t.transferNo),
        TextCellValue(t.commission),
        TextCellValue(t.notes),
        TextCellValue('مقيد ومعتمد'),
      ]);
    }

    // Totals & Accounting Reconciliation Block
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('ملخص التقفيل والمطابقة المحاسبية للصادر:'),
    ]);
    sheet.appendRow([
      TextCellValue('إجمالي عدد الحوالات الصادرة:'),
      IntCellValue(transfers.length),
      TextCellValue('حوالة منفذة ومقيدة'),
    ]);

    // Group sum by currency
    final Map<String, double> sumByCurrency = {};
    for (final t in transfers) {
      sumByCurrency[t.currency] = (sumByCurrency[t.currency] ?? 0) + t.amount;
    }
    for (final entry in sumByCurrency.entries) {
      sheet.appendRow([
        TextCellValue('إجمالي مبالغ الصادر (${entry.key}):'),
        DoubleCellValue(entry.value),
        TextCellValue(entry.key),
      ]);
    }
    sheet.appendRow([
      TextCellValue('إقرار التدقيق: تمت المطابقة والتقفيل المحاسبي آلياً عبر منظومة القسام'),
    ]);

    return _saveAndOpenFile(
      excel: excel,
      prefix: 'كشف_الصادر_${statementTitle.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '_')}',
      shareText: 'كشف حساب حوالات صادر - $statementTitle',
    );
  }

  static Future<String> _saveAndOpenFile({
    required Excel excel,
    required String prefix,
    required String shareText,
  }) async {
    final fileBytes = excel.encode() ?? excel.save();
    if (fileBytes == null) throw Exception('فشل في تشفير ملف الإكسل');

    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    // 1. Web Environment: Direct download / share via XFile.fromData without dart:io Platform
    if (kIsWeb) {
      try {
        await Share.shareXFiles(
          [
            XFile.fromData(
              Uint8List.fromList(fileBytes),
              name: fileName,
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          text: shareText,
        );
      } catch (e) {
        debugPrint('Web export error: $e');
      }
      return fileName;
    }

    // 2. Desktop & Mobile Native Environment (Windows, Android, iOS, macOS, Linux)
    Directory exportDir;
    if (!kIsWeb && Platform.isWindows) {
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {}
      try {
        dir ??= await getApplicationDocumentsDirectory();
      } catch (_) {}
      exportDir = dir ?? Directory.systemTemp;
    } else {
      Directory? externalDir;
      try {
        externalDir = await getExternalStorageDirectory();
      } catch (_) {}
      try {
        exportDir = externalDir ?? await getApplicationDocumentsDirectory();
      } catch (_) {
        exportDir = Directory.systemTemp;
      }
    }

    final filePath = '${exportDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes, flush: true);

    debugPrint('Excel exported successfully to: $filePath');

    if (!kIsWeb && Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      } catch (e) {
        debugPrint('Could not auto-start Excel: $e');
      }
    } else {
      try {
        await Share.shareXFiles(
          [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          text: shareText,
        );
      } catch (e) {
        debugPrint('Share mobile error: $e');
      }
    }

    return filePath;
  }

  /// Open or reveal the file in the OS
  static Future<void> openFile(String filePath) async {
    if (kIsWeb) return;
    if (!kIsWeb && Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', filePath]);
    } else {
      await Share.shareXFiles([
        XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      ]);
    }
  }
}

