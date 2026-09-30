import 'package:uuid/uuid.dart';
import '../../financial_engine/domain/models/incoming_remittance.dart';
import '../../financial_engine/domain/services/financial_engine.dart';

/// نتيجة تحليل واستخراج الحوالات
class ParseResult {
  final List<IncomingRemittance> records;
  final int duplicateCount;
  final String batchDate;
  final String batchId;

  const ParseResult({
    required this.records,
    required this.duplicateCount,
    required this.batchDate,
    required this.batchId,
  });
}

/// المحلل الذكي لرسائل الواتساب المالية لنظام القسام (WhatsAppParser in Dart)
class WhatsAppParser {
  static final RegExp _headerRegex = RegExp(
    r'(?:^|\n)(?:\[\d{1,4}[/\-.]\d{1,2}(?:[/\-.]\d{2,4})?,?[^\]]*\]|\b\d{1,4}[/\-.]\d{1,2}(?:[/\-.]\d{2,4})?,?[^-\n]*-)\s*[^:\n]+:\s*',
    caseSensitive: false,
    multiLine: true,
  );

  /// فحص هل النص يمثل رقم هاتف (إثيوبي: 00251.. أو 09.. أو 07.. أو خليجي/يمني)
  static bool isPhoneNumber(String str) {
    final clean = str.trim().replaceAll(RegExp(r'[\s\-+()]'), '');
    if (clean.isEmpty) return false;
    // هاتف إثيوبي دولي أو محلي (00251... / +251... / 251... / 09... / 07...)
    if (RegExp(r'^(?:00251|251|09|07)\d{7,10}$').hasMatch(clean)) return true;
    // هاتف سعودي (00966... / 966... / 05...)
    if (RegExp(r'^(?:00966|966|05)\d{8,9}$').hasMatch(clean)) return true;
    // هاتف يمني (00967... / 967... / 77... / 73... / 71... / 70...)
    if (RegExp(r'^(?:00967|967|7[01378])\d{7,8}$').hasMatch(clean)) return true;
    return false;
  }

  /// استخراج رقم الحساب المصرفي بدقة مع استبعاد أرقام الهواتف
  static String extractAccount(String text) {
    // 1. الأولوية لحساب البنك التجاري الإثيوبي (CBE) 1000...
    final cbeMatch = RegExp(r'\b(1000\d{6,12})\b').firstMatch(text);
    if (cbeMatch != null) return cbeMatch.group(1)!;

    // 2. فحص أي رقم 10-16 خانة مع التأكد التام من أنه ليس رقم هاتف
    final matches = RegExp(r'\b(\d{10,16})\b').allMatches(text);
    for (final m in matches) {
      final cand = m.group(1)!;
      if (!isPhoneNumber(cand)) {
        return cand;
      }
    }
    return '';
  }

  /// تنظيف الرموز غير المرئية وعلامات الاتجاهية
  static String cleanInvisible(String? str) {
    if (str == null || str.isEmpty) return '';
    return str
        .replaceAll(
            RegExp(r'[\u200E\u200F\u202A-\u202E\u202F\u00A0\uFEFF]'), ' ')
        .trim();
  }

  /// استخراج التاريخ من رأس النص أو اعتماد التاريخ الحالي
  static String extractDate(String text) {
    final cleaned = cleanInvisible(text);
    final match = RegExp(r'\b(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})\b')
        .firstMatch(cleaned);
    if (match != null) {
      return match.group(1)!;
    }
    final now = DateTime.now();
    return '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
  }

  /// تجزئة النص إلى فقاعات رسائل منفصلة مع دعم التجزئة الذكية للبلوكات المركبة
  /// فحص هل السطر يمثل اسماً لمستفيد (أحرف، وليس رقماً ولا هاتفاً ولا كلمة مفتاحية)
  static bool isNameLine(String line) {
    final clean = cleanInvisible(line).trim();
    if (clean.isEmpty) return false;
    if (isPhoneNumber(clean)) return false;
    if (RegExp(r'^[\d,\s.\-:]+$').hasMatch(clean)) return false;
    if (RegExp(r'^(?:حساب|رقم|المبلغ|الحساب|amount|acc|account)\b',
            caseSensitive: false)
        .hasMatch(clean)) {
      return false;
    }
    return RegExp(r'[\p{L}]{3,}', unicode: true).hasMatch(clean);
  }

  /// تجزئة النص إلى فقاعات رسائل منفصلة مع دعم التجزئة الذكية للبلوكات المركبة والقوالب المتباعدة
  static List<String> parseWhatsAppBubbles(String text) {
    String rawClean = cleanInvisible(text);

    // 1. استبعاد أسطر المجاميع الختامية (مثل total=227,620 أو المجموع: ...)
    rawClean = rawClean.replaceAll(
      RegExp(r'^\s*(?:total|المجموع|الإجمالي|الصافي|التقرير)\s*[:=].*$',
          caseSensitive: false, multiLine: true),
      '',
    );

    // 2. تحويل خطوط الفواصل النجمية أو الشرطات إلى فواصل فقرات
    rawClean = rawClean.replaceAll(
      RegExp(r'\n\s*[*_\-=~]{3,}\s*(?=\n|$)', multiLine: true),
      '\n\n',
    );

    final List<String> rawBubbles = [];
    final matches = _headerRegex.allMatches(rawClean).toList();

    if (matches.isNotEmpty) {
      for (int i = 0; i < matches.length; i++) {
        final start = matches[i].end;
        final end = (i + 1 < matches.length)
            ? matches[i + 1].start
            : rawClean.length;
        final content = rawClean.substring(start, end).trim();
        if (content.isNotEmpty) rawBubbles.add(content);
      }
    } else {
      // النص لا يحتوي على رؤوس واتساب (لصق يدوي أو رسائل مفردة/مركبة)
      final allLines = rawClean
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final cbePattern = RegExp(r'\b1000\d{6,12}\b');
      final accountLineIndices = <int>[];
      for (int i = 0; i < allLines.length; i++) {
        if (cbePattern.hasMatch(allLines[i])) {
          accountLineIndices.add(i);
        }
      }

      // إذا كان النص يحتوي على حساب واحد فقط أو أقل، فكامل النص يمثل حوالة واحدة بأسطرها المتباعدة
      if (accountLineIndices.length <= 1) {
        if (accountLineIndices.length == 1) {
          return [allLines.join('\n')];
        }
        final parts = rawClean
            .split(RegExp(r'\n\s*\n'))
            .map((b) => b.trim())
            .where((b) => b.isNotEmpty);
        return parts.toList();
      }

      // توجد عدة حسابات CBE في النص
      final splitIndices = <int>[0];
      for (int k = 1; k < accountLineIndices.length; k++) {
        final prevAccIdx = accountLineIndices[k - 1];
        final currAccIdx = accountLineIndices[k];

        // هل الحوالة السابقة k-1 كان اسمها قبل حسابها؟
        final prevStartIdx = splitIndices[k - 1];
        bool prevHadNameBefore = false;
        for (int i = prevStartIdx; i < prevAccIdx; i++) {
          if (isNameLine(allLines[i])) {
            prevHadNameBefore = true;
            break;
          }
        }

        int startIdx = currAccIdx;
        if (prevHadNameBefore) {
          // الحوالة الحالية k اسمها قبل حسابها
          if (currAccIdx - 1 > prevAccIdx && isNameLine(allLines[currAccIdx - 1])) {
            startIdx = currAccIdx - 1;
          }
        } else {
          // الحوالة السابقة اسمها بعد حسابها، فالحوالة k تبدأ من حسابها
          startIdx = currAccIdx;
        }
        splitIndices.add(startIdx);
      }

      final List<String> bubbles = [];
      for (int s = 0; s < splitIndices.length; s++) {
        final start = splitIndices[s];
        final end = (s + 1 < splitIndices.length)
            ? splitIndices[s + 1]
            : allLines.length;
        final subLines = allLines.sublist(start, end);
        if (subLines.isNotEmpty) {
          bubbles.add(subLines.join('\n'));
        }
      }
      return bubbles;
    }

    // معالجة الفقاعات المستخرجة من رؤوس الواتساب
    final List<String> bubbles = [];
    final cbePattern = RegExp(r'\b1000\d{6,12}\b');

    for (final block in rawBubbles) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final accountLineIndices = <int>[];
      for (int i = 0; i < lines.length; i++) {
        if (cbePattern.hasMatch(lines[i])) {
          accountLineIndices.add(i);
        }
      }

      if (accountLineIndices.length <= 1) {
        bubbles.add(block);
        continue;
      }

      final splitIndices = <int>[0];
      for (int k = 1; k < accountLineIndices.length; k++) {
        final prevAccIdx = accountLineIndices[k - 1];
        final currAccIdx = accountLineIndices[k];

        final prevStartIdx = splitIndices[k - 1];
        bool prevHadNameBefore = false;
        for (int i = prevStartIdx; i < prevAccIdx; i++) {
          if (isNameLine(lines[i])) {
            prevHadNameBefore = true;
            break;
          }
        }

        int startIdx = currAccIdx;
        if (prevHadNameBefore) {
          if (currAccIdx - 1 > prevAccIdx && isNameLine(lines[currAccIdx - 1])) {
            startIdx = currAccIdx - 1;
          }
        } else {
          startIdx = currAccIdx;
        }
        splitIndices.add(startIdx);
      }

      for (int s = 0; s < splitIndices.length; s++) {
        final start = splitIndices[s];
        final end = (s + 1 < splitIndices.length)
            ? splitIndices[s + 1]
            : lines.length;
        final subLines = lines.sublist(start, end);
        if (subLines.isNotEmpty) {
          bubbles.add(subLines.join('\n'));
        }
      }
    }

    return bubbles;
  }

  /// استخراج المبلغ والعملة بدقة متقدمة مع تحصين كامل ضد أرقام الهواتف والحسابات
  static ({double amount, String currency})? parseAmountAndCurrency(
    String bubbleText, [
    String account = '',
  ]) {
    String cleaned = cleanInvisible(bubbleText);
    if (account.isNotEmpty) {
      cleaned = cleaned.replaceAll(account, ' ');
    }

    // إزالة أرقام الهواتف الصريحة أولاً لضمان عدم التقاطها كمبالغ إطلاقاً
    final phoneMatches = RegExp(
            r'\b(?:\+?251|00251|251|09|07|\+?966|00966|05|\+?967|00967|7[01378])\d{7,12}\b')
        .allMatches(cleaned);
    for (final pm in phoneMatches) {
      cleaned = cleaned.replaceAll(pm.group(0)!, ' ');
    }

    // 1. فحص الملايين: 10 مليون بر / 2.5 مليون
    final millionMatch = RegExp(
      r'([\d,]+(?:\.\d+)?)\s*(?:مليون|ملايين|مليوناً)\s*([^\n\r,.]*)',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (millionMatch != null) {
      final base = FinancialEngine.normalizeAmount(millionMatch.group(1));
      final currRaw = millionMatch.group(2)?.trim() ?? '';
      final curr = FinancialEngine.normalizeCurrency(
          currRaw.isNotEmpty ? currRaw : 'بر إثيوبي');
      return (amount: base * 1000000, currency: curr);
    }

    // 2. فحص الأنماط الصريحة: رقم + عملة (مثل: 2,500 ريال / 3000 SAR / 10000 بر)
    final explicitMatch = RegExp(
      r'([\d,]+(?:\.\d+)?)\s*(ريال\s*سعودي|ريال\s*سعود|ريال|ر\.?س|سعودي|سعود|SAR|بر\s*إثيوبي|بر|ETB|birr|دولار|دولار\s*أمريكي|USD|\$)',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (explicitMatch != null) {
      final amt = FinancialEngine.normalizeAmount(explicitMatch.group(1));
      if (amt > 0) {
        final curr =
            FinancialEngine.normalizeCurrency(explicitMatch.group(2));
        return (amount: amt, currency: curr);
      }
    }

    // 3. فحص نمط المساواة: مثل Name = 500 أو = 1490 SAR
    final equalMatch = RegExp(r'=\s*([\d,]+(?:\.\d+)?)\s*([^\n\r,.]*)').firstMatch(cleaned);
    if (equalMatch != null) {
      final amt = FinancialEngine.normalizeAmount(equalMatch.group(1));
      if (amt > 0) {
        final rawCurr = equalMatch.group(2)?.trim() ?? '';
        final curr = rawCurr.isNotEmpty ? FinancialEngine.normalizeCurrency(rawCurr) : 'ريال سعودي';
        return (amount: amt, currency: curr);
      }
    }

    // 4. فحص الأسطر المنفصلة التي تحتوي على أرقام فقط (المبالغ المجردة)
    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (final line in lines) {
      if (isPhoneNumber(line)) continue;
      if (line == account) continue;

      // سطر يحتوي على رقم فقط (وليس رقم حساب طويل ولا هاتف)
      if (RegExp(r'^[\d,]+(?:\.\d+)?$').hasMatch(line)) {
        final val = FinancialEngine.normalizeAmount(line);
        if (val > 0 && val < 10000000) {
          // استنتاج العملة من سياق الفقاعة
          String curr = 'ريال سعودي';
          if (RegExp(r'(?:بر|birr|etb)', caseSensitive: false)
              .hasMatch(cleaned)) {
            curr = 'بر إثيوبي';
          } else if (RegExp(r'(?:دولار|usd|\$)', caseSensitive: false)
              .hasMatch(cleaned)) {
            curr = 'دولار أمريكي';
          }
          return (amount: val, currency: curr);
        }
      }
    }

    // 4. استخراج عام كملجأ أخير
    final generalMatches = RegExp(r'([\d,]+(?:\.\d+)?)').allMatches(cleaned);
    for (final m in generalMatches) {
      final raw = m.group(1);
      if (raw == null) continue;
      if (isPhoneNumber(raw)) continue;
      final val = FinancialEngine.normalizeAmount(raw);
      if (val > 0 &&
          val < 10000000 &&
          val != FinancialEngine.normalizeAmount(account)) {
        return (amount: val, currency: 'ريال سعودي');
      }
    }

    return null;
  }

  /// استخراج اسم المستفيد مع استبعاد الأرقام والرموز وأرقام الهواتف
  static String extractName(String bubbleText, String account, double amount) {
    String cleaned = cleanInvisible(bubbleText);
    if (account.isNotEmpty) cleaned = cleaned.replaceAll(account, ' ');

    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (final line in lines) {
      // إزالة الترقيم الترتيبي مثل 1- أو 1.
      String candidate =
          line.replaceFirst(RegExp(r'^\d+[\s.\-)]+\s*'), '').trim();
      if (candidate.isEmpty) continue;

      // إزالة بادئات ولواحق المستفيد الشائعة (مثل: المستلم:، اسم المستفيد:، :المستلم)
      candidate = candidate
          .replaceAll(
            RegExp(
              r'^\*?(?:اسم\s*المستفيد|اسم\s*المستلم|اسم\s*العميل|المستفيد|المستلم|العميل|الاسم|إلى|إلي|to|name|beneficiary|recipient)\*?\s*[:=؛\-/]?\s*',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'\s*[:=؛\-/]?\s*\*?(?:اسم\s*المستفيد|اسم\s*المستلم|اسم\s*العميل|المستفيد|المستلم|العميل|الاسم|إلى|إلي|to|name|beneficiary|recipient)\*?$',
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      // معالجة علامة المساواة إذا كان الاسم مقروناً بالمبلغ مثل: TEAME TESFAY = 500
      if (candidate.contains('=')) {
        candidate = candidate.split('=')[0].trim();
      }

      // إزالة رقم المبلغ إن وُجد في نفس سطر الاسم
      if (amount > 0) {
        candidate = candidate.replaceAll(amount.toInt().toString(), ' ').trim();
      }

      if (candidate.isEmpty) continue;

      // استبعاد الأسطر الرقمية البحتة
      if (RegExp(r'^[\d,\s.\-:]+$').hasMatch(candidate)) continue;

      // استبعاد أرقام الهواتف وكلمات الاتصال
      if (isPhoneNumber(candidate)) continue;
      if (RegExp(r'(?:هاتف|جوال|تلفون|phone|tel|mob)', caseSensitive: false)
          .hasMatch(candidate)) {
        continue;
      }

      // استبعاد أسطر الكلمات المفتاحية
      if (RegExp(r'^(حساب|رقم|المبلغ|الحساب|amount|acc|account)\b',
              caseSensitive: false)
          .hasMatch(candidate)) {
        continue;
      }

      // إذا كان يحتوي على حروف اسم معتبرة
      if (RegExp(r'[\p{L}]{3,}', unicode: true).hasMatch(candidate)) {
        // تنظيف العملة من سطر الاسم إن وجدت
        candidate = candidate
            .replaceAll(
                RegExp(r'\s*(?:ريال\s*سعودي|ريال\s*سعود|ريال|سعودي|سعود|بر\s*إثيوبي|بر|birr|etb|دولار|usd|\$)\s*',
                    caseSensitive: false),
                ' ')
            .trim();
        if (candidate.isNotEmpty) return candidate;
      }
    }

    return 'مستفيد غير محدد';
  }

  /// التحليل الكامل واستخراج السجلات مع استبعاد التكرارات (Deduplication)
  static ParseResult extractRecords({
    required String text,
    required double exchangeRate,
    String? batchId,
    Set<String>? existingFingerprints,
  }) {
    final effectiveBatchId =
        batchId ?? 'BATCH-${const Uuid().v4().substring(0, 8)}';
    final date = extractDate(text);
    final bubbles = parseWhatsAppBubbles(text);

    final List<IncomingRemittance> records = [];
    final Set<String> seenInThisBatch = {};
    int duplicateCount = 0;
    int seq = 1;

    for (final bubble in bubbles) {
      // 1. استخراج رقم الحساب المصرفي (الأولوية لـ 1000... مع استبعاد أرقام الهواتف)
      final account = extractAccount(bubble);

      // 2. استخراج المبلغ والعملة
      final parsedAmount = parseAmountAndCurrency(bubble, account);
      final amount = parsedAmount?.amount ?? 0.0;
      final currency = parsedAmount?.currency ?? 'ريال سعودي';

      // 3. استخراج الاسم
      final name = extractName(bubble, account, amount);

      if (amount > 0) {
        // حساب المقابل بالبر
        final birrResult = FinancialEngine.calculateBirr(
          amount,
          exchangeRate,
          currency,
        );

        final remittance = IncomingRemittance(
          id: const Uuid().v4(),
          batchId: effectiveBatchId,
          seq: seq,
          date: date,
          name: name,
          account: account.isNotEmpty ? account : '-',
          amount: amount,
          currency: currency,
          rate: exchangeRate,
          birrEquivalent: birrResult.birrEquivalent,
          cutCents: birrResult.cutCents,
        );

        final fp = remittance.fingerprint;

        // فحص التكرار: محلياً ضمن الدفعة أو في قاعدة البيانات المحلية السابقة
        if (seenInThisBatch.contains(fp) ||
            (existingFingerprints != null &&
                existingFingerprints.contains(fp))) {
          duplicateCount++;
          continue; // منع تكرار الحوالة!
        }

        seenInThisBatch.add(fp);
        records.add(remittance);
        seq++;
      }
    }

    return ParseResult(
      records: records,
      duplicateCount: duplicateCount,
      batchDate: date,
      batchId: effectiveBatchId,
    );
  }
}

extension _ListExt<T> on List<T> {
  void pushIfValid(T item) {
    if (item != null) add(item);
  }
}
