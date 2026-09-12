import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:server_box/core/utils/private_address.dart';
import 'package:server_box/data/model/app/ip_lookup.dart';

class IpLookupService {
  IpLookupService({Dio? dio, this.resolver = InternetAddress.lookup})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
              sendTimeout: const Duration(seconds: 6),
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  @visibleForTesting
  final Future<List<InternetAddress>> Function(String host) resolver;

  Future<PublicIpPair> discoverPublicIps({CancelToken? cancelToken}) async {
    final values = await Future.wait([
      _discover('https://api.ipify.org', InternetAddressType.IPv4, cancelToken),
      _discover(
        'https://api6.ipify.org',
        InternetAddressType.IPv6,
        cancelToken,
      ),
    ]);
    return PublicIpPair(ipv4: values[0], ipv6: values[1]);
  }

  Future<PublicIpResult> _discover(
    String url,
    InternetAddressType expected,
    CancelToken? cancelToken,
  ) async {
    try {
      final response = await _dio.get<Object?>(
        url,
        queryParameters: const {'format': 'json'},
        cancelToken: cancelToken,
      );
      final data = response.data;
      final text = data is Map ? data['ip']?.toString() : null;
      final address = text == null ? null : InternetAddress.tryParse(text);
      if (address == null || unwrapV4Mapped(address).type != expected) {
        return const PublicIpResult(
          failure: IpLookupFailure(IpLookupFailureKind.service),
        );
      }
      return PublicIpResult(address: unwrapV4Mapped(address));
    } on DioException catch (error) {
      return PublicIpResult(failure: _fromDio(error));
    } catch (error) {
      return PublicIpResult(
        failure: IpLookupFailure(IpLookupFailureKind.service, '$error'),
      );
    }
  }

  Future<List<InternetAddress>> resolveInput(String raw) async {
    final input = raw.trim();
    if (input.isEmpty ||
        input.contains('://') ||
        input.contains('/') ||
        input.contains('?') ||
        input.contains('#') ||
        input.contains('@')) {
      throw const IpLookupFailure(IpLookupFailureKind.invalidInput);
    }

    final literal = InternetAddress.tryParse(input);
    if (literal != null) {
      final address = unwrapV4Mapped(literal);
      if (isPrivateAddress(address)) {
        throw const IpLookupFailure(IpLookupFailureKind.privateAddress);
      }
      return [address];
    }

    if (input.contains(':') || isPrivateHost(input)) {
      throw const IpLookupFailure(IpLookupFailureKind.invalidInput);
    }

    try {
      final resolved = await resolver(
        input,
      ).timeout(const Duration(seconds: 6));
      final byFamily = <InternetAddressType, InternetAddress>{};
      for (final rawAddress in resolved) {
        final address = unwrapV4Mapped(rawAddress);
        if (isPrivateAddress(address)) continue;
        byFamily.putIfAbsent(address.type, () => address);
      }
      final result = [
        ?byFamily[InternetAddressType.IPv4],
        ?byFamily[InternetAddressType.IPv6],
      ];
      if (result.isEmpty) {
        throw const IpLookupFailure(IpLookupFailureKind.privateAddress);
      }
      return result;
    } on IpLookupFailure {
      rethrow;
    } on TimeoutException catch (error) {
      throw IpLookupFailure(IpLookupFailureKind.timeout, '$error');
    } catch (error) {
      throw IpLookupFailure(IpLookupFailureKind.dns, '$error');
    }
  }

  Future<IpLookupResult> lookup(
    InternetAddress address, {
    required String languageCode,
    CancelToken? cancelToken,
  }) async {
    final normalized = unwrapV4Mapped(address);
    if (isPrivateAddress(normalized)) {
      throw const IpLookupFailure(IpLookupFailureKind.privateAddress);
    }

    try {
      final response = await _dio.get<Object?>(
        'https://ipwho.is/${Uri.encodeComponent(normalized.address)}',
        queryParameters: {
          'lang': _apiLanguage(languageCode),
          'fields':
              'ip,success,message,type,country,country_code,region,city,'
              'latitude,longitude,flag.emoji,connection.asn,connection.org,'
              'connection.isp,connection.domain,timezone.id,timezone.utc',
        },
        cancelToken: cancelToken,
      );
      final raw = response.data;
      if (raw is! Map) {
        throw const IpLookupFailure(IpLookupFailureKind.service);
      }
      if (raw['success'] != true) {
        throw IpLookupFailure(
          IpLookupFailureKind.service,
          raw['message']?.toString(),
        );
      }
      final connection = raw['connection'] is Map
          ? raw['connection'] as Map
          : const {};
      final timezone = raw['timezone'] is Map
          ? raw['timezone'] as Map
          : const {};
      final flag = raw['flag'] is Map ? raw['flag'] as Map : const {};
      return IpLookupResult(
        ip: raw['ip']?.toString() ?? normalized.address,
        type:
            raw['type']?.toString() ??
            (normalized.type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4'),
        country: _string(raw['country']),
        countryCode: _string(raw['country_code']),
        region: _string(raw['region']),
        city: _string(raw['city']),
        latitude: (raw['latitude'] as num?)?.toDouble(),
        longitude: (raw['longitude'] as num?)?.toDouble(),
        isp: _string(connection['isp']),
        organization: _string(connection['org']),
        asn: (connection['asn'] as num?)?.toInt(),
        networkDomain: _string(connection['domain']),
        timezone: _string(timezone['id']),
        utcOffset: _string(timezone['utc']),
        flagEmoji: _string(flag['emoji']),
        fetchedAt: DateTime.now(),
      );
    } on IpLookupFailure {
      rethrow;
    } on DioException catch (error) {
      throw _fromDio(error);
    } catch (error) {
      throw IpLookupFailure(IpLookupFailureKind.service, '$error');
    }
  }

  static String _apiLanguage(String languageCode) => switch (languageCode) {
    'zh' => 'zh-CN',
    'de' || 'es' || 'fr' || 'ja' || 'pt' || 'ru' => languageCode,
    _ => 'en',
  };

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static IpLookupFailure _fromDio(DioException error) {
    if (CancelToken.isCancel(error)) {
      return IpLookupFailure(IpLookupFailureKind.network, '$error');
    }
    if (error.response?.statusCode == 429) {
      return const IpLookupFailure(IpLookupFailureKind.rateLimited);
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return IpLookupFailure(IpLookupFailureKind.timeout, '$error');
    }
    return IpLookupFailure(IpLookupFailureKind.network, '$error');
  }
}
