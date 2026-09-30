import '../../parsers/services/outgoing_parser.dart';
import '../../parsers/services/whatsapp_parser.dart';
import '../domain/models/template_rule.dart';

/// نتيجة اختبار أو مطابقة قالب على نص
class TemplateMatchResult {
  final bool isMatch;
  final String? beneficiary;
  final String? account;
  final String? phone;
  final double? amount;
  final String? currency;
  final String? network;
  final double? fee;
  final String? transferNumber;
  final String? rawMatchedText;
  final String? errorMessage;

  const TemplateMatchResult({
    required this.isMatch,
    this.beneficiary,
    this.account,
    this.phone,
    this.amount,
    this.currency,
    this.network,
    this.fee,
    this.transferNumber,
    this.rawMatchedText,
    this.errorMessage,
  });
}

/// محرك مطابقة واختبار القوالب الحية لنظام القسام
class TemplateMatcher {
  /// اختبار قالب على نص تجريبي لمعرفة ما إذا كان يطابقه واستخراج الحقول الحية
  static TemplateMatchResult testTemplate(TemplateRule rule, String text) {
    if (text.trim().isEmpty) {
      return const TemplateMatchResult(isMatch: false, errorMessage: 'النص التجريبي فارغ');
    }

    try {
      // 1. إذا كان القالب يستخدم تعبير نمطي مخصص (Regex)
      if (rule.strategy == ExtractionStrategy.customRegex &&
          rule.customRegex != null &&
          rule.customRegex!.isNotEmpty) {
        return _testCustomRegex(rule.customRegex!, text);
      }

      // 2. إذا كان القالب مخصص للحوالات الواردة (Incoming)
      if (rule.type == TemplateType.incoming) {
        return _testIncoming(rule, text);
      }

      // 3. إذا كان القالب مخصص للحوالات الصادرة والشبكات (Outgoing)
      if (rule.type == TemplateType.outgoing) {
        return _testOutgoing(rule, text);
      }

      return const TemplateMatchResult(isMatch: false, errorMessage: 'نوع القالب غير معروف');
    } catch (e) {
      return TemplateMatchResult(
        isMatch: false,
        errorMessage: 'خطأ أثناء المعالجة: ${e.toString()}',
      );
    }
  }

  static TemplateMatchResult _testIncoming(TemplateRule rule, String text) {
    final account = WhatsAppParser.extractAccount(text);
    final amtResult = WhatsAppParser.parseAmountAndCurrency(text, account);
    final name = WhatsAppParser.extractName(
      text,
      account,
      amtResult?.amount ?? 0.0,
    );

    // استخراج الهاتف إن وجد
    String? phone;
    final phoneMatch = RegExp(
      r'\b(?:\+?251|00251|251|09|07|\+?966|00966|05|\+?967|00967|7[01378])\d{7,12}\b',
    ).firstMatch(text);
    if (phoneMatch != null) {
      phone = phoneMatch.group(0);
    }

    final isMatched = (amtResult != null && amtResult.amount > 0) || account.isNotEmpty;

    return TemplateMatchResult(
      isMatch: isMatched,
      beneficiary: name != 'مستفيد غير محدد' ? name : null,
      account: account.isNotEmpty ? account : null,
      phone: phone,
      amount: amtResult?.amount,
      currency: amtResult?.currency ?? 'ريال سعودي',
      rawMatchedText: text.trim(),
    );
  }

  static TemplateMatchResult _testOutgoing(TemplateRule rule, String text) {
    final parseRes = OutgoingParser.parseOutgoingText(text: text);
    if (parseRes.records.isNotEmpty) {
      final first = parseRes.records.first;
      final parsedFee = double.tryParse(first.commission.replaceAll(RegExp(r'[^\d.]'), ''));
      return TemplateMatchResult(
        isMatch: true,
        beneficiary: first.recipient,
        network: first.network,
        amount: first.amount,
        currency: first.currency,
        fee: parsedFee,
        transferNumber: first.transferNo,
        rawMatchedText: text.trim(),
      );
    }

    return const TemplateMatchResult(
      isMatch: false,
      errorMessage: 'لم يتم العثور على مؤشرات شبكة أو بيانات حوالة صادرة صالحة في النص',
    );
  }

  static TemplateMatchResult _testCustomRegex(String pattern, String text) {
    final regex = RegExp(pattern, multiLine: true, caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match == null) {
      return const TemplateMatchResult(
        isMatch: false,
        errorMessage: 'النص لا يتطابق مع التعبير النمطي المحدد',
      );
    }

    // استخراج المجموعات المسماة أو الترتيبية
    String? name;
    String? account;
    String? phone;
    double? amount;

    try {
      name = match.namedGroup('name');
    } catch (_) {}

    try {
      account = match.namedGroup('account');
    } catch (_) {}

    try {
      phone = match.namedGroup('phone');
    } catch (_) {}

    try {
      final amtStr = match.namedGroup('amount');
      if (amtStr != null) {
        amount = double.tryParse(amtStr.replaceAll(',', ''));
      }
    } catch (_) {}

    // إذا لم تكن المجموعات مسماة، استخراج أول رقم كبير كحساب أو مبلغ
    if (account == null && match.groupCount >= 1) {
      name = match.group(1);
    }
    if (account == null && match.groupCount >= 2) {
      account = match.group(2);
    }
    if (amount == null && match.groupCount >= 3) {
      amount = double.tryParse(match.group(3)?.replaceAll(',', '') ?? '');
    }

    return TemplateMatchResult(
      isMatch: true,
      beneficiary: name,
      account: account,
      phone: phone,
      amount: amount,
      currency: 'ريال سعودي',
      rawMatchedText: match.group(0),
    );
  }
}
