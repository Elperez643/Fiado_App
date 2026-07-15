import 'package:flutter/foundation.dart';

const bool showDeveloperTools = bool.fromEnvironment(
  'SHOW_DEVELOPER_TOOLS',
  defaultValue: false,
);

bool isSyncDiagnosticsEnabled({
  required bool debugMode,
  required bool developerTools,
}) => debugMode || developerTools;

bool get syncDiagnosticsEnabled => isSyncDiagnosticsEnabled(
  debugMode: kDebugMode,
  developerTools: showDeveloperTools,
);
