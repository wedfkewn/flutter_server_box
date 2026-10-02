import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:server_box/data/model/app/external_probe.dart';

typedef ProbeRunner = Future<Map<String, ProbeResult>> Function(List<ProbeTarget> targets);

/// One bounded queue shared by the homepage and the detection center.
class ExternalProbeController extends ChangeNotifier {
  ExternalProbeController({required this.config, required this.runner,
    required this.save, required this.readResult, required this.writeResult,
    DateTime Function()? clock}) : clock = clock ?? DateTime.now {
    restore();
  }
  ProbeConfig config;
  final ProbeRunner runner;
  final bool Function(ProbeConfig) save;
  final ProbeResult? Function(ProbeTarget) readResult;
  final void Function(ProbeTarget, ProbeResult) writeResult;
  final DateTime Function() clock;
  final results = <String, ProbeResult>{};
  final checking = <String>{};
  final _attempts = <String, DateTime>{};
  bool running = false, cancelled = false, _disposed = false;
  int completed = 0, total = 0, _generation = 0;
  String? error;
  Future<void>? _automatic;
  bool _connected = false;
  bool _autoSuppressed = false;

  void restore() {
    for (final target in config.enabled) {
      final result = readResult(target);
      if (result != null) results[target.id] = result;
    }
  }

  bool updateConfig(ProbeConfig next) {
    if (!save(next)) return false;
    applyConfig(next);
    return true;
  }

  void applyConfig(ProbeConfig next) {
    final oldTargets = {for (final target in config.enabled) target.id: target.fingerprint};
    final nextTargets = {for (final target in next.enabled) target.id: target.fingerprint};
    cancel(suppressAuto: false);
    config = next;
    _autoSuppressed = false;
    // Pin changes retain readings and cooldowns. Changed targets do not.
    results.removeWhere((id, _) => !nextTargets.containsKey(id) || oldTargets[id] != nextTargets[id]);
    _attempts.removeWhere((id, _) => oldTargets[id] != nextTargets[id]);
    restore();
    _notify();
  }

  void invalidate() {
    cancel(suppressAuto: false);
    results.clear();
    _attempts.clear();
    restore();
    _notify();
  }

  int retryAfter(Iterable<String> ids) {
    var seconds = 0;
    for (final id in ids) {
      final at = _attempts[id];
      if (at != null) {
        final remaining = 60 - clock().difference(at).inSeconds;
        if (remaining > seconds) seconds = remaining;
      }
    }
    return seconds;
  }

  /// Automatic checks never connect a server explicitly disconnected by its user.
  void maybeAutoCheck(bool connected) {
    _connected = connected;
    if (!connected || !config.autoCheck || _autoSuppressed || running || _automatic != null) return;
    _automatic = Future<void>.delayed(Duration.zero, () async {
      if (!_disposed && _connected && config.autoCheck && !_autoSuppressed) await run(force: false);
    }).whenComplete(() { _automatic = null; });
  }

  Future<void> run({Set<String>? ids, bool force = true}) async {
    if (_disposed || running) return;
    if (force) _autoSuppressed = false;
    final targets = config.enabled.where((e) => ids == null || ids.contains(e.id))
      .where((e) => force || results[e.id]?.isFresh(clock()) != true).toList();
    if (targets.isEmpty) return;
    final cooldown = retryAfter(targets.map((e) => e.id));
    if (cooldown > 0) {
      if (force) { error = 'cooldown:$cooldown'; _notify(); }
      return;
    }
    final generation = ++_generation;
    running = true; cancelled = false; error = null;
    total = targets.length; completed = 0;
    _notify();
    try {
      for (var start = 0; start < targets.length; start += 3) {
        if (_disposed || generation != _generation) break;
        final batch = targets.skip(start).take(3).toList();
        final at = clock();
        for (final target in batch) { checking.add(target.id); _attempts[target.id] = at; }
        _notify();
        Map<String, ProbeResult> batchResults;
        try {
          batchResults = await runner(batch);
        } catch (_) {
          batchResults = {for (final target in batch) target.id:
            ProbeResult(id: target.id, state: ProbeState.unknown,
              reason: 'transportError', checkedAt: clock())};
        }
        if (_disposed || generation != _generation) break;
        for (final target in batch) {
          final result = batchResults[target.id] ?? ProbeResult(id: target.id,
            state: ProbeState.unknown, reason: 'invalidResponse', checkedAt: clock());
          writeResult(target, result);
          results[target.id] = result;
          checking.remove(target.id);
          completed++;
        }
        _notify();
      }
    } finally {
      // Cancel stops new batches; the bounded in-flight batch must finish
      // before another queue may start, even after the scope was changed.
      running = false; checking.clear(); _notify();
      if (!_disposed && generation != _generation && config.autoCheck && !_autoSuppressed) {
        Future<void>.delayed(Duration.zero, () { if (!_disposed) maybeAutoCheck(_connected); });
      }
    }
  }

  void cancel({bool suppressAuto = true}) {
    if (suppressAuto) _autoSuppressed = true;
    if (running) { _generation++; cancelled = true; checking.clear(); _notify(); }
  }

  void _notify() { if (!_disposed) notifyListeners(); }
  @override
  void dispose() { _disposed = true; _generation++; super.dispose(); }
}
