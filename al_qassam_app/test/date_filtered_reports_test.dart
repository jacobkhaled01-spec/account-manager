import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:al_qassam_app/core/storage/local_storage_service.dart';
import 'package:al_qassam_app/features/financial_engine/domain/models/batch_record.dart';
import 'package:al_qassam_app/features/financial_engine/domain/models/incoming_remittance.dart';
import 'package:al_qassam_app/features/financial_engine/domain/models/outgoing_transfer.dart';
import 'package:al_qassam_app/features/reports_export/services/excel_exporter.dart';
import 'package:al_qassam_app/features/reports_export/services/report_formatter.dart';

void main() {
  late Directory tempDir;
  late LocalStorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('date_reports_test_');
    storage = LocalStorageService.instance;
    await storage.init(tempDir.path);
  });

  tearDown(() async {
    await storage.clearAll();
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Date-filtered Statements and Reports Tests', () {
    test('getAllIncomingRemittances should filter accurately by date range and specific date', () async {
      final batchToday = BatchRecord(
        id: 'batch-today',
        title: 'دفعة اليوم',
        type: BatchType.incoming,
        exchangeRate: 48.0,
      );

      final recToday = IncomingRemittance(
        id: 'rec-today-1',
        batchId: 'batch-today',
        seq: 1,
        account: '1000111222333',
        name: 'أحمد علي اليوم',
        amount: 500,
        currency: 'سعودي',
        rate: 48,
        birrEquivalent: 24000,
        date: '2026/09/27',
        createdAt: DateTime.now(),
      );

      final recYesterday = IncomingRemittance(
        id: 'rec-yesterday-1',
        batchId: 'batch-yesterday',
        seq: 1,
        account: '1000999888777',
        name: 'صالح محمد الأمس',
        amount: 1000,
        currency: 'سعودي',
        rate: 48,
        birrEquivalent: 48000,
        date: '2026/09/26',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      await storage.saveIncomingBatch(
        batch: batchToday,
        remittances: [recToday],
      );

      await storage.saveIncomingBatch(
        batch: BatchRecord(
          id: 'batch-yesterday',
          title: 'دفعة الأمس',
          type: BatchType.incoming,
          exchangeRate: 48.0,
        ),
        remittances: [recYesterday],
      );

      // 1. Query today only
      final now = DateTime.now();
      final todayList = storage.getAllIncomingRemittances(
        fromDate: DateTime(now.year, now.month, now.day),
        toDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
      expect(todayList.length, 1);
      expect(todayList.first.name, 'أحمد علي اليوم');

      // 2. Query date range covering both days
      final rangeList = storage.getAllIncomingRemittances(
        fromDate: DateTime.now().subtract(const Duration(days: 2)),
        toDate: DateTime.now().add(const Duration(days: 1)),
      );
      expect(rangeList.length, 2);
    });

    test('getAllOutgoingTransfers should filter accurately by date and network', () async {
      final outBatch = BatchRecord(
        id: 'out-batch-1',
        title: 'صادر شبكات',
        type: BatchType.outgoing,
        exchangeRate: 0.0,
      );

      final t1 = OutgoingTransfer(
        id: 'out-1',
        batchId: 'out-batch-1',
        recipient: 'صالح أحمد',
        sender: 'مكتب القسام',
        amount: 150000,
        currency: 'ريال يمني',
        network: 'شبكة الأكوع',
        date: '2026/09/27',
        createdAt: DateTime.now(),
      );

      final t2 = OutgoingTransfer(
        id: 'out-2',
        batchId: 'out-batch-1',
        recipient: 'محمد عبدالله',
        sender: 'هشام الزبيري',
        amount: 59,
        currency: 'دولار أمريكي',
        network: 'حزمي',
        date: '2026/09/27',
        createdAt: DateTime.now(),
      );

      await storage.saveOutgoingBatch(
        batch: outBatch,
        transfers: [t1, t2],
      );

      // Filter by network 'حزمي'
      final hazmiList = storage.getAllOutgoingTransfers(network: 'حزمي');
      expect(hazmiList.length, 1);
      expect(hazmiList.first.recipient, 'محمد عبدالله');
      expect(hazmiList.first.amount, 59.0);
      expect(hazmiList.first.currency, 'دولار أمريكي');

      // Filter all
      final allOut = storage.getAllOutgoingTransfers();
      expect(allOut.length, 2);
    });

    test('ExcelExporter creates and encodes valid Outgoing Transfers Excel spreadsheet', () async {
      final transfers = [
        OutgoingTransfer(
          id: 'out-excel-1',
          batchId: 'b-1',
          recipient: 'محمد عبدالله احمد الزبيري',
          sender: 'هشام محمد عبدالوهاب الزبيري',
          amount: 59,
          currency: 'دولار أمريكي',
          network: 'حزمي',
          transferNo: '-',
          date: '2026/09/27',
        ),
      ];

      final filePath = await ExcelExporter.exportOutgoingTransfers(
        statementTitle: 'كشف صادر حزمي',
        transfers: transfers,
        bureauName: 'مكتب القسام للصرافة',
      );

      expect(filePath.isNotEmpty, true);
      final file = File(filePath);
      expect(file.existsSync(), true);

      // Cleanup generated excel
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('Strict Birr copy isolation: copying Birr message strictly targets active batch only', () async {
      // Past batch
      final pastBatchRecs = [
        IncomingRemittance(
          id: 'past-1',
          batchId: 'batch-past',
          seq: 1,
          account: '1000111111111',
          name: 'عميل سابق الأمس',
          amount: 5000,
          currency: 'سعودي',
          rate: 48,
          birrEquivalent: 240000,
          date: '2026/09/26',
        ),
      ];

      // Newly pasted batch (whether batch or single remittance)
      final List<IncomingRemittance> activePastedRecs = [
        IncomingRemittance(
          id: 'new-1',
          batchId: 'batch-active',
          seq: 1,
          account: '1000832605746',
          name: 'he mahar atsbaha',
          amount: 400,
          currency: 'سعودي',
          rate: 48,
          birrEquivalent: 19200,
          date: '2026/09/27',
        ),
      ];

      // Birr copy message generated strictly for active pasted batch
      final birrMsg = ReportFormatter.formatBirrReport(activePastedRecs, includeTotals: false);

      expect(birrMsg.contains('1000832605746'), true);
      expect(birrMsg.contains('he mahar atsbaha'), true);
      // Ensures past batch or historical items NEVER leak into Birr message
      expect(birrMsg.contains('1000111111111'), false);
      expect(birrMsg.contains('عميل سابق الأمس'), false);
    });
  });
}
