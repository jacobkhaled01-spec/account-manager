import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:al_qassam_app/core/storage/local_storage_service.dart';
import 'package:al_qassam_app/features/financial_engine/domain/models/batch_record.dart';
import 'package:al_qassam_app/features/financial_engine/domain/models/incoming_remittance.dart';
import 'package:al_qassam_app/features/reports_export/services/report_formatter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    await LocalStorageService.instance.init(tempDir.path);
  });

  tearDown(() async {
    await LocalStorageService.instance.clearAll();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Batch Isolation and Deduplication Tests', () {
    test('Deduplication prevents importing identical remittances across batches', () async {
      final storage = LocalStorageService.instance;

      // First batch
      final batch1 = BatchRecord(
        id: 'batch-001',
        title: 'دفعة 1',
        type: BatchType.incoming,
        exchangeRate: 48.0,
      );

      final rec1 = IncomingRemittance(
        id: 'rec-1',
        batchId: 'batch-001',
        seq: 1,
        date: '2026/09/27',
        name: 'محمد أحمد قاسم',
        account: '1000123456789',
        amount: 500.0,
        currency: 'ريال سعودي',
        rate: 48.0,
        birrEquivalent: 24000.0,
      );

      final rec2 = IncomingRemittance(
        id: 'rec-2',
        batchId: 'batch-001',
        seq: 2,
        date: '2026/09/27',
        name: 'علي عبد الله صالح',
        account: '1000987654321',
        amount: 1000.0,
        currency: 'ريال سعودي',
        rate: 48.0,
        birrEquivalent: 48000.0,
      );

      final res1 = await storage.saveIncomingBatch(
        batch: batch1,
        remittances: [rec1, rec2],
        preventDuplicatesAcrossBatches: true,
      );

      expect(res1.insertedCount, equals(2));
      expect(res1.duplicateCount, equals(0));
      expect(storage.hasFingerprint(rec1.fingerprint), isTrue);

      // Second batch containing 1 new record and 1 duplicate of rec1
      final batch2 = BatchRecord(
        id: 'batch-002',
        title: 'دفعة 2',
        type: BatchType.incoming,
        exchangeRate: 48.0,
      );

      final recDuplicate = IncomingRemittance(
        id: 'rec-3-dup',
        batchId: 'batch-002',
        seq: 1,
        date: '2026/09/27',
        name: 'محمد أحمد قاسم',
        account: '1000123456789', // exact same account & amount & name
        amount: 500.0,
        currency: 'ريال سعودي',
        rate: 48.0,
        birrEquivalent: 24000.0,
      );

      final recNew = IncomingRemittance(
        id: 'rec-4-new',
        batchId: 'batch-002',
        seq: 2,
        date: '2026/09/27',
        name: 'سالم خالد عمر',
        account: '1000555666777',
        amount: 300.0,
        currency: 'ريال سعودي',
        rate: 48.0,
        birrEquivalent: 14400.0,
      );

      final res2 = await storage.saveIncomingBatch(
        batch: batch2,
        remittances: [recDuplicate, recNew],
        preventDuplicatesAcrossBatches: true,
      );

      // The duplicate must be skipped, and only the new record inserted!
      expect(res2.insertedCount, equals(1));
      expect(res2.duplicateCount, equals(1));
      expect(res2.duplicateDetails.length, equals(1));
      expect(res2.duplicateDetails.first, contains('محمد أحمد قاسم'));

      // Verify records in batch2 contains ONLY recNew
      final batch2Records = storage.getIncomingRemittances('batch-002');
      expect(batch2Records.length, equals(1));
      expect(batch2Records.first.name, equals('سالم خالد عمر'));
    });

    test('Paste batch isolation: Birr copy message strictly targets active batch', () async {
      final storage = LocalStorageService.instance;

      // Batch A (Morning Paste)
      final batchA = BatchRecord(
        id: 'batch-A',
        title: 'دفعة الصباح',
        type: BatchType.incoming,
        exchangeRate: 48.0,
      );
      final recA = IncomingRemittance(
        id: 'a1',
        batchId: 'batch-A',
        seq: 1,
        date: '2026/09/27',
        name: 'عميل الصباح الأقدم',
        account: '1000111111111',
        amount: 1000.0,
        currency: 'ريال سعودي',
        rate: 48.0,
        birrEquivalent: 48000.0,
      );
      await storage.saveIncomingBatch(batch: batchA, remittances: [recA]);

      // Batch B (Evening Paste)
      final batchB = BatchRecord(
        id: 'batch-B',
        title: 'دفعة المساء',
        type: BatchType.incoming,
        exchangeRate: 48.0,
      );
      final recB = IncomingRemittance(
        id: 'b1',
        batchId: 'batch-B',
        seq: 1,
        date: '2026/09/27',
        name: 'عميل المساء الأحدث',
        account: '1000222222222',
        amount: 2500.0,
        currency: 'ريال سعودي',
        rate: 48.0,
        birrEquivalent: 120000.0,
      );
      await storage.saveIncomingBatch(batch: batchB, remittances: [recB]);

      // Fetch batch B remittances strictly
      final batchBRecords = storage.getIncomingRemittances('batch-B');
      expect(batchBRecords.length, equals(1));
      expect(batchBRecords.first.name, equals('عميل المساء الأحدث'));

      // Format Birr message for Batch B
      final birrReportB = ReportFormatter.formatBirrReport(batchBRecords);

      // Verify that Batch B report contains عميل المساء and does NOT contain عميل الصباح!
      expect(birrReportB, contains('عميل المساء الأحدث'));
      expect(birrReportB, contains('1000222222222'));
      expect(birrReportB, contains('120,000 birr'));
      expect(birrReportB, isNot(contains('عميل الصباح الأقدم')));
      expect(birrReportB, isNot(contains('1000111111111')));
    });
  });
}
