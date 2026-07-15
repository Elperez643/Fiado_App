class SyncFeatureFlags {
  // Phase 0: the legacy cloud sync remains in the codebase but is isolated from
  // automatic execution while the modular engine is built out.
  static const bool useNewSyncEngine = true;
  static const bool enableLegacySync = false;
}
