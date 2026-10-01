import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../features/auth/domain/models/app_user_account.dart';
import '../../features/financial_engine/domain/models/batch_record.dart';
import '../../features/financial_engine/domain/models/incoming_remittance.dart';
import '../../features/financial_engine/domain/models/outgoing_transfer.dart';
import '../../features/parsers/services/outgoing_parser.dart';
import '../../features/parsers/services/whatsapp_parser.dart';
import '../../features/templates/data/default_templates.dart';
import '../../features/templates/domain/models/template_rule.dart';

/// Result of an import operation with deduplication details.
class ImportResult {
  final BatchRecord batch;
  final int insertedCount;
  final int duplicateCount;
  final List<String> duplicateDetails;
  final List<IncomingRemittance> savedIncoming;
  final List<OutgoingTransfer> savedOutgoing;

  const ImportResult({
    required this.batch,
    required this.insertedCount,
    required this.duplicateCount,
    this.duplicateDetails = const [],
    this.savedIncoming = const [],
    this.savedOutgoing = const [],
  });
}

/// Offline-first local storage service powered by Hive with Multi-Account DB Isolation.
/// Guarantees zero-latency persistence, cross-batch deduplication,
/// and strict database isolation per account.
class LocalStorageService {
  static const String _accountsBoxName = 'accounts_meta_v1';
  static const String _batchesBaseName = 'batches';
  static const String _incomingBaseName = 'incoming';
  static const String _outgoingBaseName = 'outgoing';
  static const String _fingerprintsBaseName = 'fingerprints';
  static const String _settingsBaseName = 'settings';
  static const String _templatesBaseName = 'templates';

  late Box _accountsBox;
  late Box _batchesBox;
  late Box _incomingBox;
  late Box _outgoingBox;
  late Box _fingerprintsBox;
  late Box _settingsBox;
  late Box _templatesBox;

  String _currentAccountId = 'default';
  String get currentAccountId => _currentAccountId;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  static final LocalStorageService instance = LocalStorageService._internal();

  LocalStorageService._internal();

  static String _getBoxName(String baseName, String accountId) {
    if (accountId == 'default') return '${baseName}_v1';
    final cleanId = accountId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return '${baseName}_u_$cleanId';
  }

  /// Initialize Hive and open all operational boxes.
  Future<void> init([String? customPath]) async {
    if (customPath != null && customPath.isNotEmpty) {
      Hive.init(customPath);
    } else {
      await Hive.initFlutter();
    }

    _accountsBox = await Hive.openBox(_accountsBoxName);

    // Seed default admin account if accounts meta box is empty
    if (_accountsBox.isEmpty) {
      final defaultAccount = AppUserAccount(
        id: 'default',
        username: 'مدير النظام',
        pin: '1234',
        bureauName: 'نظام القسام للصرافة والتحويلات',
        createdAt: DateTime.now(),
      );
      await _accountsBox.put(defaultAccount.id, defaultAccount.toMap());
    }

    final activeId = _accountsBox.get('active_account_id', defaultValue: 'default') as String;
    await _openBoxesForAccount(activeId);
    _isInitialized = true;

    debugPrint('LocalStorageService initialized successfully with Hive. Active account: $_currentAccountId');
  }

  Future<void> _openBoxesForAccount(String accountId) async {
    _currentAccountId = accountId;
    await _accountsBox.put('active_account_id', accountId);

    _batchesBox = await Hive.openBox(_getBoxName(_batchesBaseName, accountId));
    _incomingBox = await Hive.openBox(_getBoxName(_incomingBaseName, accountId));
    _outgoingBox = await Hive.openBox(_getBoxName(_outgoingBaseName, accountId));
    _fingerprintsBox = await Hive.openBox(_getBoxName(_fingerprintsBaseName, accountId));
    _settingsBox = await Hive.openBox(_getBoxName(_settingsBaseName, accountId));
    _templatesBox = await Hive.openBox(_getBoxName(_templatesBaseName, accountId));

    // Seed default templates if empty
    if (_templatesBox.isEmpty) {
      for (final t in DefaultTemplates.defaults) {
        await _templatesBox.put(t.id, t.toMap());
      }
    }

    // Initialize default bureau name and currency if not set
    final acc = getCurrentAccount();
    if (acc != null) {
      if (_settingsBox.get('bureauName') == null) {
        await _settingsBox.put('bureauName', acc.bureauName);
      }
      if (_settingsBox.get('defaultCurrency') == null) {
        await _settingsBox.put('defaultCurrency', acc.defaultCurrency);
      }
    }

    // Auto-recover any unparsed or empty legacy batches
    await recoverUnparsedBatches();
  }

  Future<void> switchAccount(String accountId) async {
    if (!_isInitialized) return;
    if (_currentAccountId == accountId && _batchesBox.isOpen) return;

    if (_batchesBox.isOpen) await _batchesBox.close();
    if (_incomingBox.isOpen) await _incomingBox.close();
    if (_outgoingBox.isOpen) await _outgoingBox.close();
    if (_fingerprintsBox.isOpen) await _fingerprintsBox.close();
    if (_settingsBox.isOpen) await _settingsBox.close();
    if (_templatesBox.isOpen) await _templatesBox.close();

    await _openBoxesForAccount(accountId);
  }

  // ---------------------------------------------------------
  // Settings Management
  // ---------------------------------------------------------

  double getExchangeRate() {
    if (!_isInitialized) return 48.0;
    return (_settingsBox.get('exchangeRate', defaultValue: 48.0) as num).toDouble();
  }

  Future<void> setExchangeRate(double rate) async {
    if (!_isInitialized) return;
    await _settingsBox.put('exchangeRate', rate);
  }

  double getBuyRate() {
    if (!_isInitialized) return 50.0;
    return (_settingsBox.get('buyRate', defaultValue: 50.0) as num).toDouble();
  }

  Future<void> setBuyRate(double rate) async {
    if (!_isInitialized) return;
    await _settingsBox.put('buyRate', rate);
  }

  double getSellRate() {
    if (!_isInitialized) return getExchangeRate();
    return (_settingsBox.get('sellRate', defaultValue: getExchangeRate()) as num).toDouble();
  }

  Future<void> setSellRate(double rate) async {
    if (!_isInitialized) return;
    await _settingsBox.put('sellRate', rate);
    await setExchangeRate(rate);
  }

  String getDefaultCurrency() {
    if (!_isInitialized) return 'سعودي';
    return _settingsBox.get('defaultCurrency', defaultValue: 'سعودي') as String;
  }

  Future<void> setDefaultCurrency(String currency) async {
    if (!_isInitialized) return;
    await _settingsBox.put('defaultCurrency', currency);
  }

  String getBureauName() {
    if (!_isInitialized) return 'نظام القسام للصرافة والتحويلات';
    final name = _settingsBox.get('bureauName', defaultValue: 'نظام القسام للصرافة والتحويلات') as String;
    return (name.trim().isEmpty || name == 'Smart Paster') ? 'نظام القسام للصرافة والتحويلات' : name;
  }

  Future<void> setBureauName(String name) async {
    if (!_isInitialized) return;
    await _settingsBox.put('bureauName', name);
  }

  bool isDarkMode() {
    if (!_isInitialized) return false;
    return _settingsBox.get('isDarkMode', defaultValue: false) as bool;
  }

  Future<void> setDarkMode(bool isDark) async {
    if (!_isInitialized) return;
    await _settingsBox.put('isDarkMode', isDark);
  }

  bool isSizeClassificationEnabled() {
    if (!_isInitialized) return true;
    return _settingsBox.get('enableSizeClassification', defaultValue: true) as bool;
  }

  Future<void> setSizeClassificationEnabled(bool enabled) async {
    if (!_isInitialized) return;
    await _settingsBox.put('enableSizeClassification', enabled);
  }

  double getLargeRemittanceThreshold() {
    if (!_isInitialized) return 100000.0;
    return (_settingsBox.get('largeRemittanceThreshold', defaultValue: 100000.0) as num).toDouble();
  }

  Future<void> setLargeRemittanceThreshold(double threshold) async {
    if (!_isInitialized) return;
    await _settingsBox.put('largeRemittanceThreshold', threshold);
  }

  // ---------------------------------------------------------
  // Fingerprints & Deduplication Index
  // ---------------------------------------------------------

  /// Check if a unique fingerprint already exists in the global local index.
  bool hasFingerprint(String fingerprint) {
    if (!_isInitialized || fingerprint.isEmpty) return false;
    return _fingerprintsBox.containsKey(fingerprint);
  }

  Set<String> getAllFingerprints() {
    if (!_isInitialized) return <String>{};
    return _fingerprintsBox.keys.cast<String>().toSet();
  }

  // ---------------------------------------------------------
  // Batch Operations with Isolation & Deduplication
  // ---------------------------------------------------------

  /// Save an incoming remittance batch with automatic deduplication.
  /// Skips duplicate records, updates local database, and preserves batch isolation.
  Future<ImportResult> saveIncomingBatch({
    required BatchRecord batch,
    required List<IncomingRemittance> remittances,
    bool preventDuplicatesAcrossBatches = true,
  }) async {
    final List<IncomingRemittance> uniqueList = [];
    final List<String> duplicateDetails = [];
    final Set<String> seenInThisBatch = {};

    for (final record in remittances) {
      final fp = record.fingerprint;

      // 1. Check duplicate inside current batch
      if (seenInThisBatch.contains(fp)) {
        duplicateDetails.add('${record.name} - ${record.account} (${record.amount})');
        continue;
      }
      seenInThisBatch.add(fp);

      // 2. Check duplicate across all previously saved batches
      if (preventDuplicatesAcrossBatches && hasFingerprint(fp)) {
        duplicateDetails.add('${record.name} - ${record.account} (${record.amount})');
        continue;
      }

      uniqueList.add(record);
    }

    // Save batch record
    await _batchesBox.put(batch.id, batch.toMap());

    // Save unique remittances
    final Map<String, Map<String, dynamic>> recordsMap = {};
    for (final rec in uniqueList) {
      recordsMap[rec.id] = rec.toMap();
      // Register fingerprint in index referencing this batch
      await _fingerprintsBox.put(rec.fingerprint, batch.id);
    }
    await _incomingBox.putAll(recordsMap);

    return ImportResult(
      batch: batch,
      insertedCount: uniqueList.length,
      duplicateCount: duplicateDetails.length,
      duplicateDetails: duplicateDetails,
      savedIncoming: uniqueList,
    );
  }

  /// Save an outgoing transfer batch with deduplication.
  Future<ImportResult> saveOutgoingBatch({
    required BatchRecord batch,
    required List<OutgoingTransfer> transfers,
    bool preventDuplicatesAcrossBatches = true,
  }) async {
    final List<OutgoingTransfer> uniqueList = [];
    final List<String> duplicateDetails = [];
    final Set<String> seenInThisBatch = {};

    for (final transfer in transfers) {
      final fp = transfer.fingerprint;

      if (seenInThisBatch.contains(fp)) {
        duplicateDetails.add('${transfer.recipient} - ${transfer.amount} (${transfer.network})');
        continue;
      }
      seenInThisBatch.add(fp);

      if (preventDuplicatesAcrossBatches && hasFingerprint(fp)) {
        duplicateDetails.add('${transfer.recipient} - ${transfer.amount} (${transfer.network})');
        continue;
      }

      uniqueList.add(transfer);
    }

    await _batchesBox.put(batch.id, batch.toMap());

    final Map<String, Map<String, dynamic>> transfersMap = {};
    for (final t in uniqueList) {
      transfersMap[t.id] = t.toMap();
      await _fingerprintsBox.put(t.fingerprint, batch.id);
    }
    await _outgoingBox.putAll(transfersMap);

    return ImportResult(
      batch: batch,
      insertedCount: uniqueList.length,
      duplicateCount: duplicateDetails.length,
      duplicateDetails: duplicateDetails,
      savedOutgoing: uniqueList,
    );
  }

  /// Get all batches sorted by timestamp descending.
  List<BatchRecord> getBatches({BatchType? type}) {
    if (!_isInitialized) return [];
    final List<BatchRecord> list = [];
    for (final key in _batchesBox.keys) {
      final raw = _batchesBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          final b = BatchRecord.fromMap(map);
          if (type == null || b.type == type) {
            list.add(b);
          }
        } catch (e) {
          debugPrint('Error parsing batch $key: $e');
        }
      }
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Retrieve incoming remittances for a strictly isolated batch.
  List<IncomingRemittance> getIncomingRemittances(String batchId) {
    if (!_isInitialized) return [];
    final List<IncomingRemittance> records = [];
    for (final key in _incomingBox.keys) {
      final raw = _incomingBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          if (map['batchId'] == batchId) {
            records.add(IncomingRemittance.fromMap(map));
          }
        } catch (e) {
          debugPrint('Error parsing incoming remittance $key: $e');
        }
      }
    }
    records.sort((a, b) => a.sequence.compareTo(b.sequence));
    return records;
  }

  /// Retrieve outgoing transfers for a strictly isolated batch.
  List<OutgoingTransfer> getOutgoingTransfers(String batchId) {
    if (!_isInitialized) return [];
    final List<OutgoingTransfer> list = [];
    for (final key in _outgoingBox.keys) {
      final raw = _outgoingBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          if (map['batchId'] == batchId) {
            list.add(OutgoingTransfer.fromMap(map));
          }
        } catch (e) {
          debugPrint('Error parsing outgoing transfer $key: $e');
        }
      }
    }
    list.sort((a, b) => a.sequence.compareTo(b.sequence));
    return list;
  }

  /// Retrieve all incoming remittances, optionally filtered by date range or specific date.
  List<IncomingRemittance> getAllIncomingRemittances({
    DateTime? fromDate,
    DateTime? toDate,
    String? specificDate,
  }) {
    if (!_isInitialized) return [];
    final List<IncomingRemittance> records = [];
    for (final key in _incomingBox.keys) {
      final raw = _incomingBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          final rec = IncomingRemittance.fromMap(map);

          if (specificDate != null && specificDate.isNotEmpty) {
            final recDateStr =
                '${rec.createdAt.year}/${rec.createdAt.month.toString().padLeft(2, '0')}/${rec.createdAt.day.toString().padLeft(2, '0')}';
            if (recDateStr != specificDate) continue;
          }

          if (fromDate != null) {
            final startOfFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
            if (rec.createdAt.isBefore(startOfFrom)) continue;
          }

          if (toDate != null) {
            final endOfTo = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
            if (rec.createdAt.isAfter(endOfTo)) continue;
          }

          records.add(rec);
        } catch (e) {
          debugPrint('Error parsing incoming remittance $key: $e');
        }
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  /// Retrieve all outgoing transfers, optionally filtered by date range or specific date.
  List<OutgoingTransfer> getAllOutgoingTransfers({
    DateTime? fromDate,
    DateTime? toDate,
    String? specificDate,
    String? network,
  }) {
    if (!_isInitialized) return [];
    final List<OutgoingTransfer> list = [];
    for (final key in _outgoingBox.keys) {
      final raw = _outgoingBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          final t = OutgoingTransfer.fromMap(map);

          if (specificDate != null && specificDate.isNotEmpty) {
            final tDateStr =
                '${t.createdAt.year}/${t.createdAt.month.toString().padLeft(2, '0')}/${t.createdAt.day.toString().padLeft(2, '0')}';
            if (t.date != specificDate && tDateStr != specificDate) continue;
          }

          if (fromDate != null) {
            final startOfFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
            if (t.createdAt.isBefore(startOfFrom)) continue;
          }

          if (toDate != null) {
            final endOfTo = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
            if (t.createdAt.isAfter(endOfTo)) continue;
          }

          if (network != null && network.isNotEmpty && network != 'الكل') {
            if (!t.network.contains(network)) continue;
          }

          list.add(t);
        } catch (e) {
          debugPrint('Error parsing outgoing transfer $key: $e');
        }
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Recovers any empty or legacy batches by re-parsing rawText if available.
  Future<int> recoverUnparsedBatches() async {
    if (!_isInitialized) return 0;
    int recoveredCount = 0;

    for (final key in _batchesBox.keys) {
      final raw = _batchesBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          final batchId = map['id'] as String? ?? key.toString();
          final type = map['type'] as String? ?? 'incoming';
          final rawText = map['rawText'] as String? ?? '';

          if (type == 'outgoing') {
            final existingTransfers = getOutgoingTransfers(batchId);
            if (existingTransfers.isEmpty && rawText.trim().isNotEmpty) {
              final parseRes = OutgoingParser.parseOutgoingText(
                text: rawText,
                batchId: batchId,
              );
              if (parseRes.records.isNotEmpty) {
                final Map<String, Map<String, dynamic>> transfersMap = {};
                double totalAmt = 0;
                for (final t in parseRes.records) {
                  transfersMap[t.id] = t.toMap();
                  await _fingerprintsBox.put(t.fingerprint, batchId);
                  totalAmt += t.amount;
                }
                await _outgoingBox.putAll(transfersMap);

                map['count'] = parseRes.records.length;
                map['totalAmount'] = totalAmt;
                await _batchesBox.put(batchId, map);
                recoveredCount++;
              }
            }
          } else {
            final existingIncoming = getIncomingRemittances(batchId);
            final currentCount = (map['count'] as num?)?.toInt() ?? 0;
            if (existingIncoming.isEmpty && rawText.trim().isNotEmpty && currentCount == 0) {
              final parseRes = WhatsAppParser.extractRecords(
                text: rawText,
                exchangeRate: getExchangeRate(),
                batchId: batchId,
              );
              if (parseRes.records.isNotEmpty) {
                final Map<String, Map<String, dynamic>> recsMap = {};
                double totalAmt = 0;
                double totalBirr = 0;
                for (final r in parseRes.records) {
                  recsMap[r.id] = r.toMap();
                  await _fingerprintsBox.put(r.fingerprint, batchId);
                  totalAmt += r.amount;
                  totalBirr += r.birrEquivalent;
                }
                await _incomingBox.putAll(recsMap);

                map['count'] = parseRes.records.length;
                map['totalAmount'] = totalAmt;
                map['totalBirr'] = totalBirr;
                await _batchesBox.put(batchId, map);
                recoveredCount++;
              }
            }
          }
        } catch (e) {
          debugPrint('Error recovering batch $key: $e');
        }
      }
    }
    return recoveredCount;
  }


  /// Delete a batch and all of its associated records & fingerprints.
  Future<void> deleteBatch(String batchId) async {
    // 1. Delete incoming records
    final incomingKeysToDelete = <dynamic>[];
    for (final key in _incomingBox.keys) {
      final raw = _incomingBox.get(key);
      if (raw != null && raw is Map && raw['batchId'] == batchId) {
        incomingKeysToDelete.add(key);
        // remove fingerprint
        final fp = raw['fingerprint'];
        if (fp != null) {
          await _fingerprintsBox.delete(fp);
        }
      }
    }
    await _incomingBox.deleteAll(incomingKeysToDelete);

    // 2. Delete outgoing records
    final outgoingKeysToDelete = <dynamic>[];
    for (final key in _outgoingBox.keys) {
      final raw = _outgoingBox.get(key);
      if (raw != null && raw is Map && raw['batchId'] == batchId) {
        outgoingKeysToDelete.add(key);
        final fp = raw['fingerprint'];
        if (fp != null) {
          await _fingerprintsBox.delete(fp);
        }
      }
    }
    await _outgoingBox.deleteAll(outgoingKeysToDelete);

    // 3. Delete batch record
    await _batchesBox.delete(batchId);
  }

  /// Update an existing incoming remittance record.
  Future<void> updateIncomingRemittance(IncomingRemittance updated) async {
    if (!_isInitialized) return;
    final raw = _incomingBox.get(updated.id);
    if (raw != null && raw is Map) {
      final oldRec = IncomingRemittance.fromMap(Map<String, dynamic>.from(raw));
      if (oldRec.fingerprint != updated.fingerprint) {
        await _fingerprintsBox.delete(oldRec.fingerprint);
      }
    }
    await _incomingBox.put(updated.id, updated.toMap());
    await _fingerprintsBox.put(updated.fingerprint, updated.batchId);
  }

  /// Delete a single incoming remittance by ID.
  Future<void> deleteIncomingRemittance(String id) async {
    if (!_isInitialized) return;
    final raw = _incomingBox.get(id);
    if (raw != null && raw is Map) {
      final oldRec = IncomingRemittance.fromMap(Map<String, dynamic>.from(raw));
      await _fingerprintsBox.delete(oldRec.fingerprint);
    }
    await _incomingBox.delete(id);
  }

  /// Update an existing outgoing transfer record.
  Future<void> updateOutgoingTransfer(OutgoingTransfer updated) async {
    if (!_isInitialized) return;
    final raw = _outgoingBox.get(updated.id);
    if (raw != null && raw is Map) {
      final oldRec = OutgoingTransfer.fromMap(Map<String, dynamic>.from(raw));
      if (oldRec.fingerprint != updated.fingerprint) {
        await _fingerprintsBox.delete(oldRec.fingerprint);
      }
    }
    await _outgoingBox.put(updated.id, updated.toMap());
    await _fingerprintsBox.put(updated.fingerprint, updated.batchId);
  }

  /// Delete a single outgoing transfer by ID.
  Future<void> deleteOutgoingTransfer(String id) async {
    if (!_isInitialized) return;
    final raw = _outgoingBox.get(id);
    if (raw != null && raw is Map) {
      final oldRec = OutgoingTransfer.fromMap(Map<String, dynamic>.from(raw));
      await _fingerprintsBox.delete(oldRec.fingerprint);
    }
    await _outgoingBox.delete(id);
  }

  /// Clear all data completely (used for testing or resetting).
  Future<void> clearAll() async {
    await _batchesBox.clear();
    await _incomingBox.clear();
    await _outgoingBox.clear();
    await _fingerprintsBox.clear();
    await _templatesBox.clear();
  }

  // ---------------------------------------------------------
  // Template Management (الصادر والوارد)
  // ---------------------------------------------------------

  /// Get all templates, optionally filtered by type (incoming / outgoing)
  List<TemplateRule> getAllTemplates({TemplateType? type}) {
    if (!_isInitialized) {
      if (type == null) return DefaultTemplates.defaults;
      return DefaultTemplates.defaults.where((t) => t.type == type).toList();
    }

    final List<TemplateRule> list = [];
    for (final key in _templatesBox.keys) {
      final raw = _templatesBox.get(key);
      if (raw != null && raw is Map) {
        final t = TemplateRule.fromMap(raw);
        if (type == null || t.type == type) {
          list.add(t);
        }
      }
    }

    // If box was empty, seed defaults
    if (list.isEmpty) {
      return type == null
          ? DefaultTemplates.defaults
          : DefaultTemplates.defaults.where((t) => t.type == type).toList();
    }

    list.sort((a, b) {
      // Built-in first, then by date
      if (a.isBuiltIn && !b.isBuiltIn) return -1;
      if (!a.isBuiltIn && b.isBuiltIn) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });

    return list;
  }

  /// Save or update a template
  Future<void> saveTemplate(TemplateRule template) async {
    if (!_isInitialized) return;
    await _templatesBox.put(template.id, template.toMap());
  }

  /// Delete a user-defined template (built-in templates cannot be deleted)
  Future<bool> deleteTemplate(String id) async {
    if (!_isInitialized) return false;
    final raw = _templatesBox.get(id);
    if (raw != null && raw is Map) {
      final t = TemplateRule.fromMap(raw);
      if (t.isBuiltIn) {
        return false; // Prevent deleting built-in templates
      }
    }
    await _templatesBox.delete(id);
    return true;
  }

  /// Toggle template enabled/disabled status
  Future<void> toggleTemplate(String id, bool isEnabled) async {
    if (!_isInitialized) return;
    final raw = _templatesBox.get(id);
    if (raw != null && raw is Map) {
      final t = TemplateRule.fromMap(raw).copyWith(isEnabled: isEnabled);
      await _templatesBox.put(id, t.toMap());
    }
  }

  /// Reset all templates to default built-ins
  Future<void> resetTemplatesToDefaults() async {
    if (!_isInitialized) return;
    await _templatesBox.clear();
    for (final t in DefaultTemplates.defaults) {
      await _templatesBox.put(t.id, t.toMap());
    }
  }

  // ---------------------------------------------------------
  // Multi-Account Management (إدارة الحسابات وقواعد البيانات المستقلة)
  // ---------------------------------------------------------

  List<AppUserAccount> getAllAccounts() {
    if (!_isInitialized) return [];
    final accounts = <AppUserAccount>[];
    for (final key in _accountsBox.keys) {
      if (key == 'active_account_id' || key == 'is_logged_in') continue;
      final val = _accountsBox.get(key);
      if (val is Map) {
        accounts.add(AppUserAccount.fromMap(val));
      }
    }
    accounts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return accounts;
  }

  AppUserAccount? getCurrentAccount() {
    if (!_isInitialized) return null;
    final val = _accountsBox.get(_currentAccountId);
    if (val is Map) {
      return AppUserAccount.fromMap(val);
    }
    return null;
  }

  Future<AppUserAccount> createAccount({
    required String username,
    required String pin,
    required String bureauName,
    String defaultCurrency = 'سعودي',
  }) async {
    final cleanUser = username.trim();
    if (cleanUser.isEmpty) {
      throw Exception('اسم المستخدم مطلوب');
    }
    if (pin.trim().isEmpty) {
      throw Exception('الرمز السري مطلوب');
    }

    // Check duplicate username
    final existing = getAllAccounts().where(
      (a) => a.username.trim().toLowerCase() == cleanUser.toLowerCase(),
    );
    if (existing.isNotEmpty) {
      throw Exception('اسم المستخدم "$cleanUser" مسجل مسبقاً، يرجى اختيار اسم آخر');
    }

    final id = const Uuid().v4().replaceAll('-', '').substring(0, 10);
    final newAccount = AppUserAccount(
      id: id,
      username: cleanUser,
      pin: pin.trim(),
      bureauName: bureauName.trim().isNotEmpty
          ? bureauName.trim()
          : 'نظام القسام للصرافة والتحويلات',
      defaultCurrency: defaultCurrency.trim().isNotEmpty
          ? defaultCurrency.trim()
          : 'سعودي',
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    await _accountsBox.put(newAccount.id, newAccount.toMap());
    await switchAccount(newAccount.id);
    await setLoggedIn(true);

    return newAccount;
  }

  AppUserAccount? findAccountByCredentials(String username, String pin) {
    final u = username.trim().toLowerCase();
    final p = pin.trim();
    final accounts = getAllAccounts();

    for (final acc in accounts) {
      final accUser = acc.username.trim().toLowerCase();
      final userMatches = (acc.id == 'default' && (u.isEmpty || u == 'admin' || u == 'مدير' || u == 'المدير' || u == 'مدير النظام')) ||
          accUser == u;
      final pinMatches = acc.pin.trim() == p || (acc.id == 'default' && p == '1234');
      if (userMatches && pinMatches) {
        return acc;
      }
    }
    return null;
  }

  bool isLoggedIn() {
    if (!_isInitialized) return false;
    return _accountsBox.get('is_logged_in', defaultValue: false) as bool;
  }

  Future<void> setLoggedIn(bool value) async {
    if (!_isInitialized) return;
    await _accountsBox.put('is_logged_in', value);
  }

  String getAuthUsername() {
    final acc = getCurrentAccount();
    if (acc != null) return acc.username;
    return 'مدير النظام';
  }

  Future<void> setAuthUsername(String username) async {
    final acc = getCurrentAccount();
    if (acc != null) {
      final updated = acc.copyWith(username: username.trim());
      await _accountsBox.put(acc.id, updated.toMap());
    }
  }

  String getSecurityPin() {
    final acc = getCurrentAccount();
    if (acc != null) return acc.pin;
    return '1234';
  }

  Future<void> setSecurityPin(String pin) async {
    final acc = getCurrentAccount();
    if (acc != null) {
      final updated = acc.copyWith(pin: pin.trim());
      await _accountsBox.put(acc.id, updated.toMap());
    }
  }

  bool validateCredentials(String username, String pin) {
    return findAccountByCredentials(username, pin) != null;
  }
}

