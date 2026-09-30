import 'package:intl/intl.dart';
import '../models/incoming_remittance.dart';
import '../models/outgoing_transfer.dart';

/// تقرير الأرباح والمطابقة الشاملة المدمج للحوالات الصادرة والواردة
class CombinedProfitReport {
  final int incomingCount;
  final int outgoingCount;
  final double totalOriginalReceived; // إجمالي ما تم استلامه من العملاء في الوارد (ريال)
  final double totalBirrDisbursed; // إجمالي ما تم صرفه بالبر في الوارد
  final double buyRate; // سعر شراء رصيد البر (مثلاً 50.0 بر/ريال)
  final double sellRate; // سعر بيع وصرف البر للعميل (مثلاً 48.0 بر/ريال)
  final double birrSpreadPerUnit; // فارق الصرف لكل وحدة
  final double birrProfitInBirr; // أرباح البر بالبر الإثيوبي
  final double birrProfitInOriginal; // أرباح مصارفة البر بالريال السعودي
  final double outgoingTotalAmount; // إجمالي مبالغ الحوالات الصادرة
  final double outgoingCommissionsTotal; // إجمالي عمولات الحوالات الصادرة
  final double netCashFlow; // صافي حركة النقد (المقبوض من الوارد - المدفوع في الصادر)
  final double totalNetProfitInOriginal; // صافي الأرباح الشامل (أرباح المصارفة + أرباح العمولات)

  const CombinedProfitReport({
    required this.incomingCount,
    required this.outgoingCount,
    required this.totalOriginalReceived,
    required this.totalBirrDisbursed,
    required this.buyRate,
    required this.sellRate,
    required this.birrSpreadPerUnit,
    required this.birrProfitInBirr,
    required this.birrProfitInOriginal,
    required this.outgoingTotalAmount,
    required this.outgoingCommissionsTotal,
    required this.netCashFlow,
    required this.totalNetProfitInOriginal,
  });
}

/// نتيجة حساب تحويل العملة إلى البر الإثيوبي
class BirrCalculationResult {
  final double birrEquivalent;
  final double cutCents;
  final double rawBirr;

  const BirrCalculationResult({
    required this.birrEquivalent,
    required this.cutCents,
    required this.rawBirr,
  });
}

/// نتيجة حساب المجاميع الكلية للحوالات الواردة
class TotalsCalculationResult {
  final int count;
  final double totalAmount;
  final double totalBirr;
  final double totalCutCents;
  final double smallBirrTotal;
  final double largeBirrTotal;
  final int smallCount;
  final int largeCount;

  const TotalsCalculationResult({
    required this.count,
    required this.totalAmount,
    required this.totalBirr,
    required this.totalCutCents,
    required this.smallBirrTotal,
    required this.largeBirrTotal,
    required this.smallCount,
    required this.largeCount,
  });

  int get totalCount => count;
  double get totalAmountOrig => totalAmount;
  int get smallBirr => smallBirrTotal.toInt();
  int get largeBirr => largeBirrTotal.toInt();
}

typedef FinancialTotals = TotalsCalculationResult;

/// المحرك المالي النقي لنظام القسام (FinancialEngine in Dart)
class FinancialEngine {
  /// فحص هل العملة بر إثيوبي
  static bool isBirr(String? currency) {
    if (currency == null || currency.trim().isEmpty) return false;
    final c = currency.trim().toLowerCase();
    return c == 'etb' ||
        c == 'birr' ||
        c == 'بر' ||
        c == 'بر إثيوبي' ||
        c.contains('بر');
  }

  /// حساب المقابل بالبر مع استقطاع الكسور وتقفيل المئات
  static BirrCalculationResult calculateBirr(
    double amount,
    double rate, [
    String currency = 'ريال سعودي',
  ]) {
    if (isBirr(currency)) {
      return BirrCalculationResult(
        birrEquivalent: amount,
        cutCents: 0.0,
        rawBirr: amount,
      );
    }

    final double effectiveRate = rate <= 0 ? 1.0 : rate;
    final double rawBirr = amount * effectiveRate;

    // تقفيل المئات: استقطاع العشرات والآحاد والكسور
    final double birrEquivalent = ((rawBirr / 100).floor() * 100).toDouble();

    // السنتات المقطوعة بدقة
    final double rawDiff = rawBirr - birrEquivalent;
    final double cutCents = double.parse(rawDiff.toStringAsFixed(2));

    return BirrCalculationResult(
      birrEquivalent: birrEquivalent,
      cutCents: cutCents,
      rawBirr: rawBirr,
    );
  }

  /// تطبيع العملة وتوحيد مسماها
  static String normalizeCurrency(String? rawCurr,
      [String defaultCurrency = 'ريال سعودي']) {
    if (rawCurr == null || rawCurr.trim().isEmpty) return defaultCurrency;
    final c = rawCurr.trim();

    if (RegExp(r'^(sar|ر\.?س|سعودي|سعود|ريال\s*سعودي|ريال\s*سعود|ريال)$', caseSensitive: false)
            .hasMatch(c) ||
        c.contains('سعود')) {
      return 'ريال سعودي';
    }
    if (RegExp(r'^(usd|\$|دولار|دولار أمريكي)$', caseSensitive: false)
        .hasMatch(c)) {
      return 'دولار أمريكي';
    }
    if (RegExp(r'^(yer|يمني|ريال يمني)$', caseSensitive: false)
        .hasMatch(c)) {
      return 'ريال يمني';
    }
    if (RegExp(r'^(etb|birr|بر|بر إثيوبي)$', caseSensitive: false)
        .hasMatch(c)) {
      return 'بر إثيوبي';
    }
    return c;
  }

  /// تنقية وتجريد اسم المستفيد من أية بادئات أو لواحق شائعة
  static String cleanBeneficiaryName(String? name) {
    if (name == null || name.trim().isEmpty) return 'مستفيد غير محدد';
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

  /// تطبيع واستخراج الرقم المالي النقي من أي نص
  static double normalizeAmount(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();

    String str = raw.toString().trim();
    if (str.isEmpty) return 0.0;

    // معالجة الفاصلة العشرية الأوروبية/اللاتينية إن وجدت في نهاية الرقم (مثل 1.250,50)
    if (RegExp(r',\d{1,2}$').hasMatch(str)) {
      final lastComma = str.lastIndexOf(',');
      str = '${str.substring(0, lastComma).replaceAll(',', '')}.${str.substring(lastComma + 1)}';
    } else {
      str = str.replaceAll(',', '');
    }

    // إزالة أي رموز غير الأرقام والنقطة
    str = str.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(str) ?? 0.0;
  }

  /// تنسيق الأرقام مع فواصل الآلاف
  static String formatNumber(num? number, [int decimals = 0]) {
    if (number == null || number.isNaN) return '0';
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: '',
      decimalDigits: decimals,
    );
    return formatter.format(number).trim();
  }

  /// حساب الإجماليات الشاملة وتقسيم الحوالات الصغرى والكبرى حسب الحد المحدد
  static TotalsCalculationResult calculateTotals(
      List<IncomingRemittance> records, [
      double largeThreshold = 100000.0,
  ]) {
    double totalAmount = 0.0;
    double totalBirr = 0.0;
    double totalCutCents = 0.0;
    double smallBirrTotal = 0.0;
    double largeBirrTotal = 0.0;
    int smallCount = 0;
    int largeCount = 0;

    for (final r in records) {
      totalAmount += r.amount;
      totalBirr += r.birrEquivalent;
      totalCutCents += r.cutCents;

      if (r.birrEquivalent >= largeThreshold) {
        largeBirrTotal += r.birrEquivalent;
        largeCount++;
      } else {
        smallBirrTotal += r.birrEquivalent;
        smallCount++;
      }
    }

    return TotalsCalculationResult(
      count: records.length,
      totalAmount: double.parse(totalAmount.toStringAsFixed(2)),
      totalBirr: double.parse(totalBirr.toStringAsFixed(2)),
      totalCutCents: double.parse(totalCutCents.toStringAsFixed(2)),
      smallBirrTotal: double.parse(smallBirrTotal.toStringAsFixed(2)),
      largeBirrTotal: double.parse(largeBirrTotal.toStringAsFixed(2)),
      smallCount: smallCount,
      largeCount: largeCount,
    );
  }

  /// استخراج المبلغ العددي للعمولة
  static double parseCommissionAmount(String? commission) {
    if (commission == null || commission == '-' || commission.trim().isEmpty) {
      return 0.0;
    }
    final match = RegExp(r'[\d,]+(?:\.\d+)?').firstMatch(commission);
    if (match != null) {
      return normalizeAmount(match.group(0));
    }
    return 0.0;
  }

  /// حساب تقرير الأرباح المدمج والمطابقة الشاملة للصادر والوارد معاً
  static CombinedProfitReport calculateCombinedProfitReport({
    required List<IncomingRemittance> incoming,
    required List<OutgoingTransfer> outgoing,
    required double buyRate,
    required double sellRate,
  }) {
    double totalOriginalReceived = 0.0;
    double totalBirrDisbursed = 0.0;

    for (final inc in incoming) {
      if (!isBirr(inc.currency)) {
        totalOriginalReceived += inc.amount;
      }
      totalBirrDisbursed += inc.birrEquivalent;
    }

    final double effectiveBuyRate = buyRate <= 0 ? 50.0 : buyRate;
    final double effectiveSellRate = sellRate <= 0 ? 48.0 : sellRate;

    // فارق سعر الصرف بين الشراء والبيع
    final double spread = (effectiveBuyRate - effectiveSellRate).abs();

    // حساب أرباح مصارفة البر
    double birrProfitInOriginal = 0.0;
    double birrProfitInBirr = 0.0;

    if (totalOriginalReceived > 0 && totalBirrDisbursed > 0) {
      if (effectiveBuyRate > effectiveSellRate) {
        final costInOriginal = totalBirrDisbursed / effectiveBuyRate;
        birrProfitInOriginal = totalOriginalReceived - costInOriginal;
        birrProfitInBirr = birrProfitInOriginal * effectiveBuyRate;
      } else if (effectiveSellRate > effectiveBuyRate) {
        birrProfitInOriginal = (totalOriginalReceived * spread) / effectiveSellRate;
        birrProfitInBirr = totalOriginalReceived * spread;
      }
    }

    // حساب إجمالي مبالغ وعمولات الصادر
    double outgoingTotalAmount = 0.0;
    double outgoingCommissionsTotal = 0.0;

    for (final out in outgoing) {
      outgoingTotalAmount += out.amount;
      outgoingCommissionsTotal += parseCommissionAmount(out.commission);
    }

    // صافي حركة النقد (المقبوض من الوارد - المدفوع في الصادر)
    final double netCashFlow = totalOriginalReceived - outgoingTotalAmount;

    // صافي الأرباح الشامل (أرباح المصارفة + أرباح العمولات)
    final double totalNetProfitInOriginal =
        birrProfitInOriginal + outgoingCommissionsTotal;

    return CombinedProfitReport(
      incomingCount: incoming.length,
      outgoingCount: outgoing.length,
      totalOriginalReceived: double.parse(totalOriginalReceived.toStringAsFixed(2)),
      totalBirrDisbursed: double.parse(totalBirrDisbursed.toStringAsFixed(2)),
      buyRate: effectiveBuyRate,
      sellRate: effectiveSellRate,
      birrSpreadPerUnit: double.parse(spread.toStringAsFixed(4)),
      birrProfitInBirr: double.parse(birrProfitInBirr.toStringAsFixed(2)),
      birrProfitInOriginal: double.parse(birrProfitInOriginal.toStringAsFixed(2)),
      outgoingTotalAmount: double.parse(outgoingTotalAmount.toStringAsFixed(2)),
      outgoingCommissionsTotal: double.parse(outgoingCommissionsTotal.toStringAsFixed(2)),
      netCashFlow: double.parse(netCashFlow.toStringAsFixed(2)),
      totalNetProfitInOriginal: double.parse(totalNetProfitInOriginal.toStringAsFixed(2)),
    );
  }
}
