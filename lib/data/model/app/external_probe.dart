import 'dart:convert';

enum ProbeCategory { ai, media, social, developer, general, custom }
enum ProbeProtocol { http, tcp }
enum ProbeState { reachable, rejected, unknown }

/// An editable, versioned target. Credentials and arbitrary shell fragments
/// are deliberately not part of this format.
class ProbeTarget {
  const ProbeTarget({required this.id, required this.name,
    required this.address, required this.category,
    this.protocol = ProbeProtocol.http, this.method = 'GET',
    this.timeoutSeconds = 8, this.followRedirects = true,
    this.statusMin = 200, this.statusMax = 399, this.keyword = ''});

  final String id, name, address, method, keyword;
  final ProbeCategory category;
  final ProbeProtocol protocol;
  final int timeoutSeconds, statusMin, statusMax;
  final bool followRedirects;
  bool get isCustom => id.startsWith('custom_');
  String get fingerprint => jsonEncode(toJson());

  String? get validationError {
    if (!RegExp(r'^[a-zA-Z0-9_]{1,80}$').hasMatch(id)) return 'id';
    if (name.trim().isEmpty || name.length > 80) return 'name';
    final uri = Uri.tryParse(address);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        address.length > 2048 || RegExp(r'[\x00-\x20]').hasMatch(address)) { return 'address'; }
    if (protocol == ProbeProtocol.http) {
      if (!{'http', 'https'}.contains(uri.scheme) ||
          !{'GET', 'HEAD'}.contains(method)) { return 'address'; }
    } else if (uri.scheme != 'tcp' || !uri.hasPort || uri.port < 1 ||
        uri.port > 65535 || uri.path.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      return 'address';
    }
    if (timeoutSeconds < 2 || timeoutSeconds > 15) return 'timeout';
    if (statusMin < 100 || statusMax > 599 || statusMin > statusMax) return 'status';
    if (keyword.length > 200 || keyword.contains('\n') || keyword.contains('\r') ||
        keyword.contains('\u0000') || (method == 'HEAD' && keyword.isNotEmpty)) { return 'keyword'; }
    return null;
  }

  Map<String, Object> toJson() => {'id': id, 'name': name, 'address': address,
    'category': category.name, 'protocol': protocol.name, 'method': method,
    'timeoutSeconds': timeoutSeconds, 'followRedirects': followRedirects,
    'statusMin': statusMin, 'statusMax': statusMax, 'keyword': keyword};

  factory ProbeTarget.fromJson(Map raw) => ProbeTarget(
    id: raw['id'] as String, name: raw['name'] as String,
    address: raw['address'] as String,
    category: ProbeCategory.values.byName(raw['category'] as String),
    protocol: ProbeProtocol.values.byName(raw['protocol'] as String? ?? 'http'),
    method: raw['method'] as String? ?? 'GET',
    timeoutSeconds: raw['timeoutSeconds'] as int? ?? 8,
    followRedirects: raw['followRedirects'] as bool? ?? true,
    statusMin: raw['statusMin'] as int? ?? 200,
    statusMax: raw['statusMax'] as int? ?? 399,
    keyword: raw['keyword'] as String? ?? '');
}

abstract final class ProbeCatalog {
  static const version = 1;
  static const targets = <ProbeTarget>[
    ProbeTarget(id: 'chatGpt', name: 'ChatGPT', address: 'https://chatgpt.com/', category: ProbeCategory.ai),
    ProbeTarget(id: 'gemini', name: 'Gemini', address: 'https://gemini.google.com/', category: ProbeCategory.ai),
    ProbeTarget(id: 'claude', name: 'Claude', address: 'https://claude.ai/', category: ProbeCategory.ai),
    ProbeTarget(id: 'copilot', name: 'Copilot', address: 'https://copilot.microsoft.com/', category: ProbeCategory.ai),
    ProbeTarget(id: 'netflix', name: 'Netflix', address: 'https://www.netflix.com/', category: ProbeCategory.media),
    ProbeTarget(id: 'youtube', name: 'YouTube', address: 'https://www.youtube.com/', category: ProbeCategory.media),
    ProbeTarget(id: 'disney', name: 'Disney+', address: 'https://www.disneyplus.com/', category: ProbeCategory.media),
    ProbeTarget(id: 'spotify', name: 'Spotify', address: 'https://open.spotify.com/', category: ProbeCategory.media),
    ProbeTarget(id: 'telegram', name: 'Telegram Web', address: 'https://web.telegram.org/', category: ProbeCategory.social),
    ProbeTarget(id: 'discord', name: 'Discord', address: 'https://discord.com/', category: ProbeCategory.social),
    ProbeTarget(id: 'x', name: 'X', address: 'https://x.com/', category: ProbeCategory.social),
    ProbeTarget(id: 'instagram', name: 'Instagram', address: 'https://www.instagram.com/', category: ProbeCategory.social),
    ProbeTarget(id: 'reddit', name: 'Reddit', address: 'https://www.reddit.com/', category: ProbeCategory.social),
    ProbeTarget(id: 'github', name: 'GitHub', address: 'https://github.com/', category: ProbeCategory.developer),
    ProbeTarget(id: 'docker', name: 'Docker Hub', address: 'https://hub.docker.com/', category: ProbeCategory.developer),
    ProbeTarget(id: 'npm', name: 'npm Registry', address: 'https://registry.npmjs.org/', category: ProbeCategory.developer),
    ProbeTarget(id: 'pypi', name: 'PyPI', address: 'https://pypi.org/', category: ProbeCategory.developer),
    ProbeTarget(id: 'google', name: 'Google', address: 'https://www.google.com/', category: ProbeCategory.general),
    ProbeTarget(id: 'bing', name: 'Bing', address: 'https://www.bing.com/', category: ProbeCategory.general),
    ProbeTarget(id: 'wikipedia', name: 'Wikipedia', address: 'https://www.wikipedia.org/', category: ProbeCategory.general),
  ];
}

class ProbeResult {
  const ProbeResult({required this.id, required this.state,
    required this.reason, required this.checkedAt, this.httpStatus,
    this.elapsedMs, this.remoteIp, this.transport});
  final String id, reason;
  final ProbeState state;
  final DateTime checkedAt;
  final int? httpStatus, elapsedMs;
  /// The destination of the request, NOT the server's public egress address.
  final String? remoteIp, transport;
  Duration get ttl => {'rateLimited', 'serviceError', 'busy'}.contains(reason)
    ? const Duration(minutes: 1) : switch (state) {
    ProbeState.reachable => const Duration(minutes: 30),
    ProbeState.rejected => const Duration(minutes: 10),
    ProbeState.unknown => const Duration(minutes: 1),
  };
  bool isFresh(DateTime now) => !now.isBefore(checkedAt) && now.difference(checkedAt) < ttl;
  Map<String, Object?> toJson() => {'id': id, 'state': state.name,
    'reason': reason, 'checkedAt': checkedAt.toUtc().toIso8601String(),
    'httpStatus': httpStatus, 'elapsedMs': elapsedMs,
    'remoteIp': remoteIp, 'transport': transport};
  factory ProbeResult.fromJson(Map raw) => ProbeResult(id: raw['id'] as String,
    state: ProbeState.values.byName(raw['state'] as String),
    reason: raw['reason'] as String, checkedAt: DateTime.parse(raw['checkedAt'] as String),
    httpStatus: raw['httpStatus'] as int?, elapsedMs: raw['elapsedMs'] as int?,
    remoteIp: raw['remoteIp'] as String?, transport: raw['transport'] as String?);
}

class ProbeConfig {
  const ProbeConfig({required this.selected, required this.pinned,
    this.custom = const [], this.autoCheck = false});
  final Set<String> selected;
  final List<String> pinned;
  final List<ProbeTarget> custom;
  final bool autoCheck;
  List<ProbeTarget> get targets => [...ProbeCatalog.targets, ...custom];
  List<ProbeTarget> get enabled => targets.where((e) => selected.contains(e.id)).toList();
  List<ProbeTarget> get favorites => [for (final id in pinned.take(4))
    ...enabled.where((e) => e.id == id)];
  Map<String, Object> toJson() => {'selected': selected.toList(),
    'pinned': pinned.take(4).toList(), 'custom': custom.map((e) => e.toJson()).toList(),
    'autoCheck': autoCheck};
  factory ProbeConfig.fromJson(Map raw) {
    final custom = <ProbeTarget>[];
    for (final value in (raw['custom'] as List? ?? const [])) {
      try {
        final target = ProbeTarget.fromJson(value as Map);
        if (target.isCustom && target.validationError == null &&
            !custom.any((e) => e.id == target.id)) { custom.add(target); }
      } catch (_) { /* A bad user entry must not hide the built-in catalog. */ }
    }
    final known = {...ProbeCatalog.targets.map((e) => e.id), ...custom.map((e) => e.id)};
    final selected = (raw['selected'] as List? ?? const []).whereType<String>().where(known.contains).toSet();
    return ProbeConfig(selected: selected,
      pinned: (raw['pinned'] as List? ?? const []).whereType<String>().where(selected.contains).toSet().take(4).toList(),
      custom: custom, autoCheck: raw['autoCheck'] == true);
  }
}
