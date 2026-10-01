import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/service_reachability.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

void main() {
  late HttpServer server;
  late MonitorHttpClient client;
  late List<({String method, String path, String? authorization, Object? body})>
  requests;
  late Object? responseBody;
  late int responseStatus;
  late int expiredProbes;
  late int logins;

  setUp(() async {
    requests = [];
    responseStatus = HttpStatus.ok;
    expiredProbes = 0;
    logins = 0;
    responseBody = {
      'checked_at': '2026-10-01T00:00:00Z',
      'results': {'chatGpt': 'reachable', 'netflix': 'unreachable'},
    };
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      requests.add((
        method: request.method,
        path: request.uri.path,
        authorization: request.headers.value(HttpHeaders.authorizationHeader),
        body: text.isEmpty ? null : jsonDecode(text),
      ));
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/v1/login') {
        logins++;
        request.response.write(jsonEncode({'token': 'token-$logins'}));
      } else if (request.uri.path == '/api/v1/service-reachability') {
        if (expiredProbes > 0) {
          expiredProbes--;
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.write(jsonEncode({'error': 'Token expired'}));
        } else {
          request.response.statusCode = responseStatus;
          request.response.write(jsonEncode(responseBody));
        }
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.write(jsonEncode({'error': 'Command access is off'}));
      }
      await request.response.close();
    });
    client = MonitorHttpClient(
      MonitorHttpCredential(
        addr: 'http://${server.address.address}:${server.port}',
        user: 'user',
        pwd: 'password',
      ),
    );
  });

  tearDown(() async {
    client.dispose();
    await server.close(force: true);
  });

  test(
    'probes use the dedicated authenticated API without command access',
    () async {
      final results = await client.serviceReachability({
        ServiceKind.chatGpt,
        ServiceKind.netflix,
      });

      expect(requests.map((request) => request.path), [
        '/api/v1/login',
        '/api/v1/service-reachability',
      ]);
      final probe = requests.last;
      expect(probe.method, 'POST');
      expect(probe.authorization, 'Bearer token-1');
      expect(
        (probe.body as Map)['services'],
        unorderedEquals(['chatGpt', 'netflix']),
      );
      expect(
        results[ServiceKind.chatGpt]?.state,
        ServiceReachabilityState.reachable,
      );
      expect(
        results[ServiceKind.netflix]?.state,
        ServiceReachabilityState.unreachable,
      );
      for (final result in results.values) {
        expect(result.checkedAt, DateTime.utc(2026, 10, 1));
      }
    },
  );

  test(
    'each requested service keeps its own state and ignores unsolicited results',
    () async {
      responseBody = {
        'checked_at': '2026-10-01T00:00:00Z',
        'results': {
          'chatGpt': 'unreachable',
          'netflix': 'reachable',
          'gemini': 'reachable',
        },
      };

      final results = await client.serviceReachability({
        ServiceKind.chatGpt,
        ServiceKind.netflix,
      });

      expect(
        results.keys,
        unorderedEquals([ServiceKind.chatGpt, ServiceKind.netflix]),
      );
      expect(
        results[ServiceKind.chatGpt]?.state,
        ServiceReachabilityState.unreachable,
      );
      expect(
        results[ServiceKind.netflix]?.state,
        ServiceReachabilityState.reachable,
      );
    },
  );

  test(
    'unknown, omitted and future result states never become reachable',
    () async {
      for (final states in [
        {'chatGpt': 'unknown', 'netflix': 'unknown'},
        {'chatGpt': 'new-agent-state'},
        <String, Object?>{},
      ]) {
        responseBody = {'results': states};
        final results = await client.serviceReachability({
          ServiceKind.chatGpt,
          ServiceKind.netflix,
        });

        expect(results.length, 2);
        for (final result in results.values) {
          expect(result.state, ServiceReachabilityState.unknown);
          expect(result.reachable, isFalse);
        }
      }
      expect(logins, 1);
    },
  );

  test(
    'absent or unparseable timestamps fall back to the local check time',
    () async {
      for (final timestamp in [null, 'not-a-timestamp']) {
        responseBody = {
          'checked_at': ?timestamp,
          'results': {'chatGpt': 'reachable'},
        };
        final before = DateTime.now();
        final results = await client.serviceReachability({ServiceKind.chatGpt});
        final after = DateTime.now();
        final checkedAt = results[ServiceKind.chatGpt]!.checkedAt;

        expect(checkedAt.isBefore(before), isFalse);
        expect(checkedAt.isAfter(after), isFalse);
      }
    },
  );

  test('malformed result envelopes surface as response errors', () async {
    for (final body in [
      <String, Object?>{},
      {'results': []},
      {'results': 'reachable'},
      {
        'checked_at': 1234,
        'results': {'chatGpt': 'reachable'},
      },
      ['reachable'],
    ]) {
      responseBody = body;

      await expectLater(
        client.serviceReachability({ServiceKind.chatGpt}),
        throwsA(
          isA<MonitorHttpErr>().having(
            (error) => error.type,
            'type',
            MonitorHttpErrType.invalidResponse,
          ),
        ),
      );
    }
  });

  test('429 surfaces without retrying or inventing a service result', () async {
    responseStatus = HttpStatus.tooManyRequests;
    responseBody = {'error': 'Checks are limited to once per minute'};

    await expectLater(
      client.serviceReachability({ServiceKind.chatGpt, ServiceKind.netflix}),
      throwsA(
        isA<MonitorHttpErr>()
            .having((error) => error.type, 'type', MonitorHttpErrType.unknown)
            .having((error) => error.message, 'message', contains('429')),
      ),
    );
    expect(requests.length, 2);
    expect(logins, 1);

    responseStatus = HttpStatus.ok;
    responseBody = {
      'results': {'netflix': 'reachable'},
    };
    final results = await client.serviceReachability({ServiceKind.netflix});
    expect(
      results[ServiceKind.netflix]?.state,
      ServiceReachabilityState.reachable,
    );
    expect(logins, 1);
    expect(requests.length, 3);
  });

  test(
    'an older agent without the endpoint reports an error without exec fallback',
    () async {
      responseStatus = HttpStatus.notFound;
      responseBody = {'error': 'Unknown endpoint'};

      await expectLater(
        client.serviceReachability({ServiceKind.chatGpt}),
        throwsA(
          isA<MonitorHttpErr>().having(
            (error) => error.message,
            'message',
            contains('404'),
          ),
        ),
      );
      expect(requests.map((request) => request.path), [
        '/api/v1/login',
        '/api/v1/service-reachability',
      ]);
    },
  );

  test(
    'a late 401 refreshes the token once before retrying the probe',
    () async {
      expiredProbes = 1;

      final results = await client.serviceReachability({ServiceKind.chatGpt});

      expect(
        results[ServiceKind.chatGpt]?.state,
        ServiceReachabilityState.reachable,
      );
      expect(logins, 2);
      expect(requests.map((request) => request.path), [
        '/api/v1/login',
        '/api/v1/service-reachability',
        '/api/v1/login',
        '/api/v1/service-reachability',
      ]);
      expect(requests.last.authorization, 'Bearer token-2');
    },
  );
}
