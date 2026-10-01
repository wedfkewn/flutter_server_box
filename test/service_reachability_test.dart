import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/service_reachability.dart';
import 'package:server_box/data/model/app/service_reachability.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/store/service_reachability_cache.dart';
import 'package:server_box/data/store/tables.dart';

void main() {
  group('probe command and output', () {
    test('uses only fixed URLs for selected Unix services', () {
      final command = ServiceReachability.command(SystemType.linux, {
        ServiceKind.chatGpt,
        ServiceKind.gemini,
      });
      expect(command, contains('https://chatgpt.com/'));
      expect(command, contains('https://gemini.google.com/'));
      expect(command, isNot(contains('netflix.com')));
      expect(command, contains('--max-time 8'));
    });

    test('builds a PowerShell probe and parses tolerant output', () {
      final command = ServiceReachability.command(SystemType.windows, {
        ServiceKind.netflix,
      });
      expect(command, contains('Invoke-WebRequest'));
      expect(command, contains('https://www.netflix.com/'));

      final result = ServiceReachability.parse(
        'noise\nchatGpt=reachable\r\nnetflix=unreachable\ngemini=unknown\n',
        checkedAt: DateTime(2026),
      );
      expect(result[ServiceKind.chatGpt]?.reachable, isTrue);
      expect(result[ServiceKind.netflix]?.reachable, isFalse);
      expect(
        result[ServiceKind.gemini]?.state,
        ServiceReachabilityState.unknown,
      );
    });

    test('classifies actual curl HTTP responses', () async {
      for (final (status, state) in [
        ('200', 'reachable'),
        ('204', 'reachable'),
        ('302', 'reachable'),
        ('403', 'unreachable'),
        ('503', 'unreachable'),
        ('000', 'unknown'),
        ('999', 'unknown'),
        ('2xx', 'unknown'),
        ('', 'unknown'),
      ]) {
        expect(
          await _runUnixProbe("curl() { printf '%s' '$status'; }"),
          'chatGpt=$state',
          reason: 'HTTP status $status',
        );
      }
    }, skip: _unixShell == null);

    test('curl DNS, TLS and timeout failures are inconclusive', () async {
      // curl exit 6 is DNS, 35 is TLS, and 28 is a timeout. A timeout may
      // follow an earlier HTTP response, so its printed code is insufficient.
      for (final exitCode in [6, 35, 28]) {
        expect(
          await _runUnixProbe(
            "curl() { printf '%s' '200'; return $exitCode; }",
          ),
          'chatGpt=unknown',
          reason: 'curl exit $exitCode',
        );
      }
    }, skip: _unixShell == null);

    test('wget uses the final response and preserves HTTP errors', () async {
      for (final (response, exitCode, state) in [
        ('  HTTP/1.1 200 OK', 0, 'reachable'),
        ('  HTTP/1.1 302 Found\n  HTTP/2 204 No Content', 0, 'reachable'),
        ('  HTTP/1.1 403 Forbidden', 8, 'unreachable'),
        ('  HTTP/1.1 503 Unavailable', 1, 'unreachable'),
        ('wget: unable to resolve host address', 4, 'unknown'),
        ('  HTTP/1.1 302 Found\nwget: TLS connection failed', 5, 'unknown'),
        ('  HTTP/1.1 200 OK\nwget: connection timed out', 4, 'unknown'),
        ('wget: unrecognized option', 2, 'unknown'),
      ]) {
        expect(
          await _runUnixProbe(
            'command() { [ "\$2" = wget ]; }\n'
            "wget() { printf '%s\\n' '$response'; return $exitCode; }",
          ),
          'chatGpt=$state',
          reason: 'wget exit $exitCode: $response',
        );
      }
    }, skip: _unixShell == null);

    test('missing Unix tools do not imply a blocked service', () async {
      expect(await _runUnixProbe('command() { return 1; }'), 'chatGpt=unknown');
      expect(
        ServiceReachability.command(SystemType.bsd, {ServiceKind.chatGpt}),
        ServiceReachability.command(SystemType.linux, {ServiceKind.chatGpt}),
      );
    }, skip: _unixShell == null);

    test('PowerShell separates HTTP rejection from transport failure', () async {
      final cases = [
        ('response', 200, 'reachable'),
        ('response', 302, 'reachable'),
        ('httpError', 403, 'unreachable'),
        ('httpError', 503, 'unreachable'),
        ('NameResolutionFailure', 0, 'unknown'),
        ('TrustFailure', 0, 'unknown'),
        ('Timeout', 0, 'unknown'),
        ('missing', 0, 'unknown'),
        ('response', 0, 'unknown'),
      ];
      final command = ServiceReachability.command(SystemType.windows, {
        ServiceKind.chatGpt,
      });
      final script = [
        // Override the cmdlet so this test never contacts a public service.
        // A response-bearing exception matches both Windows PowerShell's
        // WebException and newer PowerShell's HTTP response exception shape.
        r'''
Add-Type @'
public sealed class ProbeResponse {
  public int StatusCode { get; private set; }
  public ProbeResponse(int statusCode) { StatusCode = statusCode; }
}
public sealed class ProbeHttpException : System.Exception {
  public ProbeResponse Response { get; private set; }
  public ProbeHttpException(int statusCode) {
    Response = new ProbeResponse(statusCode);
  }
}
'@
function Invoke-WebRequest {
  if ($script:probeMode -eq 'httpError') {
    throw [ProbeHttpException]::new($script:probeStatus)
  }
  if ($script:probeMode -eq 'missing') {
    throw [System.Management.Automation.CommandNotFoundException]::new()
  }
  if ($script:probeMode -ne 'response') {
    throw [System.Net.WebException]::new(
      'Transport failure', [System.Net.WebExceptionStatus]$script:probeMode)
  }
  [PSCustomObject]@{ StatusCode = $script:probeStatus }
}
''',
        for (final (mode, status, _) in cases)
          "\$script:probeMode='$mode'; \$script:probeStatus=$status; $command",
      ].join('\n');
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        script,
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect('${result.stdout}'.trim().split(RegExp(r'[\r\n]+')), [
        for (final (_, _, state) in cases) 'chatGpt=$state',
      ]);
    }, skip: !Platform.isWindows);
  });

  group('derived cache', () {
    late ServiceReachabilityCacheStore store;

    setUp(() async {
      SqliteDb.openInMemory();
      await createTables(SqliteDb.instance);
      store = ServiceReachabilityCacheStore('service_reachability_test');
      await store.init();
    });

    tearDown(() async {
      await closeTables();
      await SqliteDb.close();
    });

    test('keeps success for 24 hours and failure for one hour', () {
      final at = DateTime(2026, 9, 12);
      store.put(
        'one',
        'host',
        ServiceReachabilityResult(
          service: ServiceKind.chatGpt,
          state: ServiceReachabilityState.reachable,
          checkedAt: at,
        ),
      );
      store.put(
        'one',
        'host',
        ServiceReachabilityResult(
          service: ServiceKind.netflix,
          state: ServiceReachabilityState.unreachable,
          checkedAt: at,
        ),
      );
      expect(
        store.fresh(
          'one',
          'host',
          ServiceKind.chatGpt,
          now: at.add(const Duration(hours: 23)),
        ),
        isNotNull,
      );
      expect(
        store.fresh(
          'one',
          'host',
          ServiceKind.netflix,
          now: at.add(const Duration(hours: 1)),
        ),
        isNull,
      );
    });

    test('separates targets and forgets a server', () {
      final result = ServiceReachabilityResult(
        service: ServiceKind.gemini,
        state: ServiceReachabilityState.reachable,
        checkedAt: DateTime.now(),
      );
      store.put('one', 'old-host', result);
      store.put('one', 'new-host', result);
      store.forgetServer('one');
      expect(store.fresh('one', 'old-host', ServiceKind.gemini), isNull);
      expect(store.fresh('one', 'new-host', ServiceKind.gemini), isNull);
    });
  });
}

Future<String> _runUnixProbe(String tools) async {
  final command = ServiceReachability.command(SystemType.linux, {
    ServiceKind.chatGpt,
  });
  final result = await Process.run(_unixShell!, [
    '-c',
    '$tools\n$command'.replaceAll('\r\n', '\n'),
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return '${result.stdout}'.trim();
}

// Windows can opt into the Unix cases using Git's sh (or another POSIX shell)
// without depending on WSL. Other platforms keep the normal /bin/sh default.
String? get _unixShell {
  final configured = Platform.environment['SERVERBOX_TEST_SH']?.trim();
  if (configured != null && configured.isNotEmpty) return configured;
  return Platform.isWindows ? null : '/bin/sh';
}
