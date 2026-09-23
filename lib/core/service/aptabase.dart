import 'package:fl_lib/fl_lib.dart';

/// Legacy API retained without an analytics SDK, timer, or network transport.
abstract final class AptabaseAnalytics {
  static const host = '';
  static const appKey = '';
  static bool get availableInBuild => false;
  static bool get started => false;
  static Future<void> start() async {}
  static Future<void> stop() async {}
  static void capture(String event, Map<String, Object?> props) {}
}

/// No-op compatibility sink for existing diagnostics consumers.
final class AptabaseSink extends DiagnosticsSink {
  const AptabaseSink();
  static String eventName(Breadcrumb crumb) =>
      '${crumb.category.name}.${crumb.message}';
  @override
  void breadcrumb(Breadcrumb crumb) {}
  @override
  void tag(String key, String? value) {}
  @override
  void error(Object error, StackTrace? stack, {String? source}) {}
  @override
  void log(DiagLevel level, String message, {String? logger}) {}
  @override
  Future<void> flush() async {}
}
