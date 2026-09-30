import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:al_qassam_app/core/storage/local_storage_service.dart';
import 'package:al_qassam_app/features/templates/data/default_templates.dart';
import 'package:al_qassam_app/features/templates/domain/models/template_rule.dart';
import 'package:al_qassam_app/features/templates/services/template_matcher.dart';

void main() {
  late Directory tempDir;
  late LocalStorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('templates_test_');
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

  group('Template Management System Tests', () {
    test('Default templates should be seeded properly with incoming and outgoing', () {
      final all = storage.getAllTemplates();
      final incoming = storage.getAllTemplates(type: TemplateType.incoming);
      final outgoing = storage.getAllTemplates(type: TemplateType.outgoing);

      expect(all.isNotEmpty, true);
      expect(incoming.length, greaterThanOrEqualTo(5));
      expect(outgoing.length, greaterThanOrEqualTo(5));

      // Check specific built-in template existence
      expect(incoming.any((t) => t.id == 'incoming-phone-included'), true);
      expect(outgoing.any((t) => t.id == 'outgoing-alakwaa'), true);
    });

    test('Add custom incoming template and verify persistence', () async {
      final custom = TemplateRule(
        id: 'custom-in-1',
        name: 'قالب إثيوبي مخصص لفرع أديس',
        type: TemplateType.incoming,
        description: 'قالب خاص بالموردين',
        strategy: ExtractionStrategy.phoneIncluded,
        sampleText: 'Mulugeta Assefa\n1000998877665\n0911002233\n500',
        isEnabled: true,
        isBuiltIn: false,
        createdAt: DateTime.now(),
      );

      await storage.saveTemplate(custom);

      final retrieved = storage.getAllTemplates(type: TemplateType.incoming);
      expect(retrieved.any((t) => t.id == 'custom-in-1'), true);

      // Matcher test
      final matchRes = TemplateMatcher.testTemplate(custom, custom.sampleText);
      expect(matchRes.isMatch, true);
      expect(matchRes.beneficiary, 'Mulugeta Assefa');
      expect(matchRes.account, '1000998877665');
      expect(matchRes.phone, '0911002233');
      expect(matchRes.amount, 500.0);
    });

    test('Add custom outgoing network template and verify persistence', () async {
      final customOut = TemplateRule(
        id: 'custom-out-1',
        name: 'قالب شبكة الحظا إكسبرس',
        type: TemplateType.outgoing,
        description: 'إشعارات شبكة الحظا الصادرة',
        strategy: ExtractionStrategy.outgoingNetwork,
        sampleText: 'شركة الحظا إكسبرس للصرافة\nرقم الحوالة: 665544\nالمستفيد: وليد محمد سعيد\nالمبلغ: 75000 ريال يمني\nالعمولة: 1500',
        isEnabled: true,
        isBuiltIn: false,
        createdAt: DateTime.now(),
      );

      await storage.saveTemplate(customOut);

      final retrievedOut = storage.getAllTemplates(type: TemplateType.outgoing);
      expect(retrievedOut.any((t) => t.id == 'custom-out-1'), true);

      // Matcher test
      final matchRes = TemplateMatcher.testTemplate(customOut, customOut.sampleText);
      expect(matchRes.isMatch, true);
      expect(matchRes.beneficiary, 'وليد محمد سعيد');
      expect(matchRes.amount, 75000.0);
      expect(matchRes.fee, 1500.0);
      expect(matchRes.transferNumber, '665544');
    });

    test('Toggling template state (enable/disable)', () async {
      final target = storage.getAllTemplates().first;
      expect(target.isEnabled, true);

      await storage.toggleTemplate(target.id, false);

      final updated = storage.getAllTemplates().firstWhere((t) => t.id == target.id);
      expect(updated.isEnabled, false);
    });

    test('Built-in templates cannot be deleted, but custom templates can', () async {
      // 1. Attempt to delete built-in template
      final canDeleteBuiltIn = await storage.deleteTemplate('incoming-phone-included');
      expect(canDeleteBuiltIn, false);

      // 2. Add and delete custom template
      final custom = TemplateRule(
        id: 'custom-to-delete',
        name: 'قالب للتجربة والحذف',
        type: TemplateType.incoming,
        description: '',
        strategy: ExtractionStrategy.standardOrder,
        sampleText: 'test',
        isEnabled: true,
        isBuiltIn: false,
        createdAt: DateTime.now(),
      );
      await storage.saveTemplate(custom);

      final canDeleteCustom = await storage.deleteTemplate('custom-to-delete');
      expect(canDeleteCustom, true);
      expect(storage.getAllTemplates().any((t) => t.id == 'custom-to-delete'), false);
    });

    test('Resetting templates restores default catalog', () async {
      // Add custom template and disable one built-in
      await storage.toggleTemplate('incoming-phone-included', false);
      await storage.saveTemplate(TemplateRule(
        id: 'custom-temp',
        name: 'قالب مؤقت',
        type: TemplateType.incoming,
        description: '',
        strategy: ExtractionStrategy.standardOrder,
        sampleText: '',
        createdAt: DateTime.now(),
      ));

      // Reset
      await storage.resetTemplatesToDefaults();

      final list = storage.getAllTemplates();
      expect(list.any((t) => t.id == 'custom-temp'), false);
      expect(list.firstWhere((t) => t.id == 'incoming-phone-included').isEnabled, true);
    });
  });
}
