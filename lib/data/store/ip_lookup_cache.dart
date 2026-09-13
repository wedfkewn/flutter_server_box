import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/ip_lookup.dart';

class IpLookupCacheStore extends SqliteStore {
  IpLookupCacheStore([super.storeName = 'ip_lookup_cache'])
    : super(
        updateLastUpdateTsOnSet: false,
        updateLastUpdateTsOnRemove: false,
        updateLastUpdateTsOnClear: false,
      );

  static final instance = IpLookupCacheStore();
  static const staleAfter = Duration(days: 7);

  String _key(String serverId, String ip) => '$serverId::$ip';

  IpLookupResult? fresh(String serverId, String ip, {DateTime? now}) {
    final raw = get<Map>(_key(serverId, ip));
    if (raw == null) return null;
    try {
      final result = IpLookupResult.fromJson(raw);
      final fetchedAt = result.fetchedAt;
      if (fetchedAt == null ||
          (now ?? DateTime.now()).difference(fetchedAt) >= staleAfter) {
        remove(_key(serverId, ip));
        return null;
      }
      return result;
    } catch (_) {
      remove(_key(serverId, ip));
      return null;
    }
  }

  bool putResult(String serverId, IpLookupResult result) =>
      set(_key(serverId, result.ip), result.toJson());

  void forgetServer(String serverId) {
    for (final key in keys().where((key) => key.startsWith('$serverId::'))) {
      remove(key);
    }
  }

  /// Drops derived entries for addresses the server no longer reports.
  void forgetServerExcept(String serverId, String ip) {
    final keep = _key(serverId, ip);
    for (final key in keys().where(
      (key) => key.startsWith('$serverId::') && key != keep,
    )) {
      remove(key);
    }
  }
}
