import 'dart:convert';

import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';

/// Read-only data sent from Flutter to the incremental SwiftUI dashboard.
///
/// Deliberately excludes credentials, tokens, commands and terminal state.
class NativeDashboardSnapshot {
  const NativeDashboardSnapshot({
    required this.revision,
    required this.servers,
  });

  final int revision;
  final List<NativeDashboardServerSnapshot> servers;

  /// Captures the current Flutter provider values. It does not retain or poll
  /// those providers; Flutter remains the single source of monitor state.
  factory NativeDashboardSnapshot.fromServerStates({
    required int revision,
    required Iterable<ServerState> states,
  }) => NativeDashboardSnapshot(
    revision: revision,
    servers: states
        .map(NativeDashboardServerSnapshot.fromServerState)
        .toList(growable: false),
  );

  Map<String, Object> toJson() => {
    'revision': revision,
    'servers': servers.map((server) => server.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());
}

class NativeDashboardServerSnapshot {
  const NativeDashboardServerSnapshot({
    required this.id,
    required this.name,
    required this.address,
    required this.online,
    this.cpuPercent,
    this.memoryPercent,
    this.diskPercent,
  });

  final String id;
  final String name;
  final String address;
  final bool online;
  final int? cpuPercent;
  final int? memoryPercent;
  final int? diskPercent;

  /// Projects existing monitor state without exposing connection credentials.
  factory NativeDashboardServerSnapshot.fromServerState(ServerState state) {
    final status = state.status;
    int percent(num value) => value.round().clamp(0, 100);
    return NativeDashboardServerSnapshot(
      id: state.spi.id,
      name: state.spi.name,
      address: state.spi.displayAddr,
      online: state.conn == ServerConn.finished,
      cpuPercent: status.cpu.usedPercent() == null
          ? null
          : percent(status.cpu.usedPercent()!),
      memoryPercent: percent(status.mem.usedPercent * 100),
      diskPercent: status.diskUsage == null
          ? null
          : percent(status.diskUsage!.usedPercent),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'state': online ? 'online' : 'offline',
    if (cpuPercent != null) 'cpuPercent': cpuPercent,
    if (memoryPercent != null) 'memoryPercent': memoryPercent,
    if (diskPercent != null) 'diskPercent': diskPercent,
  };
}
