import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/app/ip_info.dart';
import 'package:server_box/data/res/store.dart';

part 'ip_info.g.dart';

final class _IpInfoCacheEntry {
  final IpInfo info;
  final DateTime at;

  const _IpInfoCacheEntry(this.info, this.at);
}

final class _IpInfoRepo {
  final Dio _dio = Dio();
  final Map<String, _IpInfoCacheEntry> _cache = {};
  DateTime? _lastRequestAt;
  Future<void> _tail = Future.value();

  static const _defaultToken = '6f434b09039258';
  static const _ttl = Duration(minutes: 5);
  static const _minInterval = Duration(seconds: 1);

  String get _token {
    final customToken = Stores.setting.ipinfoToken.fetch();
    return customToken.isEmpty ? _defaultToken : customToken;
  }

  Future<IpInfo> get(String ip, {required bool force}) {
    final key = ip.trim();
    if (key.isEmpty) {
      throw ArgumentError.value(ip, 'ip');
    }

    if (!force) {
      final cached = _cache[key];
      if (cached != null && DateTime.now().difference(cached.at) < _ttl) {
        return Future.value(cached.info);
      }
    }

    return _enqueue(() async {
      if (_lastRequestAt != null) {
        final diff = DateTime.now().difference(_lastRequestAt!);
        if (diff < _minInterval) {
          await Future.delayed(_minInterval - diff);
        }
      }
      _lastRequestAt = DateTime.now();
      final response = await _dio.get('https://ipinfo.io/$key?token=$_token');
      final info = IpInfo.fromJson(response.data);
      _cache[key] = _IpInfoCacheEntry(info, DateTime.now());
      return info;
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}

@Riverpod(keepAlive: true)
class IpInfoNotifier extends _$IpInfoNotifier {
  static final _repo = _IpInfoRepo();
  late final String _ip;

  @override
  Future<IpInfo?> build(String ip) async {
    _ip = ip.trim();
    if (_ip.isEmpty) return null;
    return _repo.get(_ip, force: false);
  }

  Future<void> refresh({bool force = true}) async {
    if (_ip.isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.get(_ip, force: force));
  }
}
