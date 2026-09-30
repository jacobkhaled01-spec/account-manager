import 'package:flutter_test/flutter_test.dart';
import 'package:al_qassam_app/features/financial_engine/domain/services/financial_engine.dart';
import 'package:al_qassam_app/features/financial_engine/domain/models/incoming_remittance.dart';
import 'package:al_qassam_app/features/parsers/services/whatsapp_parser.dart';
import 'package:al_qassam_app/features/parsers/services/outgoing_parser.dart';
import 'package:al_qassam_app/features/reports_export/services/report_formatter.dart';

void main() {
  group('FinancialEngine Tests', () {
    test('calculateBirr should truncate to hundreds and calculate cut cents', () {
      // 2500 * 48 = 120,000
      final res1 = FinancialEngine.calculateBirr(2500, 48, 'ريال سعودي');
      expect(res1.birrEquivalent, 120000.0);
      expect(res1.cutCents, 0.0);

      // 123.45 * 48 = 5925.6 -> Truncated to hundreds: 5900, cut cents: 25.6
      final res2 = FinancialEngine.calculateBirr(123.45, 48, 'ريال سعودي');
      expect(res2.birrEquivalent, 5900.0);
      expect(res2.cutCents, 25.6);
    });

    test('isBirr should correctly identify Birr currency variants', () {
      expect(FinancialEngine.isBirr('بر'), isTrue);
      expect(FinancialEngine.isBirr('بر إثيوبي'), isTrue);
      expect(FinancialEngine.isBirr('ETB'), isTrue);
      expect(FinancialEngine.isBirr('birr'), isTrue);
      expect(FinancialEngine.isBirr('ريال'), isFalse);
    });
  });

  group('WhatsAppParser & Deduplication Tests', () {
    test('extractRecords should parse all permutations and deduplicate', () {
      const sampleText = '''
[1/13/18, 10:00 AM] Client: TEAME TESFAY
100012345678
500 SAR

[1/13/18, 10:01 AM] Client: 100087654321
AHMED ALI
1000 ريال

[1/13/18, 10:02 AM] Client: 2500 ريال
100099998888
SALEM SAEED

[1/13/18, 10:03 AM] Client: TEAME TESFAY
100012345678
500 SAR
''';

      final result = WhatsAppParser.extractRecords(
        text: sampleText,
        exchangeRate: 48,
        batchId: 'TEST-BATCH-1',
      );

      // 4 bubbles, but 1 is exact duplicate of TEAME TESFAY -> 3 records, 1 duplicate
      expect(result.records.length, 3);
      expect(result.duplicateCount, 1);
      expect(result.records[0].name, 'TEAME TESFAY');
      expect(result.records[0].account, '100012345678');
      expect(result.records[0].amount, 500.0);
      expect(result.records[0].birrEquivalent, 24000.0);
    });

    test('extractRecords should parse template with phone number', () {
      const sample = '''
he mahar atsbaha
1000832605746
00251914740800
400
''';
      final result = WhatsAppParser.extractRecords(
        text: sample,
        exchangeRate: 48,
        batchId: 'PHONE-TEST',
      );

      expect(result.records.length, 1);
      final rec = result.records.first;
      expect(rec.name, 'he mahar atsbaha');
      expect(rec.account, '1000832605746');
      expect(rec.amount, 400.0);
    });

    test('extractRecords should parse account-first spaced template with blank lines (1000... / amount / name)', () {
      const sample = '''
1000733766097

8950

aferyeme djana
''';
      final result = WhatsAppParser.extractRecords(
        text: sample,
        exchangeRate: 48,
        batchId: 'SPACED-TEST',
      );

      expect(result.records.length, 1);
      expect(result.duplicateCount, 0);
      final rec = result.records.first;
      expect(rec.account, '1000733766097');
      expect(rec.amount, 8950.0);
      expect(rec.name, 'aferyeme djana');
      expect(rec.birrEquivalent, 8950.0 * 48);
    });

    test('extractRecords should parse multiple phone template records without blank lines', () {
      const sample = '''
he mahar atsbaha
1000832605746
00251914740800
400
tesfay berhe
1000123456789
00251912345678
500
''';
      final result = WhatsAppParser.extractRecords(
        text: sample,
        exchangeRate: 48,
        batchId: 'MULTI-PHONE-TEST',
      );

      expect(result.records.length, 2);
      expect(result.records[0].name, 'he mahar atsbaha');
      expect(result.records[0].account, '1000832605746');
      expect(result.records[0].amount, 400.0);
      expect(result.records[1].name, 'tesfay berhe');
      expect(result.records[1].account, '1000123456789');
      expect(result.records[1].amount, 500.0);
    });

    test('extractRecords should parse equal sign template (Ethiopian format)', () {
      const sample = '''
TEAME TESFAY HAGOS=1490
1000181711713

1- Mohammed Ali = 500 SAR
100012345678
''';
      final result = WhatsAppParser.extractRecords(
        text: sample,
        exchangeRate: 48,
        batchId: 'EQUAL-TEST',
      );

      expect(result.records.length, 2);
      expect(result.records[0].name, 'TEAME TESFAY HAGOS');
      expect(result.records[0].amount, 1490.0);
      expect(result.records[0].account, '1000181711713');
      expect(result.records[1].name, 'Mohammed Ali');
      expect(result.records[1].amount, 500.0);
      expect(result.records[1].account, '100012345678');
    });

    test('extractRecords should parse single-line combo template', () {
      const sample = '''
TEAME TESFAY 1000181711713 4975
''';
      final result = WhatsAppParser.extractRecords(
        text: sample,
        exchangeRate: 48,
        batchId: 'SINGLE-LINE-TEST',
      );

      expect(result.records.length, 1);
      expect(result.records[0].name, 'TEAME TESFAY');
      expect(result.records[0].account, '1000181711713');
      expect(result.records[0].amount, 4975.0);
    });

    test('extractRecords should parse million pattern', () {
      const sample = '''
أحمد علي سالم
1000554433221
2.5 مليون بر
''';
      final result = WhatsAppParser.extractRecords(
        text: sample,
        exchangeRate: 48,
        batchId: 'MILLION-TEST',
      );

      expect(result.records.length, 1);
      expect(result.records[0].name, 'أحمد علي سالم');
      expect(result.records[0].account, '1000554433221');
      expect(result.records[0].amount, 2500000.0);
      expect(result.records[0].currency, 'بر إثيوبي');
      expect(result.records[0].birrEquivalent, 2500000.0);
    });
  });

  group('OutgoingParser Tests', () {
    test('parseOutgoingText should extract network transfers', () {
      const sampleText = '''
*(ارسال حوالة)*
عبر الادارة: شبكة الأكوع
رقم الاشعار: 987654
المستلم: علي حسن العامري
المرسل: شركة القسام للصرافة
خصم 3,000 ريال سعودي عمولة 150 ريال
''';

      final res = OutgoingParser.parseOutgoingText(text: sampleText);
      expect(res.records.length, 1);
      expect(res.records[0].recipient, 'علي حسن العامري');
      expect(res.records[0].amount, 3000.0);
      expect(res.records[0].commission, '150 ريال');
      expect(res.records[0].network, 'شبكة الأكوع');
      expect(res.records[0].transferNo, '987654');
    });

    test('parseOutgoingText should extract conversational transfer (Hazmi template)', () {
      const sampleText = '''
محمد عبدالله احمد الزبيري 
المرسل
هشام محمد عبدالوهاب الزبيري
59 \$

دولار حزمي
''';

      final res = OutgoingParser.parseOutgoingText(text: sampleText);
      expect(res.records.length, 1);
      expect(res.records[0].recipient, 'محمد عبدالله احمد الزبيري');
      expect(res.records[0].sender, 'هشام محمد عبدالوهاب الزبيري');
      expect(res.records[0].amount, 59.0);
      expect(res.records[0].currency, 'دولار أمريكي');
      expect(res.records[0].network, 'حزمي');
    });

    test('parseOutgoingText should extract spaced CBE account transfer', () {
      const sampleText = '''
1000733766097

8950

aferyeme djana
''';

      final res = OutgoingParser.parseOutgoingText(text: sampleText);
      expect(res.records.length, 1);
      expect(res.records[0].recipient, 'aferyeme djana');
      expect(res.records[0].amount, 8950.0);
      expect(res.records[0].transferNo, '1000733766097');
      expect(res.records[0].network, 'البنك التجاري الإثيوبي (CBE)');
    });
  });

  group('ReportFormatter Tests', () {
    test('formatBirrReport should format independent batch Birr message', () {
      final res = WhatsAppParser.extractRecords(
        text: 'MOHAMMED\n100011223344\n1000 ريال',
        exchangeRate: 48,
        batchId: 'BATCH-X',
      );

      final birrMsg = ReportFormatter.formatBirrReport(res.records, includeTotals: false);
      expect(birrMsg, contains('MOHAMMED'));
      expect(birrMsg, contains('100011223344'));
      expect(birrMsg, contains('48,000 birr'));
    });

    test('formatSingleBirrMessage should format single remittance accurately', () {
      final res = WhatsAppParser.extractRecords(
        text: '1000733766097\n8950\naferyeme djana',
        exchangeRate: 48,
        batchId: 'BATCH-SINGLE',
      );
      expect(res.records.length, 1);
      final singleMsg = ReportFormatter.formatSingleBirrMessage(res.records.first);
      expect(singleMsg, 'aferyeme djana\n1000733766097\n429,600 birr');
    });

    test('formatSingleOutgoingTransfer and formatOutgoingListMessage test', () {
      final outRes = OutgoingParser.parseOutgoingText(
        text: 'محمد الزبيري = 1000 ريال',
      );
      expect(outRes.records.length, 1);
      final singleOut = ReportFormatter.formatSingleOutgoingTransfer(outRes.records.first);
      expect(singleOut, contains('المستلم: محمد الزبيري'));
      expect(singleOut, contains('1,000'));
      expect(singleOut, contains('ريال سعودي'));

      final listOut = ReportFormatter.formatOutgoingListMessage(outRes.records);
      expect(listOut, contains('المستلم: محمد الزبيري'));
    });
  });

  group('CombinedProfitReport & Reconciliation Tests', () {
    test('parseCommissionAmount should extract numeric value reliably', () {
      expect(FinancialEngine.parseCommissionAmount('25 ريال'), 25.0);
      expect(FinancialEngine.parseCommissionAmount('50.50'), 50.5);
      expect(FinancialEngine.parseCommissionAmount('عمولة 100 ر.س'), 100.0);
      expect(FinancialEngine.parseCommissionAmount('-'), 0.0);
      expect(FinancialEngine.parseCommissionAmount(''), 0.0);
      expect(FinancialEngine.parseCommissionAmount(null), 0.0);
    });

    test('calculateCombinedProfitReport should calculate Birr FX profit and outgoing commissions accurately', () {
      // 1 Incoming transfer: 1,000 SAR at sellRate 48 -> 48,000 Birr
      final inResult = WhatsAppParser.extractRecords(
        text: '100012345678\n1000 ريال\nAHMED ALI',
        exchangeRate: 48,
        batchId: 'BATCH-PROFIT-TEST',
      );
      expect(inResult.records.length, 1);
      expect(inResult.records.first.birrEquivalent, 48000.0);

      // 1 Outgoing transfer: 200 SAR with 15 SAR commission
      final outResult = OutgoingParser.parseOutgoingText(
        text: '''
شبكة الأكوع
حوالة رقم: 12345
المستلم: علي حسن
المرسل: مكتب القسام
خصم 200 ريال سعودي عمولة 15 ريال
''',
      );
      expect(outResult.records.length, 1);
      expect(outResult.records.first.amount, 200.0);
      expect(outResult.records.first.commission, '15 ريال');

      // Calculate combined report: BuyRate = 50.0, SellRate = 48.0
      final report = FinancialEngine.calculateCombinedProfitReport(
        incoming: inResult.records,
        outgoing: outResult.records,
        buyRate: 50.0,
        sellRate: 48.0,
      );

      // Birr profit:
      // Received 1,000 SAR, disbursed 48,000 Birr.
      // Cost to buy 48,000 Birr at 50 = 960 SAR.
      // Profit in SAR = 1000 - 960 = 40 SAR.
      // Profit in Birr = 40 * 50 = 2,000 Birr.
      expect(report.birrSpreadPerUnit, 2.0);
      expect(report.birrProfitInOriginal, 40.0);
      expect(report.birrProfitInBirr, 2000.0);

      // Outgoing commission = 15 SAR
      expect(report.outgoingCommissionsTotal, 15.0);

      // Total net profit = 40 + 15 = 55 SAR
      expect(report.totalNetProfitInOriginal, 55.0);

      // Net cash flow = 1,000 - 200 = 800 SAR
      expect(report.netCashFlow, 800.0);

      // Format report for WhatsApp
      final formatted = ReportFormatter.formatCombinedProfitReport(
        report,
        bureauName: 'مكتب القسام للصرافة والتحويلات',
        dateLabel: '2026/09/27',
      );

      expect(formatted, contains('تقرير الأرباح والمطابقة المالية الشاملة'));
      expect(formatted, contains('سعر الشراء: 50.00'));
      expect(formatted, contains('سعر البيع: 48.00'));
      expect(formatted, contains('+40.00 ريال'));
      expect(formatted, contains('+15.00 ريال'));
      expect(formatted, contains('55.00 ريال سعودي'));
      expect(formatted, contains('800.00 ريال سعودي'));

      // Verify that NO emojis or informal stickers are in the output
      expect(formatted.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true)), isFalse);
    });

    test('calculateTotals respects custom large remittance threshold', () {
      final r1 = IncomingRemittance(
        id: '1',
        batchId: 'B1',
        seq: 1,
        date: '2026/09/27',
        name: 'A',
        account: '10001',
        amount: 1500,
        rate: 50,
        birrEquivalent: 75000,
      );
      final r2 = IncomingRemittance(
        id: '2',
        batchId: 'B1',
        seq: 2,
        date: '2026/09/27',
        name: 'B',
        account: '10002',
        amount: 3000,
        rate: 50,
        birrEquivalent: 150000,
      );

      // Default threshold (100,000): r1 is small, r2 is large
      final defaultTotals = FinancialEngine.calculateTotals([r1, r2]);
      expect(defaultTotals.smallCount, 1);
      expect(defaultTotals.largeCount, 1);

      // Custom threshold = 50,000: both are large
      final customTotals50k = FinancialEngine.calculateTotals([r1, r2], 50000);
      expect(customTotals50k.smallCount, 0);
      expect(customTotals50k.largeCount, 2);

      // Custom threshold = 200,000: both are small
      final customTotals200k = FinancialEngine.calculateTotals([r1, r2], 200000);
      expect(customTotals200k.smallCount, 2);
      expect(customTotals200k.largeCount, 0);
    });

    test('formatFullIncomingSummary produces emoji-free and clean accounting statement', () {
      final r1 = IncomingRemittance(
        id: '1',
        batchId: 'B1',
        seq: 1,
        date: '2026/09/27',
        name: 'سالم',
        account: '10001',
        amount: 2000,
        rate: 48,
        birrEquivalent: 96000,
      );

      final summaryWithClass = ReportFormatter.formatFullIncomingSummary(
        [r1],
        48,
        enableClassification: true,
        largeThreshold: 100000,
      );
      expect(summaryWithClass, contains('كشف حسابات الصرافين'));
      expect(summaryWithClass.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true)), isFalse);

      final summaryNoClass = ReportFormatter.formatFullIncomingSummary(
        [r1],
        48,
        enableClassification: false,
      );
      expect(summaryNoClass, contains('قائمة الحوالات الواردة'));
      expect(summaryNoClass.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true)), isFalse);
    });

    test('normalizeCurrency should normalize سعود and ريال سعود to ريال سعودي', () {
      expect(FinancialEngine.normalizeCurrency('ريال سعود'), 'ريال سعودي');
      expect(FinancialEngine.normalizeCurrency('سعودي'), 'ريال سعودي');
      expect(FinancialEngine.normalizeCurrency('سعود'), 'ريال سعودي');
      expect(FinancialEngine.normalizeCurrency('SAR'), 'ريال سعودي');
      expect(FinancialEngine.normalizeCurrency('ر.س'), 'ريال سعودي');
    });

    test('WhatsAppParser removes beneficiary label prefixes and parses shorthand currency', () {
      const msg = '''
المستلم: aferyeme djana
1000733766097
8,950 ريال سعود
''';
      final res = WhatsAppParser.extractRecords(text: msg, exchangeRate: 48.0);
      expect(res.records.length, 1);
      final r = res.records.first;
      expect(r.name, 'aferyeme djana');
      expect(r.currency, 'ريال سعودي');
      expect(r.amount, 8950.0);
      expect(r.account, '1000733766097');
    });
  });
}
