import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/external_probe.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';

void main() {
  late HttpServer server;
  late MonitorHttpClient client;
  late List<String> paths;
  late Object? response;
  late int status;
  late bool expired;
  setUp(() async {
    paths = []; status = 200; expired = false;
    response = {'results': [ProbeResult(id: 'github', state: ProbeState.reachable,
      reason: 'httpResponse', checkedAt: DateTime.utc(2026), httpStatus: 200,
      elapsedMs: 250, transport: 'Monitor').toJson()]};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      paths.add(request.uri.path);
      final body = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/v1/login') {
        request.response.write(jsonEncode({'token': 'test-token'}));
      } else if (request.uri.path == '/api/v1/external-probes') {
        expect(request.headers.value('authorization'), 'Bearer test-token');
        final targets = (jsonDecode(body) as Map)['targets'] as List;
        expect((targets.single as Map)['id'], 'github');
        request.response.statusCode = expired ? 401 : status;
        request.response.write(jsonEncode(expired ? {'error': 'expired'} : response));
        expired = false;
      } else { request.response.statusCode = 403; }
      await request.response.close();
    });
    client = MonitorHttpClient(MonitorHttpCredential(addr: 'http://127.0.0.1:${server.port}', user: 'user', pwd: 'pass'));
  });
  tearDown(() async { client.dispose(); await server.close(force: true); });

  test('uses dedicated authenticated probes without exec permission', () async {
    final result = await client.externalProbes([ProbeCatalog.targets.firstWhere((e) => e.id == 'github')]);
    expect(result['github']?.httpStatus, 200); expect(result['github']?.elapsedMs, 250);
    expect(paths, ['/api/v1/login', '/api/v1/external-probes']);
  });
  test('a cold Monitor-only server uses probes before any status poll or shell', () async {
    final credential = MonitorHttpCredential(addr: 'http://127.0.0.1:${server.port}', user: 'user', pwd: 'pass');
    final fake = _ColdMonitorServer(credential);
    final container = ProviderContainer(overrides: [serverProvider('cold').overrideWith(() => fake)]);
    try {
      final result = await container.read(serverProvider('cold').notifier)
        .probeExternalServices([ProbeCatalog.targets.firstWhere((e) => e.id == 'github')]);
      expect(result['github']?.state, ProbeState.reachable);
      expect(paths, ['/api/v1/login', '/api/v1/external-probes']);
    } finally { container.dispose(); }
  });
  test('old agents and permission errors have actionable inconclusive results', () async {
    for (final item in {404: 'agentUpgrade', 403: 'permission', 429: 'rateLimited'}.entries) {
      status = item.key; response = {'error': 'unavailable'};
      final result = await client.externalProbes([ProbeCatalog.targets.firstWhere((e) => e.id == 'github')]);
      expect(result['github']?.state, ProbeState.unknown); expect(result['github']?.reason, item.value);
    }
    expect(paths.where((e) => e.endsWith('/exec')), isEmpty);
  });
  test('token refresh retries once, while unsolicited and invalid results are ignored', () async {
    expired = true;
    final results = await client.externalProbes([ProbeCatalog.targets.firstWhere((e) => e.id == 'github')]);
    expect(results['github']?.state, ProbeState.reachable);
    expect(paths.where((e) => e.endsWith('/login')).length, 2);
    response = {'results': [{'id': 'github', 'state': 'new-agent-state'},
      ProbeResult(id: 'google', state: ProbeState.reachable, reason: 'httpResponse', checkedAt: DateTime.now()).toJson()]};
    expect(await client.externalProbes([ProbeCatalog.targets.firstWhere((e) => e.id == 'github')]), isEmpty);
  });
}

class _ColdMonitorServer extends ServerNotifier {
  _ColdMonitorServer(this.credential);
  final MonitorHttpCredential credential;
  @override
  ServerState build(String id) => ServerState(spi: Spi(id: id, name: 'Cold Monitor',
    monitorHttp: credential, autoConnect: false), status: InitStatus.status);
  @override
  Future<ServerExec> ensureExec() => throw StateError('A built-in Monitor probe must not call exec');
}
