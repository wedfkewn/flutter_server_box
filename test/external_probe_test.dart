import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/external_probe.dart';
import 'package:server_box/core/service/external_probe_controller.dart';
import 'package:server_box/data/model/app/external_probe.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/store/external_probe_preferences.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

ProbeTarget target(String id, {String address = 'https://example.com/',
  ProbeProtocol protocol = ProbeProtocol.http, String keyword = ''}) => ProbeTarget(
    id: id, name: id, address: address, category: ProbeCategory.custom,
    protocol: protocol, keyword: keyword);

void main() {
  test('catalog has unique validated targets and covers all categories', () {
    expect(ProbeCatalog.targets.length, 20);
    expect(ProbeCatalog.targets.map((e) => e.id).toSet().length, 20);
    for (final e in ProbeCatalog.targets) { expect(e.validationError, isNull, reason: e.name); }
    expect(ProbeCatalog.targets.map((e) => e.category).toSet(),
      ProbeCategory.values.where((e) => e != ProbeCategory.custom).toSet());
    // The Monitor whitelist must match the app catalog, including destinations.
    final rust = File('monitor/src/api/external_probes.rs').readAsStringSync();
    for (final e in ProbeCatalog.targets) {
      expect(rust, contains('"${e.id}" => "${e.address}"'), reason: e.id);
    }
  });

  test('rejects credentials, unsupported schemes, control chars and invalid ports', () {
    for (final address in ['file:///etc/passwd', 'http://user:secret@example.com/',
      'https://example.com/\nanything', 'https://example.com/with space']) {
      expect(target('custom_a', address: address).validationError, isNotNull);
    }
    expect(target('custom_a', protocol: ProbeProtocol.tcp, address: 'tcp://example.com:443').validationError, isNull);
    expect(target('custom_a', protocol: ProbeProtocol.tcp, address: 'tcp://example.com').validationError, isNotNull);
    expect(target('custom_a', protocol: ProbeProtocol.tcp, address: 'tcp://example.com:0').validationError, isNotNull);
    expect(target('custom_a', keyword: '\u0000').validationError, isNotNull);
    final command = ExternalProbe.command(SystemType.linux, [
      target('custom_a', address: "https://example.com/?q='\$()"),
    ]);
    expect(command, contains("'\\''"));
    expect(() => ExternalProbe.command(SystemType.linux, List.filled(4, target('custom_a'))), throwsArgumentError);
  });

  test('HTTP diagnostics retain evidence without inventing region restrictions', () {
    final t = target('custom_a');
    for (final pair in {200: 'httpResponse', 302: 'httpResponse',
      401: 'authentication', 403: 'accessDenied', 429: 'rateLimited', 503: 'serviceError'}.entries) {
      final r = ExternalProbe.classify(t, exitCode: 0, status: pair.key);
      expect(r.reason, pair.value);
      expect(r.state, pair.key < 400 ? ProbeState.reachable : ProbeState.rejected);
    }
    for (final pair in {6: 'dns', 7: 'connection', 28: 'timeout', 60: 'tls', 127: 'missingTool', 63: 'responseTooLarge'}.entries) {
      final r = ExternalProbe.classify(t, exitCode: pair.key, status: 200);
      expect(r.state, ProbeState.unknown); expect(r.reason, pair.value);
    }
    final keyword = target('custom_a', keyword: 'healthy');
    expect(ExternalProbe.classify(keyword, exitCode: 0, status: 200, keywordMatch: 0).reason, 'keywordMismatch');
    expect(ExternalProbe.classify(keyword, exitCode: 0, status: 200).state, ProbeState.unknown);
    expect(ExternalProbe.parse('noise\ncustom_a|0|200|0.234|1.2.3.4|-1\nother|0|200|1||-1', [t])['custom_a']?.elapsedMs, 234);
  });

  test('cache freshness differs by outcome and rejects future timestamps', () {
    final at = DateTime(2026);
    for (final state in ProbeState.values) {
      final r = ProbeResult(id: 'a', state: state, reason: 'test', checkedAt: at);
      expect(r.isFresh(at.add(r.ttl - const Duration(seconds: 1))), isTrue);
      expect(r.isFresh(at.add(r.ttl)), isFalse);
      expect(r.isFresh(at.subtract(const Duration(seconds: 1))), isFalse);
      expect(ProbeResult.fromJson(r.toJson()).checkedAt.isAtSameMomentAs(at), isTrue);
    }
    expect(ProbeResult(id: 'a', state: ProbeState.rejected, reason: 'rateLimited', checkedAt: at).ttl,
      const Duration(minutes: 1));
  });

  group('per-server configuration', () {
    late SettingStore store;
    setUp(() async { await openTestDb(); store = SettingStore('external_probe_prefs'); await store.init(); });
    tearDown(closeTestDb);
    test('default is manual; legacy opt-ins remain enabled without a destructive migration', () {
      expect(ExternalProbePreferences.load(store, 'one').autoCheck, isFalse);
      store.probeNetflix.put(true);
      final legacy = ExternalProbePreferences.load(store, 'one');
      expect(legacy.selected, {'netflix'}); expect(legacy.autoCheck, isTrue);
      final custom = target('custom_a', address: 'https://example.com/health', keyword: 'healthy');
      final config = ProbeConfig(selected: {'github', 'custom_a'}, pinned: ['github'], custom: [custom]);
      expect(ExternalProbePreferences.save(store, 'one', config), isTrue);
      final restored = ExternalProbePreferences.load(store, 'one');
      expect(restored.selected, config.selected); expect(restored.custom.single.keyword, 'healthy');
      expect(ExternalProbePreferences.load(store, 'two').selected, {'netflix'});
      ExternalProbePreferences.forget(store, 'one');
      expect(ExternalProbePreferences.load(store, 'one').selected, {'netflix'});
    });
  });

  group('shared queue', () {
    late ExternalProbeController controller;
    late List<List<ProbeTarget>> requests;
    late List<Completer<Map<String, ProbeResult>>> pending;
    late DateTime now;
    late Map<String, ProbeResult> cache;
    setUp(() {
      now = DateTime(2026); requests = []; pending = []; cache = {};
      controller = ExternalProbeController(
        config: ProbeConfig(selected: ProbeCatalog.targets.take(7).map((e) => e.id).toSet(), pinned: []),
        clock: () => now, save: (_) => true, readResult: (t) => cache[t.id],
        writeResult: (t, r) { cache[t.id] = r; }, runner: (batch) {
          requests.add(batch); final c = Completer<Map<String, ProbeResult>>(); pending.add(c); return c.future;
        });
    });
    tearDown(() => controller.dispose());
    void finish(int i) => pending[i].complete({for (final t in requests[i]) t.id:
      ProbeResult(id: t.id, state: ProbeState.reachable, reason: 'httpResponse', checkedAt: now)});

    test('batches are bounded, progress updates and duplicate starts coalesce', () async {
      final job = controller.run();
      await controller.run(); expect(requests.length, 1); expect(requests.first.length, 3);
      finish(0); await Future<void>.delayed(Duration.zero);
      expect(controller.completed, 3); expect(requests.length, 2);
      finish(1); await Future<void>.delayed(Duration.zero);
      expect(requests[2].length, 1); finish(2); await job;
      expect(controller.completed, 7); expect(cache.length, 7);
      await controller.run(); expect(requests.length, 3); expect(controller.error, 'cooldown:60');
      now = now.add(const Duration(minutes: 1));
      await controller.run(force: false); expect(requests.length, 3);
    });

    test('cancel discards late results and stops pending batches', () async {
      final job = controller.run(); controller.cancel();
      await controller.run(); expect(requests.length, 1);
      finish(0); await job;
      expect(requests.length, 1); expect(cache, isEmpty); expect(controller.cancelled, isTrue);
    });

    test('changing connection scope cannot save an old observation', () async {
      final job = controller.run(); controller.invalidate(); finish(0); await job;
      expect(cache, isEmpty); expect(controller.results, isEmpty);
    });

    test('automatic checks never connect when disabled or disconnected', () async {
      controller.maybeAutoCheck(true); await Future<void>.delayed(Duration.zero);
      expect(requests, isEmpty);
      controller.updateConfig(ProbeConfig(selected: controller.config.selected, pinned: [], autoCheck: true));
      controller.maybeAutoCheck(false); await Future<void>.delayed(Duration.zero); expect(requests, isEmpty);
      controller.maybeAutoCheck(true); controller.maybeAutoCheck(false);
      await Future<void>.delayed(Duration.zero); expect(requests, isEmpty);
    });

    test('transport failures stay inconclusive and do not stop later batches', () async {
      final job = controller.run(); pending.first.completeError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.results.values.every((e) => e.reason == 'transportError'), isTrue);
      finish(1); await Future<void>.delayed(Duration.zero); finish(2); await job;
      expect(controller.completed, 7);
    });

    test('manual cancellation does not immediately restart an automatic queue', () async {
      controller.updateConfig(ProbeConfig(selected: controller.config.selected, pinned: [], autoCheck: true));
      controller.maybeAutoCheck(true); await Future<void>.delayed(Duration.zero);
      expect(requests.length, 1); controller.cancel(); finish(0);
      await Future<void>.delayed(Duration.zero); await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(minutes: 2));
      controller.maybeAutoCheck(true); await Future<void>.delayed(Duration.zero);
      expect(requests.length, 1); expect(cache, isEmpty);
    });
  });

  test('Windows cmd launches PowerShell with UTF-8 stdin for HTTP, keywords and TCP', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      r.response.statusCode = r.uri.path == '/denied' ? 403 : 200;
      r.response.write("healthy '中文'"); await r.response.close();
    });
    try {
      final base = 'http://127.0.0.1:${server.port}';
      final targets = [target('custom_a', address: base, keyword: "healthy '中文'"),
        target('custom_b', address: '$base/denied'),
        target('custom_c', address: 'tcp://127.0.0.1:${server.port}', protocol: ProbeProtocol.tcp)];
      final process = await Process.start('cmd.exe', ['/d', '/s', '/c', ExternalProbe.windowsEntry]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.add(utf8.encode('${ExternalProbe.windowsInput(targets)}\n'));
      await process.stdin.close();
      expect(await process.exitCode, 0, reason: await stderr);
      final output = await stdout;
      final results = ExternalProbe.parse(output, targets);
      expect(results['custom_a']?.state, ProbeState.reachable, reason: '$output ${await stderr}');
      expect(results['custom_b']?.reason, 'accessDenied');
      expect(results['custom_c']?.state, ProbeState.reachable);
    } finally { await server.close(force: true); }
  }, skip: !Platform.isWindows);

  test('Unix curl probes real loopback HTTP and quotes custom values', () async {
    final shell = Platform.environment['SERVERBOX_TEST_SH'] ?? (Platform.isWindows ? null : '/bin/sh');
    if (shell == null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      r.response.statusCode = r.uri.path == '/denied' ? 403 : 200;
      r.response.write("healthy 'value'"); await r.response.close();
    });
    try {
      final t = target('custom_a', address: 'http://127.0.0.1:${server.port}/', keyword: "healthy 'value'");
      final targets = [t,
        target('custom_b', address: 'http://127.0.0.1:${server.port}/denied'),
        target('custom_c', address: 'tcp://127.0.0.1:${server.port}', protocol: ProbeProtocol.tcp)];
      final nativeDir = File(shell).parent.path;
      final process = await Process.run(shell, ['-c', ExternalProbe.command(SystemType.linux, targets)],
        environment: {'PATH': '$nativeDir${Platform.isWindows ? ';' : ':'}${Platform.environment['PATH'] ?? ''}'});
      expect(process.exitCode, 0, reason: '${process.stderr}');
      final results = ExternalProbe.parse('${process.stdout}', targets);
      expect(results[t.id]?.state, ProbeState.reachable,
        reason: '${process.stdout} ${process.stderr}');
      expect(results['custom_b']?.reason, 'accessDenied');
      expect(results['custom_c']?.state, ProbeState.reachable, reason: '${process.stdout}');
    } finally { await server.close(force: true); }
  });
}
