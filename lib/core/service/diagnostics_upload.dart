import 'package:server_box/data/model/app/diagnostics_level.dart';

// Retained for stored consent-version compatibility. This edition has no
// remote diagnostics destinations; local logs and manual crash reports remain.
const kDiagnosticsConsentVer = 1;

abstract final class DiagnosticsUpload {
  static const dsn = '';
  static bool get availableInBuild => false;
  static DiagnosticsLevel get level => DiagnosticsLevel.none;
  static bool get uploading => false;
  static Future<void> sync() async {}
}
