import '../../financial_engine/domain/models/incoming_remittance.dart';
import '../../financial_engine/domain/models/outgoing_transfer.dart';
import '../../financial_engine/domain/services/financial_engine.dart';

/// منسق التقارير ورسائل الواتساب لنظام القسام وفق المعايير الرسمية والخالية تماماً من الملصقات والرموز
class ReportFormatter {
  /// توليد رسالة كشف البر للواتساب (حوالات الدفعة الحالية فقط)
  /// الصيغة المعتمدة:
  /// الاسم
  /// رقم الحساب
  /// المبلغ birr
  static String formatBirrReport(
    List<IncomingRemittance> records, {
    bool includeTotals = true,
  }) {
    if (records.isEmpty) return 'لا توجد حوالات في هذه الدفعة.';

    final buffer = StringBuffer();

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      buffer.writeln(r.name);
      buffer.writeln(r.account);
      buffer.writeln('${FinancialEngine.formatNumber(r.birrEquivalent)} birr');

      if (i < records.length - 1) {
        buffer.writeln(); // سطر فارغ بين الحوالات
      }
    }

    if (includeTotals && records.isNotEmpty) {
      final totals = FinancialEngine.calculateTotals(records);
      buffer.writeln();
      buffer.writeln('--------------------');
      buffer.writeln('إجمالي عدد الحوالات: ${totals.count}');
      buffer.writeln(
          'إجمالي المبلغ بالبر: ${FinancialEngine.formatNumber(totals.totalBirr)} birr');
    }

    return buffer.toString();
  }

  /// كشف الوارد الشامل المنسق مع دعم التصنيف الاختياري والحد المخصص
  static String formatFullIncomingSummary(
    List<IncomingRemittance> records,
    double rate, {
    bool enableClassification = true,
    double largeThreshold = 100000.0,
  }) {
    if (records.isEmpty) return 'لا توجد حوالات واردة.';

    final totals = FinancialEngine.calculateTotals(records, largeThreshold);
    final buffer = StringBuffer();

    buffer.writeln('*كشف حسابات الصرافين (الوارد بالبر) — نظام القسام*');
    buffer.writeln('سعر المصارفة: ${FinancialEngine.formatNumber(rate, 2)}');
    buffer.writeln('التاريخ: ${records.first.date}');
    buffer.writeln('==============================\n');

    if (enableClassification) {
      final smallList = records.where((r) => r.birrEquivalent < largeThreshold).toList();
      final largeList = records.where((r) => r.birrEquivalent >= largeThreshold).toList();

      if (smallList.isNotEmpty) {
        buffer.writeln('*الحوالات العادية (أقل من ${FinancialEngine.formatNumber(largeThreshold)} بر):*');
        for (final r in smallList) {
          buffer.writeln(
              '${r.seq}. المستفيد: ${r.name} | الحساب: ${r.account} | المقبوض: ${FinancialEngine.formatNumber(r.amount)} ${r.currency} | المصروف: ${FinancialEngine.formatNumber(r.birrEquivalent)} بر');
        }
        buffer.writeln(
            '   *إجمالي الفئة العادية (${smallList.length} حوالة):* ${FinancialEngine.formatNumber(totals.smallBirrTotal)} بر\n');
      }

      if (largeList.isNotEmpty) {
        buffer.writeln('*الحوالات الكبيرة (${FinancialEngine.formatNumber(largeThreshold)} بر فأكثر):*');
        for (final r in largeList) {
          buffer.writeln(
              '${r.seq}. المستفيد: ${r.name} | الحساب: ${r.account} | المقبوض: ${FinancialEngine.formatNumber(r.amount)} ${r.currency} | المصروف: ${FinancialEngine.formatNumber(r.birrEquivalent)} بر');
        }
        buffer.writeln(
            '   *إجمالي الفئة الكبيرة (${largeList.length} حوالة):* ${FinancialEngine.formatNumber(totals.largeBirrTotal)} بر\n');
      }
    } else {
      buffer.writeln('*قائمة الحوالات الواردة:*');
      for (final r in records) {
        buffer.writeln(
            '${r.seq}. المستفيد: ${r.name} | الحساب: ${r.account} | المقبوض: ${FinancialEngine.formatNumber(r.amount)} ${r.currency} | المصروف: ${FinancialEngine.formatNumber(r.birrEquivalent)} بر');
      }
      buffer.writeln();
    }

    buffer.writeln('==============================');
    buffer.writeln('*الإجمالي العام الشامل:*');
    buffer.writeln('العدد الإجمالي: ${totals.count} حوالة');
    buffer.writeln(
        'إجمالي العملة الأصلية: ${FinancialEngine.formatNumber(totals.totalAmount, 2)}');
    buffer.writeln(
        'الإجمالي النهائي بالبر: ${FinancialEngine.formatNumber(totals.totalBirr)} بر إثيوبي');
    if (totals.totalCutCents > 0) {
      buffer.writeln(
          'إجمالي الكسور المستقطعة: ${totals.totalCutCents.toStringAsFixed(2)} بر');
    }
    buffer.writeln('*تم التحقق والتقفيل آلياً عبر نظام القسام*');

    return buffer.toString();
  }

  /// كشف الحوالات الصادرة وشبكات الصرافة
  static String formatOutgoingSummary(List<OutgoingTransfer> records) {
    if (records.isEmpty) return 'لا توجد حوالات صادرة.';

    final buffer = StringBuffer();
    double totalAmount = 0;

    buffer.writeln('*كشف الحوالات الصادرة (شبكات الصرافة) — نظام القسام*');
    buffer.writeln('التاريخ: ${records.first.date}');
    buffer.writeln('==============================\n');

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      totalAmount += r.amount;
      buffer.writeln('${i + 1}. المستلم: ${r.recipient}');
      buffer.writeln(
          '   المبلغ: ${FinancialEngine.formatNumber(r.amount, 2)} ${r.currency}');
      if (r.network != '-') buffer.writeln('   الشبكة: ${r.network}');
      if (r.transferNo != '-') buffer.writeln('   رقم الحوالة: ${r.transferNo}');
      if (r.commission != '-') buffer.writeln('   العمولة: ${r.commission}');
      buffer.writeln('   المرسل: ${r.sender}');
      buffer.writeln();
    }

    buffer.writeln('==============================');
    buffer.writeln('إجمالي عدد الحوالات الصادرة: ${records.length}');
    buffer.writeln(
        'إجمالي المبالغ الصادرة: ${FinancialEngine.formatNumber(totalAmount, 2)} ريال سعودي');
    buffer.writeln('*تم التحقق آلياً عبر نظام القسام*');

    return buffer.toString();
  }

  /// تنسيق حوالة بر مفردة للواتساب والبنك
  static String formatSingleBirrMessage(IncomingRemittance r) {
    return '${r.name}\n${r.account}\n${FinancialEngine.formatNumber(r.birrEquivalent)} birr';
  }

  /// تنسيق حوالة صادرة مفردة للواتساب
  static String formatSingleOutgoingTransfer(OutgoingTransfer r) {
    final buffer = StringBuffer();
    buffer.writeln('المستلم: ${r.recipient}');
    buffer.writeln('المبلغ: ${FinancialEngine.formatNumber(r.amount, 2)} ${r.currency}');
    if (r.network != '-') buffer.writeln('الشبكة: ${r.network}');
    if (r.transferNo != '-') buffer.writeln('رقم الحوالة: ${r.transferNo}');
    if (r.commission != '-') buffer.writeln('العمولة: ${r.commission}');
    if (r.sender.isNotEmpty && r.sender != 'غير محدد') buffer.writeln('المرسل: ${r.sender}');
    return buffer.toString().trim();
  }

  /// تنسيق قائمة الحوالات الصادرة برسائل نصية للواتساب
  static String formatOutgoingListMessage(List<OutgoingTransfer> records) {
    if (records.isEmpty) return 'لا توجد حوالات صادرة.';
    if (records.length == 1) return formatSingleOutgoingTransfer(records.first);

    final buffer = StringBuffer();
    for (int i = 0; i < records.length; i++) {
      buffer.writeln(formatSingleOutgoingTransfer(records[i]));
      if (i < records.length - 1) {
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  /// توليد رسالة تقرير الأرباح والمطابقة الشاملة للواتساب وفق المعايير الرسمية والخالية تماماً من الملصقات
  static String formatCombinedProfitReport(
    CombinedProfitReport report, {
    String bureauName = 'نظام القسام للصرافة والتحويلات',
    String dateLabel = 'اليوم',
  }) {
    final buffer = StringBuffer();
    buffer.writeln('*$bureauName*');
    buffer.writeln('*تقرير الأرباح والمطابقة المالية الشاملة*');
    buffer.writeln('الفترة / التاريخ: $dateLabel');
    buffer.writeln('==============================\n');

    buffer.writeln('*أسعار مصارفة البر الإثيوبي:*');
    buffer.writeln('• سعر الشراء: ${FinancialEngine.formatNumber(report.buyRate, 2)} بر/ريال');
    buffer.writeln('• سعر البيع: ${FinancialEngine.formatNumber(report.sellRate, 2)} بر/ريال');
    buffer.writeln('• فارق الصرف (الهامش): ${report.birrSpreadPerUnit} بر لكل 1 ريال\n');

    buffer.writeln('*حركة كشف الوارد (البر الإثيوبي):*');
    buffer.writeln('• عدد الحوالات: ${report.incomingCount} حوالة');
    buffer.writeln('• إجمالي المقبوض: ${FinancialEngine.formatNumber(report.totalOriginalReceived, 2)} ريال سعودي');
    buffer.writeln('• إجمالي المصروف: ${FinancialEngine.formatNumber(report.totalBirrDisbursed)} بر إثيوبي');
    buffer.writeln('• ربح مصارفة البر: +${FinancialEngine.formatNumber(report.birrProfitInOriginal, 2)} ريال (${FinancialEngine.formatNumber(report.birrProfitInBirr)} بر)\n');

    buffer.writeln('*حركة كشف الصادر (الشبكات والحوالات):*');
    buffer.writeln('• عدد الحوالات الصادرة: ${report.outgoingCount} حوالة');
    buffer.writeln('• إجمالي مبالغ الصادر: ${FinancialEngine.formatNumber(report.outgoingTotalAmount, 2)} ريال سعودي');
    buffer.writeln('• أرباح عمولات الصادر: +${FinancialEngine.formatNumber(report.outgoingCommissionsTotal, 2)} ريال\n');

    buffer.writeln('==============================');
    buffer.writeln('*النتائج الختامية الشاملة:*');
    buffer.writeln('• صافي حركة النقد (السيولة): ${FinancialEngine.formatNumber(report.netCashFlow, 2)} ريال سعودي');
    buffer.writeln('• صافي الأرباح العام: ${FinancialEngine.formatNumber(report.totalNetProfitInOriginal, 2)} ريال سعودي');
    buffer.writeln('*تم التحقق والتقفيل آلياً عبر نظام القسام*');

    return buffer.toString();
  }
}
