import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../batch_import/providers/batches_provider.dart';
import '../../financial_engine/domain/models/outgoing_transfer.dart';

/// Provider for outgoing transfers of the strictly active batch.
final outgoingTransfersProvider = Provider<List<OutgoingTransfer>>((ref) {
  final batchesState = ref.watch(batchesProvider);
  final activeBatchId = batchesState.activeBatchId;

  if (activeBatchId == null) return [];

  return LocalStorageService.instance.getOutgoingTransfers(activeBatchId);
});
