import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/external_probe.dart';
import 'package:server_box/data/model/app/service_reachability.dart';

class ServiceReachabilityCacheStore extends SqliteStore {
  ServiceReachabilityCacheStore([
    super.storeName = 'service_reachability_cache',
  ]) : super(
         updateLastUpdateTsOnSet: false,
         updateLastUpdateTsOnRemove: false,
         updateLastUpdateTsOnClear: false,
       );

  static final instance = ServiceReachabilityCacheStore();
  static const successTtl = Duration(hours: 24);
  static const failureTtl = Duration(hours: 1);

  String _key(String serverId, String target, ServiceKind service) =>
      '$serverId::$target::${service.name}';

  ServiceReachabilityResult? fresh(
    String serverId,
    String target,
    ServiceKind service, {
    DateTime? now,
  }) {
    final key = _key(serverId, target, service);
    final raw = get<Map>(key);
    if (raw == null) return null;
    try {
      final result = ServiceReachabilityResult.fromJson(raw);
      final ttl = result.reachable ? successTtl : failureTtl;
      if ((now ?? DateTime.now()).difference(result.checkedAt) >= ttl) {
        remove(key);
        return null;
      }
      return result;
    } catch (_) {
      remove(key);
      return null;
    }
  }

  bool put(String serverId, String target, ServiceReachabilityResult result) =>
      set(_key(serverId, target, result.service), result.toJson());

  String _externalKey(String serverId, String scope, ProbeTarget target) =>
      '$serverId::external::v${ProbeCatalog.version}::$scope::${target.fingerprint}';

  /// Expired observations remain available with their original timestamp.
  ProbeResult? external(String serverId, String scope, ProbeTarget target) {
    final raw = get<Map>(_externalKey(serverId, scope, target));
    if (raw == null) return null;
    try { return ProbeResult.fromJson(raw); } catch (_) { return null; }
  }

  bool putExternal(String serverId, String scope, ProbeTarget target, ProbeResult result) =>
      set(_externalKey(serverId, scope, target), result.toJson());

  void forgetServer(String serverId) {
    for (final key in keys().where((key) => key.startsWith('$serverId::'))) {
      remove(key);
    }
  }
}
