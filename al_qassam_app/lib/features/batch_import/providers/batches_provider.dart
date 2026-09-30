import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../financial_engine/domain/models/batch_record.dart';
import '../../financial_engine/domain/services/financial_engine.dart';
import '../../financial_engine/domain/models/incoming_remittance.dart';
import '../../financial_engine/domain/models/outgoing_transfer.dart';
import '../../parsers/services/whatsapp_parser.dart';
import '../../parsers/services/outgoing_parser.dart';

/// State of batches list and active batch selection.
class BatchesState {
  final List<BatchRecord> batches;
  final String? activeBatchId;
  final bool isLoading;

  const BatchesState({
    required this.batches,
    this.activeBatchId,
    this.isLoading = false,
  });

  BatchRecord? get activeBatch {
    if (activeBatchId == null) return null;
    return batches.where((b) => b.id == activeBatchId).firstOrNull;
  }

  BatchesState copyWith({
    List<BatchRecord>? batches,
    String? activeBatchId,
    bool? isLoading,
  }) {
    return BatchesState(
      batches: batches ?? this.batches,
      activeBatchId: activeBatchId ?? this.activeBatchId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final batchesProvider = StateNotifierProvider<BatchesNotifier, BatchesState>((ref) {
  return BatchesNotifier();
});

class BatchesNotifier extends StateNotifier<BatchesState> {
  final _uuid = const Uuid();

  BatchesNotifier() : super(const BatchesState(batches: [], isLoading: true)) {
    loadBatches();
  }

  Future<void> loadBatches() async {
    await LocalStorageService.instance.recoverUnparsedBatches();
    final list = LocalStorageService.instance.getBatches();
    state = state.copyWith(
      batches: list,
      activeBatchId: list.isNotEmpty ? (state.activeBatchId ?? list.first.id) : null,
      isLoading: false,
    );
  }

  void selectBatch(String batchId) {
    state = state.copyWith(activeBatchId: batchId);
  }

  /// Creates a completely isolated incoming batch from pasted text.
  /// Enforces local storage and deduplication.
  Future<ImportResult> importIncomingPaste({
    required String rawText,
    required double exchangeRate,
    required String defaultCurrency,
    bool deduplicate = true,
  }) async {
    final batchId = _uuid.v4();

    // Parse WhatsApp raw bubbles
    final parseResult = WhatsAppParser.extractRecords(
      text: rawText,
      exchangeRate: exchangeRate,
      batchId: batchId,
    );
    final parsedRecords = parseResult.records;

    // Compute totals
    final totals = FinancialEngine.calculateTotals(parsedRecords);

    final batch = BatchRecord(
      id: batchId,
      title: 'دفعة وارد #${state.batches.where((b) => b.type == BatchType.incoming).length + 1}',
      type: BatchType.incoming,
      exchangeRate: exchangeRate,
      count: totals.totalCount,
      totalAmount: totals.totalAmountOrig,
      totalBirr: totals.totalBirr.toDouble(),
      totalCutCents: totals.totalCutCents,
      smallBirrTotal: totals.smallBirrTotal,
      largeBirrTotal: totals.largeBirrTotal,
      rawText: rawText,
    );

    final result = await LocalStorageService.instance.saveIncomingBatch(
      batch: batch,
      remittances: parsedRecords,
      preventDuplicatesAcrossBatches: deduplicate,
    );

    // Reload state and select the newly created isolated batch
    final updatedList = LocalStorageService.instance.getBatches();
    state = state.copyWith(
      batches: updatedList,
      activeBatchId: batchId,
    );

    return result;
  }

  /// Creates a completely isolated outgoing batch from pasted text.
  Future<ImportResult> importOutgoingPaste({
    required String rawText,
    required String defaultCurrency,
    bool deduplicate = true,
  }) async {
    final batchId = _uuid.v4();

    final parseResult = OutgoingParser.parseOutgoingText(
      text: rawText,
      batchId: batchId,
      defaultCurrency: defaultCurrency,
    );
    final parsedTransfers = parseResult.records;

    double totalAmount = 0.0;
    for (final t in parsedTransfers) {
      totalAmount += t.amount;
    }

    final batch = BatchRecord(
      id: batchId,
      title: 'دفعة صادر #${state.batches.where((b) => b.type == BatchType.outgoing).length + 1}',
      type: BatchType.outgoing,
      exchangeRate: 0.0,
      count: parsedTransfers.length,
      totalAmount: totalAmount,
      totalBirr: 0,
      rawText: rawText,
    );

    final result = await LocalStorageService.instance.saveOutgoingBatch(
      batch: batch,
      transfers: parsedTransfers,
      preventDuplicatesAcrossBatches: deduplicate,
    );

    final updatedList = LocalStorageService.instance.getBatches();
    state = state.copyWith(
      batches: updatedList,
      activeBatchId: batchId,
    );

    return result;
  }

  Future<void> deleteBatch(String batchId) async {
    await LocalStorageService.instance.deleteBatch(batchId);
    final updatedList = LocalStorageService.instance.getBatches();
    state = state.copyWith(
      batches: updatedList,
      activeBatchId: updatedList.isNotEmpty ? updatedList.first.id : null,
    );
  }

  Future<void> updateIncomingRemittance(IncomingRemittance updated) async {
    await LocalStorageService.instance.updateIncomingRemittance(updated);
    final updatedList = LocalStorageService.instance.getBatches();
    state = state.copyWith(batches: updatedList);
  }

  Future<void> deleteIncomingRemittance(String id) async {
    await LocalStorageService.instance.deleteIncomingRemittance(id);
    final updatedList = LocalStorageService.instance.getBatches();
    state = state.copyWith(batches: updatedList);
  }

  Future<void> updateOutgoingTransfer(OutgoingTransfer updated) async {
    await LocalStorageService.instance.updateOutgoingTransfer(updated);
    final updatedList = LocalStorageService.instance.getBatches();
    state = state.copyWith(batches: updatedList);
  }

  Future<void> deleteOutgoingTransfer(String id) async {
    await LocalStorageService.instance.deleteOutgoingTransfer(id);
    final updatedList = LocalStorageService.instance.getBatches();
    state = state.copyWith(batches: updatedList);
  }
}
