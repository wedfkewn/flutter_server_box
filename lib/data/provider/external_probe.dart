import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/service/external_probe_controller.dart';
import 'package:server_box/core/service/self_addr.dart';
import 'package:server_box/data/model/app/external_probe.dart';
import 'package:server_box/data/model/app/service_reachability.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/external_probe_preferences.dart';

String externalProbeScope(ServerState server) => jsonEncode([
  server.spi.ssh?.ip, server.spi.ssh?.port, server.spi.ssh?.user,
  server.spi.monitorHttp?.addr, server.spi.transport.name,
  SelfAddr.pick(server.status.ips)?.address,
]);

final externalProbeProvider = Provider.autoDispose.family<ExternalProbeController, String>((ref, id) {
  var server = ref.read(serverProvider(id));
  var scope = externalProbeScope(server);
  final controller = ExternalProbeController(
    config: ExternalProbePreferences.load(Stores.setting, id),
    runner: (targets) => ref.read(serverProvider(id).notifier).probeExternalServices(targets),
    save: (config) => ExternalProbePreferences.save(Stores.setting, id, config),
    readResult: (target) {
      final current = Stores.serviceReachabilityCache.external(id, scope, target);
      if (current != null) return current;
      final legacyKind = ServiceKind.values.where((e) => e.name == target.id).firstOrNull;
      if (legacyKind == null) return null;
      final old = Stores.serviceReachabilityCache.fresh(id, server.spi.displayAddr, legacyKind);
      if (old == null) return null;
      return ProbeResult(id: target.id, state: switch (old.state) {
        ServiceReachabilityState.reachable => ProbeState.reachable,
        ServiceReachabilityState.unreachable => ProbeState.rejected,
        ServiceReachabilityState.unknown => ProbeState.unknown,
      }, reason: old.reachable ? 'httpResponse' : 'legacyResult', checkedAt: old.checkedAt,
        transport: 'Legacy');
    },
    writeResult: (target, result) {
      Stores.serviceReachabilityCache.putExternal(id, scope, target, result);
    });
  ref.listen(serverProvider(id), (previous, next) {
    server = next;
    final nextScope = externalProbeScope(next);
    if (nextScope != scope || (previous != null && next.spi.shouldReconnect(previous.spi))) {
      scope = nextScope;
      Stores.serviceReachabilityCache.forgetServer(id);
      controller.invalidate();
    }
    controller.maybeAutoCheck(server.conn == ServerConn.finished);
  });
  controller.maybeAutoCheck(server.conn == ServerConn.finished);
  final settingListeners = [Stores.setting.externalProbeConfig.listenable(),
    Stores.setting.probeChatGpt.listenable(), Stores.setting.probeNetflix.listenable(),
    Stores.setting.probeGemini.listenable()];
  void settingsChanged() {
    final next = ExternalProbePreferences.load(Stores.setting, id);
    if (jsonEncode(next.toJson()) == jsonEncode(controller.config.toJson())) return;
    controller.applyConfig(next);
    controller.maybeAutoCheck(server.conn == ServerConn.finished);
  }
  for (final listenable in settingListeners) { listenable.addListener(settingsChanged); }
  ref.onDispose(() {
    for (final listenable in settingListeners) { listenable.removeListener(settingsChanged); }
    controller.dispose();
  });
  return controller;
});
