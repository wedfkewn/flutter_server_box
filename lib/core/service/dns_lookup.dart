import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:server_box/core/utils/private_address.dart';
import 'package:server_box/data/model/app/dns_lookup.dart';
import 'package:server_box/data/model/app/ip_lookup.dart';

/// Explicit, on-demand DNS queries through public JSON DoH resolvers.
class DnsLookupService {
  DnsLookupService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
              sendTimeout: const Duration(seconds: 4),
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;
  static const _resolvers = [
    'https://dns.alidns.com/resolve',
    'https://cloudflare-dns.com/dns-query',
  ];

  static String normalizeDomain(String raw) {
    final input = raw.trim().toLowerCase();
    final domain = input.endsWith('.')
        ? input.substring(0, input.length - 1)
        : input;
    if (domain.isEmpty ||
        domain.length > 253 ||
        InternetAddress.tryParse(domain) != null ||
        isPrivateHost(domain) ||
        domain.contains('://') ||
        domain.contains('/') ||
        domain.contains(':') ||
        domain.contains('@') ||
        domain.contains('?') ||
        domain.contains('#')) {
      throw const IpLookupFailure(IpLookupFailureKind.invalidInput);
    }
    final labels = domain.split('.');
    if (labels.length < 2 ||
        labels.any(
          (label) =>
              label.isEmpty ||
              label.length > 63 ||
              label.startsWith('-') ||
              label.endsWith('-') ||
              !RegExp(r'^[a-z0-9_-]+$').hasMatch(label),
        )) {
      throw const IpLookupFailure(IpLookupFailureKind.invalidInput);
    }
    return domain;
  }

  Future<DnsLookupResult> lookup(String raw, {CancelToken? cancelToken}) async {
    final domain = normalizeDomain(raw);
    final answers = await Future.wait([
      for (final type in DnsRecordType.values)
        _query(domain, type, cancelToken),
    ]);
    if (cancelToken?.isCancelled == true) {
      throw const IpLookupFailure(IpLookupFailureKind.network);
    }

    final records = <String, DnsRecord>{};
    final failed = <DnsRecordType>[];
    IpLookupFailure? firstFailure;
    var succeeded = false;
    var nxdomain = false;
    for (var i = 0; i < answers.length; i++) {
      final answer = answers[i];
      if (answer.failure case final failure?) {
        firstFailure ??= failure;
        failed.add(DnsRecordType.values[i]);
        continue;
      }
      if (answer.nxdomain) {
        nxdomain = true;
        continue;
      }
      succeeded = true;
      for (final record in answer.records) {
        records.putIfAbsent(
          '${record.name}|${record.type.code}|${record.value}',
          () => record,
        );
      }
    }
    if (!succeeded && nxdomain) {
      throw const IpLookupFailure(IpLookupFailureKind.dns);
    }
    if (!succeeded && firstFailure != null) throw firstFailure;
    final sorted = records.values.toList()
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
    return DnsLookupResult(
      domain: domain,
      records: sorted,
      failedTypes: failed,
    );
  }

  Future<_DnsAnswer> _query(
    String domain,
    DnsRecordType type,
    CancelToken? cancelToken,
  ) async {
    _DnsAnswer? lastFailure;
    for (final resolver in _resolvers) {
      if (cancelToken?.isCancelled == true) {
        return const _DnsAnswer(
          failure: IpLookupFailure(IpLookupFailureKind.network),
        );
      }
      final answer = await _queryFrom(resolver, domain, type, cancelToken);
      if (answer.failure == null ||
          answer.failure?.kind == IpLookupFailureKind.dns) {
        return answer;
      }
      lastFailure = answer;
    }
    return lastFailure!;
  }

  Future<_DnsAnswer> _queryFrom(
    String resolver,
    String domain,
    DnsRecordType type,
    CancelToken? cancelToken,
  ) async {
    try {
      final response = await _dio.get<Object?>(
        resolver,
        queryParameters: {'name': domain, 'type': type.label},
        options: Options(headers: {'Accept': 'application/dns-json'}),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body is! Map || body['Status'] is! int) {
        throw const IpLookupFailure(IpLookupFailureKind.service);
      }
      if (body['Status'] == 3) return const _DnsAnswer(nxdomain: true);
      if (body['Status'] != 0) {
        throw IpLookupFailure(
          IpLookupFailureKind.service,
          'DNS status ${body['Status']}',
        );
      }
      final rawRecords = body['Answer'];
      if (rawRecords != null && rawRecords is! List) {
        throw const IpLookupFailure(IpLookupFailureKind.service);
      }
      final records = <DnsRecord>[];
      for (final item in rawRecords ?? const []) {
        if (item is! Map ||
            item['name'] is! String ||
            item['type'] is! int ||
            item['data'] is! String ||
            item['TTL'] is! int) {
          throw const IpLookupFailure(IpLookupFailureKind.service);
        }
        final recordType = DnsRecordType.fromCode(item['type'] as int);
        if (recordType == null) continue;
        final value = (item['data'] as String).trim();
        if (value.isEmpty) continue;
        records.add(
          DnsRecord(
            name: (item['name'] as String).replaceFirst(RegExp(r'\.$'), ''),
            type: recordType,
            value: value,
            ttl: (item['TTL'] as int).clamp(0, 2147483647),
          ),
        );
      }
      return _DnsAnswer(records: records);
    } on IpLookupFailure catch (failure) {
      return _DnsAnswer(failure: failure);
    } on DioException catch (error) {
      final failure = switch (error) {
        DioException(response: Response(statusCode: 429)) =>
          const IpLookupFailure(IpLookupFailureKind.rateLimited),
        DioException(response: Response(statusCode: 504)) =>
          const IpLookupFailure(IpLookupFailureKind.timeout),
        DioException(response: Response(statusCode: final status?))
            when status >= 500 =>
          const IpLookupFailure(IpLookupFailureKind.service),
        DioException(
          type: DioExceptionType.connectionTimeout ||
              DioExceptionType.receiveTimeout ||
              DioExceptionType.sendTimeout,
        ) =>
          const IpLookupFailure(IpLookupFailureKind.timeout),
        _ => const IpLookupFailure(IpLookupFailureKind.network),
      };
      return _DnsAnswer(failure: failure);
    } on TimeoutException {
      return const _DnsAnswer(
        failure: IpLookupFailure(IpLookupFailureKind.timeout),
      );
    } catch (error) {
      return _DnsAnswer(
        failure: IpLookupFailure(IpLookupFailureKind.service, '$error'),
      );
    }
  }
}

final class _DnsAnswer {
  const _DnsAnswer({
    this.records = const [],
    this.nxdomain = false,
    this.failure,
  });

  final List<DnsRecord> records;
  final bool nxdomain;
  final IpLookupFailure? failure;
}
