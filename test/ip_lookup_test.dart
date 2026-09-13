import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/ip_lookup.dart';
import 'package:server_box/data/model/app/ip_lookup.dart';

void main() {
  test('discovers IPv4 and IPv6 independently', () async {
    final service = IpLookupService(
      dio: _dio((options) {
        final ip = options.uri.host == 'api6.ipify.org'
            ? '2001:4860:4860::8888'
            : '8.8.8.8';
        return _json({'ip': ip});
      }),
    );

    final result = await service.discoverPublicIps();

    expect(result.ipv4.address?.address, '8.8.8.8');
    expect(result.ipv6.address?.address, '2001:4860:4860::8888');
  });

  test('an unavailable IPv6 endpoint does not discard IPv4', () async {
    final service = IpLookupService(
      dio: _dio((options) {
        if (options.uri.host == 'api6.ipify.org') {
          return ResponseBody.fromString('unavailable', 503);
        }
        return _json({'ip': '8.8.8.8'});
      }),
    );

    final result = await service.discoverPublicIps();

    expect(result.ipv4.address?.address, '8.8.8.8');
    expect(result.ipv6.address, isNull);
    expect(result.ipv6.failure, isNotNull);
  });

  test('maps ipwho response to the display model', () async {
    final service = IpLookupService(
      dio: _dio(
        (_) => _json({
          'ip': '1.1.1.1',
          'success': true,
          'type': 'IPv4',
          'country': 'Australia',
          'country_code': 'AU',
          'region': 'Queensland',
          'city': 'South Brisbane',
          'latitude': -27.47,
          'longitude': 153.02,
          'flag': {'emoji': '🇦🇺'},
          'connection': {
            'asn': 13335,
            'org': 'Cloudflare, Inc.',
            'isp': 'Cloudflare',
            'domain': 'cloudflare.com',
          },
          'timezone': {'id': 'Australia/Brisbane', 'utc': '+10:00'},
        }),
      ),
    );

    final result = await service.lookup(
      InternetAddress('1.1.1.1'),
      languageCode: 'zh',
    );

    expect(result.organization, 'Cloudflare, Inc.');
    expect(result.asnLabel, 'AS13335');
    expect(result.networkDomain, 'cloudflare.com');
    expect(result.countryCode, 'AU');
  });

  test(
    'domain resolution keeps at most one public address per family',
    () async {
      final service = IpLookupService(
        resolver: (_) async => [
          InternetAddress('10.0.0.1'),
          InternetAddress('8.8.8.8'),
          InternetAddress('1.1.1.1'),
          InternetAddress('2001:4860:4860::8888'),
        ],
      );

      final result = await service.resolveInput('dns.example.net');

      expect(result.map((value) => value.address), [
        '8.8.8.8',
        '2001:4860:4860::8888',
      ]);
    },
  );

  test('rejects URLs and private addresses before networking', () async {
    final service = IpLookupService();

    await expectLater(
      service.resolveInput('https://example.com/a'),
      throwsA(
        isA<IpLookupFailure>().having(
          (value) => value.kind,
          'kind',
          IpLookupFailureKind.invalidInput,
        ),
      ),
    );
    await expectLater(
      service.resolveInput('192.168.1.1'),
      throwsA(
        isA<IpLookupFailure>().having(
          (value) => value.kind,
          'kind',
          IpLookupFailureKind.privateAddress,
        ),
      ),
    );
  });

  test('maps HTTP 429 to a rate-limit failure', () async {
    final service = IpLookupService(
      dio: _dio((_) => ResponseBody.fromString('limited', 429)),
    );

    await expectLater(
      service.lookup(InternetAddress('8.8.8.8'), languageCode: 'en'),
      throwsA(
        isA<IpLookupFailure>().having(
          (value) => value.kind,
          'kind',
          IpLookupFailureKind.rateLimited,
        ),
      ),
    );
  });

  test('maps timeout and malformed responses', () async {
    final timeoutService = IpLookupService(
      dio: _dioThrowing(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      ),
    );
    await expectLater(
      timeoutService.lookup(InternetAddress('8.8.8.8'), languageCode: 'en'),
      throwsA(
        isA<IpLookupFailure>().having(
          (value) => value.kind,
          'kind',
          IpLookupFailureKind.timeout,
        ),
      ),
    );

    final malformedService = IpLookupService(
      dio: _dio((_) => _json(['not', 'an', 'object'])),
    );
    await expectLater(
      malformedService.lookup(InternetAddress('8.8.8.8'), languageCode: 'en'),
      throwsA(
        isA<IpLookupFailure>().having(
          (value) => value.kind,
          'kind',
          IpLookupFailureKind.service,
        ),
      ),
    );
  });
}

Dio _dio(ResponseBody Function(RequestOptions options) response) =>
    Dio()..httpClientAdapter = _Adapter(response);

Dio _dioThrowing(DioException Function(RequestOptions options) error) =>
    Dio()..httpClientAdapter = _ThrowingAdapter(error);

ResponseBody _json(Object value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.response);

  final ResponseBody Function(RequestOptions options) response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => response(options);

  @override
  void close({bool force = false}) {}
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.error);

  final DioException Function(RequestOptions options) error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw error(options);

  @override
  void close({bool force = false}) {}
}
