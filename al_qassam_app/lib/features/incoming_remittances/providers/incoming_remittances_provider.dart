import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../batch_import/providers/batches_provider.dart';
import '../../financial_engine/domain/models/incoming_remittance.dart';
import '../../financial_engine/domain/services/financial_engine.dart';

/// Provider for incoming remittances of the strictly active batch.
final incomingRemittancesProvider = Provider<List<IncomingRemittance>>((ref) {
  final batchesState = ref.watch(batchesProvider);
  final activeBatchId = batchesState.activeBatchId;

  if (activeBatchId == null) return [];

  // Return strictly the records for this isolated batch
  return LocalStorageService.instance.getIncomingRemittances(activeBatchId);
});

/// Provider for calculated totals of the active batch.
final incomingTotalsProvider = Provider<FinancialTotals>((ref) {
  final records = ref.watch(incomingRemittancesProvider);
  return FinancialEngine.calculateTotals(records);
});
