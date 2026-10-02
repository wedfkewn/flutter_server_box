import 'dart:convert';

import 'package:server_box/data/model/app/external_probe.dart';
import 'package:server_box/data/store/setting.dart';

abstract final class ExternalProbePreferences {
  static Map<String, dynamic> _read(SettingStore store) {
    try {
      return Map<String, dynamic>.from(jsonDecode(store.externalProbeConfig.fetch()) as Map);
    } catch (_) { return {}; }
  }

  static ProbeConfig load(SettingStore store, String serverId) {
    final raw = _read(store)[serverId];
    if (raw is Map) {
      try { return ProbeConfig.fromJson(raw); } catch (_) { /* Use legacy defaults. */ }
    }
    final legacy = <String>{
      if (store.probeChatGpt.fetch()) 'chatGpt',
      if (store.probeNetflix.fetch()) 'netflix',
      if (store.probeGemini.fetch()) 'gemini',
    };
    final selected = legacy.isEmpty ? {'google', 'github', 'youtube', 'chatGpt'} : legacy;
    return ProbeConfig(selected: selected, pinned: selected.take(4).toList(),
      autoCheck: legacy.isNotEmpty);
  }

  static bool save(SettingStore store, String serverId, ProbeConfig config) {
    final all = _read(store)..[serverId] = config.toJson();
    return store.set('externalProbeConfig', jsonEncode(all));
  }

  static void forget(SettingStore store, String serverId) {
    final all = _read(store);
    if (all.remove(serverId) != null) store.set('externalProbeConfig', jsonEncode(all));
  }
}
