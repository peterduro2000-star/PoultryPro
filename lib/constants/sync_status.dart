/// Canonical sync status constants used across models, DB, and SyncService.
/// Every business record carries one of these values in its syncStatus column.
class SyncStatus {
  SyncStatus._();

  /// Created or modified locally, never sent to Supabase.
  static const String local = 'local';

  /// Modified locally, queued in sync_queue, not yet pushed.
  static const String pending = 'pending';

  /// Successfully pushed to / pulled from Supabase.
  static const String synced = 'synced';

  /// Local and server versions conflict — needs resolution.
  static const String conflict = 'conflict';

  static const List<String> all = [local, pending, synced, conflict];
}