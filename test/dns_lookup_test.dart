import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/dns_lookup.dart';
import 'package:server_box/data/model/app/dns_lookup.dart';
import 'package:server_box/data/model/app/ip_lookup.dart';

void main() {
  test('queries six record types and maps values with TTL', () async {
    final requested = <String>[];
    final service = DnsLookupService(
      dio: _dio((options) {
        expect(options.uri.host, 'dns.alidns.com');
        expect(options.uri.queryParameters['name'], 'example.com');
        expect(options.headers['Accept'], 'application/dns-json');
        final type = options.uri.queryParameters['type']!;
        requested.add(type);
        return _json({
          'Status': 0,
          'Answer': [
            {
              'name': 'example.com.',
              'type': DnsRecordType.values
                  .firstWhere((value) => value.label == type)
                  .code,
              'TTL': 300,
              'data': type == 'MX' ? '10 mail.example.com.' : 'record-$type',
            },
          ],
        });
      }),
    );

    final result = await service.lookup(' EXAMPLE.COM. ');
    expect(result.domain, 'example.com');
    expect(result.records, hasLength(6));
    expect(result.records.first.ttl, 300);
    expect(result.records.first.name, 'example.com');
    expect(
      result.records.singleWhere((r) => r.type == DnsRecordType.mx).value,
      '10 mail.example.com.',
    );
    expect(requested.toSet(), {'A', 'AAAA', 'CNAME', 'MX', 'NS', 'TXT'});
  });

  test(
    'rejects URLs, IP addresses and private domains before requests',
    () async {
      var calls = 0;
      final service = DnsLookupService(
        dio: _dio((_) {
          calls++;
          return _json({'Status': 0});
        }),
      );
      for (final input in [
        'https://example.com',
        '8.8.8.8',
        '192.168.1.1',
        'router.local',
        'example.internal',
        'example.com/path',
        'localhost',
      ]) {
        await expectLater(
          service.lookup(input),
          throwsA(
            isA<IpLookupFailure>().having(
              (value) => value.kind,
              'kind',
              IpLookupFailureKind.invalidInput,
            ),
          ),
        );
      }
      expect(calls, 0);
    },
  );

  test('returns partial records when one type is rate limited', () async {
    final service = DnsLookupService(
      dio: _dio((options) {
        if (options.uri.queryParameters['type'] == 'TXT') {
          return ResponseBody.fromString('limited', 429);
        }
        return _json({'Status': 0});
      }),
    );
    final result = await service.lookup('example.com');
    expect(result.records, isEmpty);
    expect(result.failedTypes, [DnsRecordType.txt]);
  });

  test('falls back to Cloudflare after Alibaba timeout', () async {
    final requests = <String>[];
    final dio = Dio()
      ..httpClientAdapter = _Adapter((options) {
        requests.add(
          '${options.uri.host}:${options.uri.queryParameters['type']}',
        );
        if (options.uri.host == 'dns.alidns.com') {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return _json({
          'Status': 0,
          'Answer': [
            {'name': 'example.com.', 'type': 1, 'TTL': 120, 'data': '1.1.1.1'},
          ],
        });
      });
    final result = await DnsLookupService(dio: dio).lookup('example.com');
    expect(result.records.single.value, '1.1.1.1');
    expect(
      requests.where((value) => value.startsWith('dns.alidns.com:')),
      hasLength(6),
    );
    expect(
      requests.where((value) => value.startsWith('cloudflare-dns.com:')),
      hasLength(6),
    );
  });

  test('does not send a second request after NXDOMAIN', () async {
    var requests = 0;
    final service = DnsLookupService(
      dio: _dio((_) {
        requests++;
        return _json({'Status': 3});
      }),
    );
    await expectLater(
      service.lookup('example.com'),
      throwsA(isA<IpLookupFailure>()),
    );
    expect(requests, 6);
  });

  test('falls back after resolver SERVFAIL', () async {
    var fallbackCalls = 0;
    final service = DnsLookupService(
      dio: _dio((options) {
        if (options.uri.host == 'dns.alidns.com') return _json({'Status': 2});
        fallbackCalls++;
        return _json({'Status': 0});
      }),
    );
    final result = await service.lookup('example.com');
    expect(result.failedTypes, isEmpty);
    expect(fallbackCalls, 6);
  });

  test('maps NXDOMAIN, malformed response and all-rate-limited', () async {
    for (final response in [
      _json({'Status': 3}),
      _json(['invalid']),
      ResponseBody.fromString('limited', 429),
    ]) {
      final service = DnsLookupService(dio: _dio((_) => response));
      await expectLater(
        service.lookup('example.com'),
        throwsA(isA<IpLookupFailure>()),
      );
    }
  });

  test('maps transport timeouts', () async {
    final dio = Dio()
      ..httpClientAdapter = _Adapter(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );
    final service = DnsLookupService(dio: dio);
    await expectLater(
      service.lookup('example.com'),
      throwsA(
        isA<IpLookupFailure>().having(
          (value) => value.kind,
          'kind',
          IpLookupFailureKind.timeout,
        ),
      ),
    );
  });
}

Dio _dio(ResponseBody Function(RequestOptions) response) =>
    Dio()..httpClientAdapter = _Adapter(response);

ResponseBody _json(Object value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.response);
  final ResponseBody Function(RequestOptions) response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => response(options);

  @override
  void close({bool force = false}) {}
}
