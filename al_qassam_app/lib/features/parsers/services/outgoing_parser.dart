import 'package:uuid/uuid.dart';
import '../../financial_engine/domain/models/outgoing_transfer.dart';
import '../../financial_engine/domain/services/financial_engine.dart';
import 'whatsapp_parser.dart';

/// نتيجة تحليل واستخراج الحوالات الصادرة
class OutgoingParseResult {
  final List<OutgoingTransfer> records;
  final int duplicateCount;
  final String batchId;

  const OutgoingParseResult({
    required this.records,
    required this.duplicateCount,
    required this.batchId,
  });
}

/// محلل الحوالات الصادرة وشبكات الصرافة (OutgoingParser in Dart)
class OutgoingParser {
  /// تنظيف الرموز غير المرئية وعلامات الاتجاهية
  static String cleanInvisible(String? str) {
    if (str == null || str.isEmpty) return '';
    return str
        .replaceAll(
            RegExp(r'[\u200E\u200F\u202A-\u202E\u202F\u00A0\uFEFF]'), ' ')
        .trim();
  }

  /// تحليل نصوص الحوالات الصادرة بمختلف قوالبها
  static OutgoingParseResult parseOutgoingText({
    required String text,
    String? batchId,
    String? defaultCurrency,
    Set<String>? existingFingerprints,
  }) {
    if (text.trim().isEmpty) {
      return OutgoingParseResult(
        records: [],
        duplicateCount: 0,
        batchId: batchId ?? 'OUT-${const Uuid().v4().substring(0, 8)}',
      );
    }

    final effectiveBatchId =
        batchId ?? 'OUT-${const Uuid().v4().substring(0, 8)}';
    final records = <OutgoingTransfer>[];
    final seenFingerprints = <String>{};
    int duplicateCount = 0;

    final normalized = cleanInvisible(text.replaceAll('\r\n', '\n'));

    // 1. التجزئة الذكية للكتل (Blocks)
    final List<String> rawBlocks = [];
    final headerMatches = RegExp(
      r'(?:^|\n)(?:\[\d{1,4}[/\-.]\d{1,2}(?:[/\-.]\d{2,4})?,?[^\]]*\]|\b\d{1,4}[/\-.]\d{1,2}(?:[/\-.]\d{2,4})?,?[^-\n]*-)\s*[^:\n]+:\s*',
      caseSensitive: false,
      multiLine: true,
    ).allMatches(normalized).toList();

    if (headerMatches.isNotEmpty) {
      for (int i = 0; i < headerMatches.length; i++) {
        final start = headerMatches[i].end;
        final end = (i + 1 < headerMatches.length)
            ? headerMatches[i + 1].start
            : normalized.length;
        final content = normalized.substring(start, end).trim();
        if (content.isNotEmpty) rawBlocks.add(content);
      }
    } else if (RegExp(r'\b1000\d{6,12}\b').hasMatch(normalized)) {
      rawBlocks.addAll(WhatsAppParser.parseWhatsAppBubbles(normalized));
    } else {
      final splitRegex = RegExp(
        r'(?=(?:\*(?:\s*ارسال\s*حوال[ةه]\s*)\*|\(\s*ارسال\s*حوال[ةه]\s*\)|ارسال\s*حوال[ةه]|^المستلم\b|^[^\n=]{2,}=[\d,]+|(?:\n\s*[-_=*~]{3,}\s*\n)))',
        multiLine: true,
        caseSensitive: false,
      );
      final parts = normalized.split(splitRegex);
      for (final p in parts) {
        final trimmed = p.trim();
        if (trimmed.isNotEmpty) rawBlocks.add(trimmed);
      }
    }

    // تجزئة إضافية إذا كانت هناك عدة حوالات حوارية في نفس الكتلة (كل واحدة تحتوي على "المرسل")
    final List<String> blocks = [];
    for (final b in rawBlocks) {
      final lines = b.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final mersalIndices = <int>[];
      for (int i = 0; i < lines.length; i++) {
        if (RegExp(r'^\*?المرسل\*?\s*[:=\s]?.*$', caseSensitive: false).hasMatch(lines[i])) {
          mersalIndices.add(i);
        }
      }

      if (mersalIndices.length > 1) {
        for (int k = 0; k < mersalIndices.length; k++) {
          final mIdx = mersalIndices[k];
          final startIdx = (mIdx > 0 && (k == 0 || mIdx - 1 > mersalIndices[k - 1])) ? mIdx - 1 : mIdx;
          final nextStartIdx = (k + 1 < mersalIndices.length)
              ? (mersalIndices[k + 1] > 0 ? mersalIndices[k + 1] - 1 : mersalIndices[k + 1])
              : lines.length;
          final sub = lines.sublist(startIdx, nextStartIdx).join('\n');
          if (sub.trim().isNotEmpty) blocks.add(sub.trim());
        }
      } else {
        blocks.add(b);
      }
    }

    final today = DateTime.now();
    final todayStr =
        '${today.year}/${today.month.toString().padLeft(2, '0')}/${today.day.toString().padLeft(2, '0')}';

    for (final rawBlock in blocks) {
      String block = rawBlock.trim();
      if (block.isEmpty) continue;
      block = block.replaceFirst(RegExp(r'^[-_=*~]{3,}\s*'), '').trim();
      if (block.isEmpty) continue;

      // 1. قالب إشعار إرسال حوالة رسمي عبر شبكة صرافة (خصم وعمولة وشبكة أو حقول صريحة)
      if (RegExp(r'ارسال\s*حوال[ةه]|حوال[ةه]\s*صادرة|خصم\s*[\d,]+|سند\s*حوال[ةه]|رقم\s*الاشعار|رقم\s*الحوال[ةه]|شركة|شبكة',
              caseSensitive: false)
          .hasMatch(block)) {
        double amount = 0;
        String currency = 'ريال سعودي';
        String commission = '-';
        String network = '-';
        String transferNo = '-';
        String recipient = '';
        String sender = '';

        // استخراج الخصم والعمولة بنمط الإشعار المباشر
        final discountMatch = RegExp(
          r'خصم\s*([\d,]+(?:\.\d+)?)\s*\*?([^*\n\r]+?)\*?\s*عمول[ةه]\s*([\d,]+(?:\.\d+)?\s*[^\n\r]*)',
          caseSensitive: false,
        ).firstMatch(block);

        if (discountMatch != null) {
          amount = FinancialEngine.normalizeAmount(discountMatch.group(1));
          currency = FinancialEngine.normalizeCurrency(discountMatch.group(2));
          commission = discountMatch.group(3)?.trim() ?? '-';
        } else {
          final amtMatch = RegExp(
            r'خصم\s*([\d,]+(?:\.\d+)?)\s*\*?([^*\n\r]+?)\*?(?:\s|$)',
            caseSensitive: false,
          ).firstMatch(block);
          if (amtMatch != null) {
            amount = FinancialEngine.normalizeAmount(amtMatch.group(1));
            currency = FinancialEngine.normalizeCurrency(amtMatch.group(2));
          }
          final commMatch = RegExp(
            r'عمول[ةه]\s*([\d,]+(?:\.\d+)?\s*[^\n\r]*)',
            caseSensitive: false,
          ).firstMatch(block);
          if (commMatch != null) {
            commission = commMatch.group(1)?.trim() ?? '-';
          }
        }

        // في حال كان المبلغ مكتوباً كحقل صريح (المبلغ: 150000 ريال يمني)
        if (amount == 0) {
          final explicitAmt = RegExp(
            r'(?:المبلغ|مبلغ الحوالة)\s*:\s*([\d,]+(?:\.\d+)?)\s*([^\n\r]*)',
            caseSensitive: false,
          ).firstMatch(block);
          if (explicitAmt != null) {
            amount = FinancialEngine.normalizeAmount(explicitAmt.group(1));
            final currRaw = explicitAmt.group(2)?.trim() ?? '';
            if (currRaw.isNotEmpty) {
              currency = FinancialEngine.normalizeCurrency(currRaw);
            }
          }
        }

        // في حال كانت العمولة مكتوبة كحقل صريح (العمولة: 2500)
        if (commission == '-') {
          final explicitComm = RegExp(
            r'(?:العمول[ةه]|أجور الإرسال|اجور الارسال|أجور الحوالة|اجور الحوالة|الرسوم)\s*:\s*([^\n\r]+)',
            caseSensitive: false,
          ).firstMatch(block);
          if (explicitComm != null) {
            commission = explicitComm.group(1)!.trim();
          }
        }

        // استخراج اسم الشبكة
        final netMatch = RegExp(
          r'(?:حوال[ةه]\s*صادرة\s*)?(?:عبر\s*(?:الادارة|الإدارة|شبكة)?|(?:شبكة|شركة))\s*:\s*([^\n\r]+)',
          caseSensitive: false,
        ).firstMatch(block);
        if (netMatch != null) {
          network = netMatch.group(1)!.trim();
        } else {
          final firstLine = block.split('\n').first.trim();
          if (RegExp(r'(?:شبكة|شركة)\s+[^\n]+', caseSensitive: false).hasMatch(firstLine)) {
            network = firstLine.replaceAll(RegExp(r'[*_#]'), '').trim();
          }
        }

        // رقم الحوالة / المرجع
        final refMatch = RegExp(
          r'(?:رقم\s*الحوال[ةه]|رقم\s*الاشعار|رقم\s*العملي[ةه]|سند\s*حوال[ةه]\s*(?:صادر|رقم)?|المرجع)\s*:\s*([^\n\r]+)',
          caseSensitive: false,
        ).firstMatch(block);
        if (refMatch != null) {
          transferNo = refMatch.group(1)!.trim();
        }

        // المستلم / المستفيد
        final recMatch = RegExp(
          r'\*?(?:المستلم|المستفيد|اسم المستلم|اسم المستفيد)\*?\s*:\s*([^\n\r]+)',
          caseSensitive: false,
        ).firstMatch(block);
        if (recMatch != null) {
          recipient = recMatch.group(1)!.replaceAll('*', '').trim();
        }

        // المرسل
        final sndMatch = RegExp(
          r'\*?(?:المرسل|اسم المرسل)\*?\s*:\s*([^\n\r]+)',
          caseSensitive: false,
        ).firstMatch(block);
        if (sndMatch != null) {
          sender = sndMatch.group(1)!.replaceAll('*', '').trim();
        }

        if (recipient.isNotEmpty || sender.isNotEmpty || amount > 0) {
          final transfer = OutgoingTransfer(
            id: const Uuid().v4(),
            batchId: effectiveBatchId,
            recipient: recipient.isNotEmpty ? recipient : 'غير محدد',
            sender: sender.isNotEmpty ? sender : 'غير محدد',
            amount: amount,
            currency: currency,
            commission: commission,
            network: network,
            transferNo: transferNo,
            date: todayStr,
          );

          final fp = transfer.fingerprint;
          if (seenFingerprints.contains(fp) ||
              (existingFingerprints != null &&
                  existingFingerprints.contains(fp))) {
            duplicateCount++;
            continue;
          }

          seenFingerprints.add(fp);
          records.add(transfer);
          continue;
        }
      }

      // 2. قالب الحوالة الحوارية (الاسم الأول مستلم، ثم سطر المرسل، ثم المبلغ، ثم اسم الشبكة مثل دولار حزمي)
      if (RegExp(r'\*?المرسل\*?|حزمي|الحزمي|المستلم', caseSensitive: false).hasMatch(block)) {
        final lines = block
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !l.startsWith('---') && !l.startsWith('===') && !l.startsWith('***'))
            .toList();

        String recipient = '';
        String sender = '';
        double amount = 0;
        String currency = 'ريال سعودي';
        String network = '-';
        String commission = '-';
        String transferNo = '-';

        // 1. البحث عن مؤشر "المرسل"
        int senderLineIdx = -1;
        for (int i = 0; i < lines.length; i++) {
          final l = lines[i];
          if (RegExp(r'^\*?المرسل\*?\s*[:=]?\s*$', caseSensitive: false).hasMatch(l)) {
            senderLineIdx = i;
            if (i + 1 < lines.length) {
              sender = lines[i + 1].replaceAll('*', '').trim();
            }
            break;
          } else if (RegExp(r'^\*?المرسل\*?\s*[:=\s]\s*(.+)$', caseSensitive: false).hasMatch(l)) {
            final m = RegExp(r'^\*?المرسل\*?\s*[:=\s]\s*(.+)$', caseSensitive: false).firstMatch(l);
            sender = m?.group(1)?.replaceAll('*', '').trim() ?? '';
            senderLineIdx = i;
            break;
          }
        }

        // 2. البحث عن مؤشر "المستلم" أو "المستقبل" أو "المستفيد"
        for (int i = 0; i < lines.length; i++) {
          final l = lines[i];
          if (RegExp(r'^\*?(?:المستلم|المستفيد|المستقبل|اسم المستلم|اسم المستفيد|اسم المستقبل)\*?\s*[:=]?\s*$', caseSensitive: false).hasMatch(l)) {
            if (i + 1 < lines.length && !lines[i + 1].startsWith('المرسل')) {
              recipient = lines[i + 1].replaceAll('*', '').trim();
              break;
            }
          } else if (RegExp(r'^\*?(?:المستلم|المستفيد|المستقبل|اسم المستلم|اسم المستفيد|اسم المستقبل)\*?\s*[:=\s]\s*(.+)$', caseSensitive: false).hasMatch(l)) {
            final m = RegExp(r'^\*?(?:المستلم|المستفيد|المستقبل|اسم المستلم|اسم المستفيد|اسم المستقبل)\*?\s*[:=\s]\s*(.+)$', caseSensitive: false).firstMatch(l);
            recipient = m?.group(1)?.replaceAll('*', '').trim() ?? '';
            break;
          }
        }

        // 3. إذا لم يوجد مؤشر صريح للمستلم، استنتاجه من السياق
        if (recipient.isEmpty) {
          if (senderLineIdx > 0) {
            int recIdx = senderLineIdx - 1;
            if (RegExp(r'^\*?(?:المستلم|المستفيد|المستقبل)\*?\s*[:=]?\s*$', caseSensitive: false).hasMatch(lines[recIdx]) && recIdx > 0) {
              recIdx--;
            }
            recipient = lines[recIdx].replaceAll(RegExp(r'^\*?(?:المستلم|المستفيد|المستقبل)\*?\s*[:=]?\s*'), '').replaceAll('*', '').trim();
          } else {
            for (final l in lines) {
              if (l != sender && !l.startsWith('المرسل') && !RegExp(r'[\d$€£]').hasMatch(l)) {
                recipient = l.replaceAll(RegExp(r'^\*?(?:المستلم|المستفيد|المستقبل)\*?\s*[:=]?\s*'), '').replaceAll('*', '').trim();
                break;
              }
            }
          }
        }

        // تنظيف أية بادئات زائدة قد تكون علقت باسم المستلم
        recipient = recipient.replaceAll(RegExp(r'^\*?(?:المرسل|المستلم|المستقبل|المستفيد)\*?\s*[:=\s]*'), '').trim();

        // 3. استخراج المبلغ والعملة
        for (final l in lines) {
          if (l == sender || l == recipient || l == 'المرسل' || l.startsWith('المرسل:')) continue;

          final amtMatch = RegExp(
            r'\b([\d,]+(?:\.\d+)?)\s*([\$€£]|دولار\s*أمريكي|دولار|USD|ريال\s*سعودي|سعودي|SAR|ر\.س|ريال\s*يمني|يمني|YER|ريال|درهم|بر)?\b',
            caseSensitive: false,
          ).firstMatch(l);

          if (amtMatch != null) {
            final val = FinancialEngine.normalizeAmount(amtMatch.group(1));
            if (val > 0 && val < 100000000) {
              amount = val;
              final currRaw = amtMatch.group(2)?.trim() ?? '';
              if (currRaw.isNotEmpty) {
                currency = FinancialEngine.normalizeCurrency(currRaw);
              }
              break;
            }
          }
        }

        // 4. استخراج اسم الشبكة والعملة التوكيدية (مثل: دولار حزمي، أو حزمي، أو شبكة النجم)
        final networkRegex = RegExp(
          r'(?:حزمي|الحزمي|النجم|الامتياز|الأكوع|الاكوع|المحيط|بن هادي|داديه|يمن إكسبرس|يمن كاش|القطيبي|الكريمي|البسيري|المريسي|التضامن|الإنماء|الانماء|الصيفي|سبأ|الرويشان|الناصر|العمقي|شامل|العروي|الفرقان)',
          caseSensitive: false,
        );

        for (final l in lines) {
          if (l == sender || l == recipient) continue;

          final netMatch = networkRegex.firstMatch(l);
          if (netMatch != null) {
            network = netMatch.group(0)!;
            // فحص إذا كان السطر يحدد العملة أيضاً
            if (RegExp(r'(?:دولار|\$)', caseSensitive: false).hasMatch(l)) {
              currency = 'دولار أمريكي';
            } else if (RegExp(r'(?:سعودي|sar|ر\.س)', caseSensitive: false).hasMatch(l)) {
              currency = 'ريال سعودي';
            } else if (RegExp(r'(?:يمني|yer)', caseSensitive: false).hasMatch(l)) {
              currency = 'ريال يمني';
            }
            break;
          }
        }

        if (recipient.isNotEmpty && (amount > 0 || sender.isNotEmpty)) {
          final transfer = OutgoingTransfer(
            id: const Uuid().v4(),
            batchId: effectiveBatchId,
            recipient: recipient.isNotEmpty ? recipient : 'غير محدد',
            sender: sender.isNotEmpty ? sender : 'غير محدد',
            amount: amount,
            currency: currency,
            commission: commission,
            network: network,
            transferNo: transferNo,
            date: todayStr,
          );

          final fp = transfer.fingerprint;
          if (seenFingerprints.contains(fp) ||
              (existingFingerprints != null &&
                  existingFingerprints.contains(fp))) {
            duplicateCount++;
            continue;
          }

          seenFingerprints.add(fp);
          records.add(transfer);
          continue;
        }
      }

      // 3. قالب سطر الحوالة البسيط: الاسم = المبلغ (مثل: علي محمد = 5,000 ريال)
      final simpleMatch = RegExp(r'^([^\n=]+?)\s*=\s*([\d,]+(?:\.\d+)?)\s*([^\n]*)')
          .firstMatch(block);
      if (simpleMatch != null) {
        final recipient = simpleMatch.group(1)!.trim();
        final amount = FinancialEngine.normalizeAmount(simpleMatch.group(2));
        final currRaw = simpleMatch.group(3)?.trim();
        final currency = FinancialEngine.normalizeCurrency(currRaw);

        if (amount > 0 && recipient.isNotEmpty) {
          final transfer = OutgoingTransfer(
            id: const Uuid().v4(),
            batchId: effectiveBatchId,
            recipient: recipient,
            sender: 'عميل',
            amount: amount,
            currency: currency,
            date: todayStr,
          );

          final fp = transfer.fingerprint;
          if (seenFingerprints.contains(fp) ||
              (existingFingerprints != null &&
                  existingFingerprints.contains(fp))) {
            duplicateCount++;
            continue;
          }

          seenFingerprints.add(fp);
          records.add(transfer);
          continue;
        }
      }

      // 4. قالب الحوالة البنكية / CBE المباشرة (رقم حساب 1000 + مبلغ + اسم مستفيد)
      final cbeAccMatch = RegExp(r'\b(1000\d{6,12})\b').firstMatch(block);
      if (cbeAccMatch != null) {
        final accountNo = cbeAccMatch.group(1)!;
        final extraction = WhatsAppParser.parseAmountAndCurrency(block, accountNo);
        final amount = extraction?.amount ?? 0;
        final currency = extraction?.currency ?? defaultCurrency ?? 'بر إثيوبي';
        final recipient = WhatsAppParser.extractName(block, accountNo, amount);

        if ((recipient.isNotEmpty && recipient != 'مستفيد غير محدد') || amount > 0) {
          final transfer = OutgoingTransfer(
            id: const Uuid().v4(),
            batchId: effectiveBatchId,
            recipient: recipient.isNotEmpty ? recipient : 'غير محدد',
            sender: 'عميل',
            amount: amount,
            currency: currency,
            network: 'البنك التجاري الإثيوبي (CBE)',
            transferNo: accountNo,
            date: todayStr,
          );

          final fp = transfer.fingerprint;
          if (seenFingerprints.contains(fp) ||
              (existingFingerprints != null &&
                  existingFingerprints.contains(fp))) {
            duplicateCount++;
            continue;
          }

          seenFingerprints.add(fp);
          records.add(transfer);
          continue;
        }
      }
    }

    return OutgoingParseResult(
      records: records,
      duplicateCount: duplicateCount,
      batchId: effectiveBatchId,
    );
  }
}
