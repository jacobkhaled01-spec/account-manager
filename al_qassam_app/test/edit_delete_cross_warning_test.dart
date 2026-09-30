import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:al_qassam_app/core/storage/local_storage_service.dart';
import 'package:al_qassam_app/features/financial_engine/domain/models/batch_record.dart';
import 'package:al_qassam_app/features/financial_engine/domain/models/incoming_remittance.dart';
import 'package:al_qassam_app/features/financial_engine/domain/models/outgoing_transfer.dart';
import 'package:al_qassam_app/features/parsers/services/whatsapp_parser.dart';
import 'package:al_qassam_app/features/parsers/services/outgoing_parser.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('edit_delete_test_');
    await LocalStorageService.instance.init(tempDir.path);
    await LocalStorageService.instance.clearAll();
  });

  tearDown(() async {
    await LocalStorageService.instance.clearAll();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Edit and Delete Remittances & Transfers Tests', () {
    test('Update and Delete Incoming Remittance', () async {
      final batch = BatchRecord(
        id: 'batch_in_1',
        title: 'دفعة وارد 1',
        type: BatchType.incoming,
        exchangeRate: 50.0,
        count: 1,
        totalAmount: 1000,
        totalBirr: 50000,
        rawText: '',
      );

      final remittance = IncomingRemittance(
        id: 'rem_1',
        batchId: 'batch_in_1',
        seq: 1,
        date: '2026/09/29',
        name: 'محمد عبدالله',
        account: '100012345678',
        amount: 1000.0,
        rate: 50.0,
        birrEquivalent: 50000.0,
      );

      await LocalStorageService.instance.saveIncomingBatch(
        batch: batch,
        remittances: [remittance],
      );

      var records = LocalStorageService.instance.getIncomingRemittances('batch_in_1');
      expect(records.length, 1);
      expect(records.first.name, 'محمد عبدالله');

      // 1. Edit / Update
      final updated = remittance.copyWith(
        name: 'محمد عبدالله أحمد',
        amount: 1200.0,
        birrEquivalent: 60000.0,
      );
      await LocalStorageService.instance.updateIncomingRemittance(updated);

      records = LocalStorageService.instance.getIncomingRemittances('batch_in_1');
      expect(records.length, 1);
      expect(records.first.name, 'محمد عبدالله أحمد');
      expect(records.first.amount, 1200.0);
      expect(records.first.birrEquivalent, 60000.0);

      // 2. Delete
      await LocalStorageService.instance.deleteIncomingRemittance('rem_1');
      records = LocalStorageService.instance.getIncomingRemittances('batch_in_1');
      expect(records.isEmpty, isTrue);
    });

    test('Update and Delete Outgoing Transfer', () async {
      final batch = BatchRecord(
        id: 'batch_out_1',
        title: 'دفعة صادر 1',
        type: BatchType.outgoing,
        exchangeRate: 0.0,
        count: 1,
        totalAmount: 50000,
        totalBirr: 0,
        rawText: '',
      );

      final transfer = OutgoingTransfer(
        id: 'out_1',
        batchId: 'batch_out_1',
        seq: 1,
        recipient: 'علي حسن',
        sender: '777123456',
        amount: 50000.0,
        network: 'النجم',
        transferNo: 'TR-9988',
        date: '2026/09/29',
      );

      await LocalStorageService.instance.saveOutgoingBatch(
        batch: batch,
        transfers: [transfer],
      );

      var records = LocalStorageService.instance.getOutgoingTransfers('batch_out_1');
      expect(records.length, 1);
      expect(records.first.recipient, 'علي حسن');

      // 1. Edit / Update
      final updated = transfer.copyWith(
        recipient: 'علي حسن المريسي',
        amount: 60000.0,
        network: 'الكريمي',
      );
      await LocalStorageService.instance.updateOutgoingTransfer(updated);

      records = LocalStorageService.instance.getOutgoingTransfers('batch_out_1');
      expect(records.length, 1);
      expect(records.first.recipient, 'علي حسن المريسي');
      expect(records.first.amount, 60000.0);
      expect(records.first.network, 'الكريمي');

      // 2. Delete
      await LocalStorageService.instance.deleteOutgoingTransfer('out_1');
      records = LocalStorageService.instance.getOutgoingTransfers('batch_out_1');
      expect(records.isEmpty, isTrue);
    });

    test('Cross-Type Detection identifies mismatch accurately', () {
      const outgoingText = '''
شبكة النجم
المستلم: فهد أحمد قاسم
المبلغ: 150000 ريال
الهاتف: 777000111
رقم الحوالة: 88776655
''';

      final outCheck = OutgoingParser.parseOutgoingText(text: outgoingText);
      final inCheck = WhatsAppParser.extractRecords(text: outgoingText, exchangeRate: 50.0);

      // Outgoing parser correctly identifies the outgoing network transfer
      expect(outCheck.records.isNotEmpty, isTrue);
      expect(outCheck.records.first.recipient, 'فهد أحمد قاسم');
      expect(outCheck.records.first.network, 'شبكة النجم');

      const incomingText = '''
1000733766097

8950

aferyeme djana
''';
      final inCheck2 = WhatsAppParser.extractRecords(text: incomingText, exchangeRate: 50.0);
      final outCheck2 = OutgoingParser.parseOutgoingText(text: incomingText);

      // Incoming parser identifies the CBE account remittance
      expect(inCheck2.records.isNotEmpty, isTrue);
      expect(inCheck2.records.first.account, '1000733766097');
    });
  });
}
