import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/geo_data.dart';
import 'package:server_box/core/service/ip_geo.dart';
import 'package:server_box/core/service/self_addr.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/data/model/server/geo_source.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/floating_dialog.dart';
import 'package:server_box/view/widget/geo_data_install.dart';
import 'package:server_box/view/widget/globe/view.dart';

enum ServerGlobeMode { legacy, preview, explorer }

/// Shared only while the homepage card or its full-screen route is mounted.
class ServerGlobeSession extends ChangeNotifier {
  final located = <String, ResolvedGeo>{};
  final misses = <String, GeoMiss>{};
  final inputs = <String, ({String? host, GeoCoord? manual})>{};
  Future<void>? pending;
  int _users = 0;
  int? revision;
  void attach() => _users++;
  void detach() {
    if (--_users == 0) dispose();
  }

  void changed() {
    if (_users > 0) notifyListeners();
  }
}

/// The server list, as a globe.
///
/// This is the part that knows about servers: it asks [IpGeo] where each one
/// is, decides what a card says, and hands the rest to [GlobeView], which
/// knows only about points and rectangles.
///
/// Resolution happens here rather than in a provider because it is only wanted
/// while this is on screen. A provider would resolve every server — a name
/// lookup each — the first time anything read it, whether or not the globe had
/// ever been opened.
class ServerGlobe extends ConsumerStatefulWidget {
  const ServerGlobe({
    super.key,
    required this.ids,
    required this.onTapServer,
    required this.onEditServer,
    this.action,
    this.mode = ServerGlobeMode.legacy,
    this.session,
    this.controller,
    this.onSelection,
  });

  /// In the order the list is showing them, which decides which one the globe
  /// opens facing.
  final List<String> ids;
  final ServerGlobeMode mode;
  final ServerGlobeSession? session;
  final GlobeViewController? controller;
  final ValueChanged<List<String>>? onSelection;

  final void Function(Spi spi) onTapServer;

  /// For a server nothing could place: the editor is where a coordinate is
  /// given by hand, and that is the only thing to do about it.
  final void Function(Spi spi) onEditServer;

  /// Passed straight to [GlobeView.action] — a control in the top right corner,
  /// for when the globe is the whole page and nothing else on screen leaves it.
  final Widget? action;

  @override
  ConsumerState<ServerGlobe> createState() => _ServerGlobeState();
}

/// Fixed, because the layout has to know it before the cards are built.
///
/// Wide enough for a name that is not a hostname and two readings under it,
/// and no wider: every extra pixel is one the de-overlap has to push the next
/// card by.
const _kCardSize = Size(136, 46);

class _ServerGlobeState extends ConsumerState<ServerGlobe> {
  final _localLocated = <String, ResolvedGeo>{};
  Map<String, ResolvedGeo> get _located =>
      widget.session?.located ?? _localLocated;

  /// Servers nothing could place and why, remembered so the chain is not
  /// walked again on every rebuild — for a name that does not resolve that is
  /// a DNS query per frame.
  ///
  /// The reason is kept rather than a bare set because it is what the strip
  /// along the bottom says. "Unknown" over a tab of LAN servers is true and
  /// useless: it is the ordinary state of an install with nothing on the
  /// public internet, and nothing on screen said so.
  final _localUnplaceable = <String, GeoMiss>{};
  Map<String, GeoMiss> get _unplaceable =>
      widget.session?.misses ?? _localUnplaceable;

  /// What each id was resolved *from*, so an edited address is looked up
  /// again.
  ///
  /// [_located] is keyed by id because that is what the caller hands over, but
  /// an id is not what decides where a server is. Editing either the address or
  /// the manual coordinate leaves `widget.ids` unchanged, so both inputs have
  /// to travel with the answer or the old dot stays where it was for as long as
  /// this widget lives.
  final _localResolvedFrom = <String, ({String? host, GeoCoord? manual})>{};
  Map<String, ({String? host, GeoCoord? manual})> get _resolvedFrom =>
      widget.session?.inputs ?? _localResolvedFrom;
  List<String> _selection = const [];
  final _connections = <String, ServerConn>{};

  // A removed provider can be invalidated before this widget drops its old
  // subscriptions. Consume that disposal event without reading a deleted ID.
  ServerConn _connection(String id) {
    final provider = serverProvider(id).select((s) => s.conn);
    ref.listen(
      provider,
      (_, next) {
        if (mounted) setState(() => _connections[id] = next);
      },
      onError: (error, stack) {
        if (ref.read(serversProvider).servers.containsKey(id)) {
          FlutterError.reportError(
            FlutterErrorDetails(exception: error, stack: stack),
          );
        }
      },
    );
    return _connections[id] = ref.read(provider);
  }

  /// One at a time, not `Future.wait`. Fifty servers behind fifty names is
  /// fifty simultaneous DNS queries, which is a burst a router notices — and
  /// `_resolvedFrom` means a pass that changes nothing asks nothing, so the
  /// serial loop costs nothing in the case that actually repeats.
  bool _resolving = false;

  /// Set when something asks to resolve while a pass is already running.
  ///
  /// The guard used to just drop the request. A pass takes as long as its
  /// slowest DNS timeout, and anything arriving in that window — a server
  /// added, a tag picked — was discarded with nothing to re-trigger it, so
  /// those servers rendered as neither a dot nor a chip until an unrelated
  /// change happened to land while the loop was idle.
  bool _resolveAgain = false;

  @override
  void initState() {
    super.initState();
    widget.session?.attach();
    widget.session?.addListener(_onSession);
    // Installed or removed from anywhere — the strip's own button, the settings
    // page in another tab — and every answer this holds was reached against the
    // data that changed. `_resolvedFrom` is cleared with it so the pass is not
    // a no-op for every server it already settled.
    GeoData.revision.addListener(_onGeoData);
    unawaited(_resolve());
  }

  @override
  void dispose() {
    widget.session?.removeListener(_onSession);
    widget.session?.detach();
    GeoData.revision.removeListener(_onGeoData);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  void _onGeoData() {
    if (!mounted) return;
    final session = widget.session;
    if (session != null && session.revision == GeoData.revision.value) return;
    if (session != null) session.revision = GeoData.revision.value;
    _resolvedFrom.clear();
    _located.clear();
    _unplaceable.clear();
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(ServerGlobe old) {
    super.didUpdateWidget(old);
    // Server edits are covered by the provider listener in [build]. A parent
    // rebuild with the same ids therefore has no new resolution input.
    if (!listEquals(old.ids, widget.ids)) unawaited(_resolve());
  }

  /// What [_reportPlacements] last said, so an unchanged answer is not repeated.
  String? _reported;

  Future<void> _resolve() async {
    if (_resolving) {
      _resolveAgain = true;
      return;
    }
    _resolving = true;
    final session = widget.session;
    if (session?.pending case final pending?) {
      await pending;
      if (!mounted) {
        _resolving = false;
        return;
      }
    }
    final completed = Completer<void>();
    if (session != null) session.pending = completed.future;
    try {
      do {
        _resolveAgain = false;
        await _resolvePass();
      } while (_resolveAgain && mounted);
    } finally {
      _resolving = false;
      if (session != null && identical(session.pending, completed.future)) {
        session.pending = null;
      }
      completed.complete();
    }
    if (mounted) _reportPlacements();
  }

  /// How the servers on screen were placed, as counts.
  ///
  /// A summary rather than a crumb per server: a pass runs every time the globe
  /// is opened and every time the list it is given changes, so per-server would
  /// be tens of events for one look at a sphere. What is worth knowing is a
  /// proportion — how many the city data placed, how many were placed only
  /// because the machine reported its own address, how many nothing could place
  /// at all — and that is a property of the pass rather than of any server.
  ///
  /// Counts only, and deliberately: where a server is is location data about
  /// the user's machines, and a crumb is written to be published — see
  /// [Breadcrumb]. Even the country a server is in is not sent.
  ///
  /// Sent once per answer. Late arrivals change it — a machine that reports its
  /// own address several minutes in moves from [GeoMiss.private] to
  /// [GeoSource.selfReported] — and those are the passes worth hearing about,
  /// while the ones that reach the same answer again are not.
  void _reportPlacements() {
    if (!Diag.enabled) return;
    // Keyed by the enums' own names, so a source or a miss added later is
    // counted without a second list here to fall behind it. The two share no
    // name, which is what lets them share one map.
    final counts = <String, int>{
      for (final source in GeoSource.values) source.name: 0,
      for (final miss in GeoMiss.values) miss.name: 0,
    };
    for (final id in widget.ids) {
      final source = _located[id]?.source;
      if (source != null) {
        counts[source.name] = counts[source.name]! + 1;
        continue;
      }
      // Neither placed nor missed: a server deleted while the pass ran, or the
      // globe switched off under it. Counted by `servers` and by nothing else.
      final miss = _unplaceable[id];
      if (miss != null) counts[miss.name] = counts[miss.name]! + 1;
    }
    final data = {
      // How many are on the globe at once, which is the number
      // `GlobeView.labelLimit` is a guess about.
      'servers': '${widget.ids.length}',
      for (final entry in counts.entries) entry.key: '${entry.value}',
    };
    final summary = data.toString();
    if (summary == _reported) return;
    _reported = summary;
    Diag.crumb(SbDiag.globe, 'placed', data: data);
  }

  /// One pass, one rebuild.
  ///
  /// The `setState` used to be inside the loop, so fifty servers meant fifty
  /// rebuilds of the globe — each one re-running `layoutGlobeCards`, which
  /// tries up to ninety-six positions per card against every card already
  /// placed, and re-registering the per-id `ref.listen` calls in `build`. All
  /// of it on the frames the entrance animation is running on, which is the
  /// first thing anybody sees of this screen.
  ///
  /// Applied at the end rather than per server because nothing reads a partial
  /// pass: a server resolved halfway through is not drawn until the frame
  /// after, and that frame is this one.
  Future<void> _resolvePass() async {
    final located = <String, ResolvedGeo>{};
    final unplaceable = <String, GeoMiss>{};
    final resolvedFrom = <String, ({String? host, GeoCoord? manual})>{};
    final cleared = <String>{};
    final dataRevision = GeoData.revision.value;

    for (final id in widget.ids) {
      if (!mounted) return;
      final servers = ref.read(serversProvider).servers;
      final spi = servers[id];
      if (spi == null) continue;

      // What the answer on hand was derived from. The manual coordinate is the
      // first link in the resolution chain, so changing or removing it is as
      // significant as editing the address below it.
      final from = (host: IpGeo.geoHostOf(spi), manual: spi.custom?.geo);
      final known = _resolvedFrom[id] == from;
      // A settled answer is not asked about again — except a private miss on a
      // server that can now be asked where it is, or a self-reported answer
      // whose seven-day lease can now be refreshed from a later status poll.
      final canReadWhereItIs = _canReadWhereItIs(id);
      final placed = _located[id];
      final refreshSelfReported =
          placed?.source == GeoSource.selfReported && canReadWhereItIs;
      final settled =
          (placed != null && !refreshSelfReported) ||
          (_unplaceable.containsKey(id) && !canReadWhereItIs);
      if (known && settled) continue;

      // `IpGeo.locate` reads the stored self address before returning. Replace
      // an expired one first, otherwise this pass would faithfully resolve the
      // same stale address and mark it settled for another seven days.
      if (refreshSelfReported) _readWhereItIs(id);
      var found = await IpGeo.locate(spi);
      // A LAN address places nothing, and this is the first point at which
      // that is known. What the machine said about its own interfaces is
      // already in hand by then — the status poll collected it.
      if (found.miss == GeoMiss.private && _readWhereItIs(id)) {
        found = await IpGeo.locate(spi);
      }
      if (!mounted) return;
      resolvedFrom[id] = from;
      final geo = found.geo;
      if (geo != null) {
        located[id] = geo;
      } else {
        // Null only when the globe is off, in which case this widget is not
        // on screen — but it is a state the type allows, and treating it as
        // a reason would put a caption on the strip claiming one.
        final miss = found.miss;
        if (miss == null) {
          cleared.add(id);
        } else {
          unplaceable[id] = miss;
        }
      }
    }

    if (!mounted) return;
    if (dataRevision != GeoData.revision.value) {
      _resolveAgain = true;
      return;
    }
    final current = ref.read(serversProvider).servers;
    for (final id in resolvedFrom.keys.toList()) {
      final spi = current[id];
      if (spi == null ||
          (host: IpGeo.geoHostOf(spi), manual: spi.custom?.geo) !=
              resolvedFrom[id]) {
        resolvedFrom.remove(id);
        located.remove(id);
        unplaceable.remove(id);
        cleared.remove(id);
        _resolveAgain = true;
      }
    }
    _located.removeWhere((id, _) => !current.containsKey(id));
    _unplaceable.removeWhere((id, _) => !current.containsKey(id));
    _resolvedFrom.removeWhere((id, _) => !current.containsKey(id));
    if (resolvedFrom.isEmpty) return;
    setState(() {
      _resolvedFrom.addAll(resolvedFrom);
      for (final id in located.keys) {
        _unplaceable.remove(id);
      }
      for (final id in unplaceable.keys) {
        _located.remove(id);
      }
      // Neither placed nor missed: the globe was switched off under the pass.
      for (final id in cleared) {
        _located.remove(id);
        _unplaceable.remove(id);
      }
      _located.addAll(located);
      _unplaceable.addAll(unplaceable);
    });
    widget.session?.changed();
  }

  /// Whether [id] has an address on hand that nothing has read yet.
  ///
  /// The status poll is what collects it, so a server that has not reported
  /// yet is not refused permanently — it is left for a later pass, which is
  /// what the listener in [build] exists to cause.
  bool _canReadWhereItIs(String id) {
    if (!Stores.selfAddr.isStale(id)) return false;
    return ref.read(serverProvider(id)).status.ips.isNotEmpty;
  }

  /// Records what the machine reported about its own addresses.
  ///
  /// Nothing is run on the server here: `ip` is a key in the status manifest,
  /// so this is reading a field the poll already filled — over SSH or from a
  /// monitor agent's `/metrics`, identically. That is the whole reason it is a
  /// manifest command; see [SelfAddr].
  ///
  /// Returns whether anything worth another lookup came back. A machine with
  /// only private addresses records null — it will not grow a public one, and
  /// [SelfAddrStore] remembering that is what stops this being reconsidered on
  /// every pass.
  bool _readWhereItIs(String id) {
    if (!_canReadWhereItIs(id)) return false;
    final addr = SelfAddr.pick(ref.read(serverProvider(id)).status.ips);
    Stores.selfAddr.put(id, addr);
    return addr != null;
  }

  @override
  Widget build(BuildContext context) {
    // An editor updates this provider directly. `didUpdateWidget` covers the
    // parent changing the visible ids, but a Consumer rebuilding from its own
    // dependency is not given that callback, so the changed resolution inputs
    // need their own listener.
    ref.listen(serversProvider.select((s) => s.servers), (_, _) {
      unawaited(_resolve());
    });
    final servers = ref.watch(serversProvider.select((s) => s.servers));
    if (widget.mode != ServerGlobeMode.legacy) {
      return _buildDistribution(servers);
    }

    final items = <GlobeItem>[];
    final unplaced = <Widget>[];
    final misses = <GeoMiss>{};
    for (final id in widget.ids) {
      final spi = servers[id];
      if (spi == null) continue;
      final geo = _located[id];
      if (geo == null) {
        // Only once it is known there is no answer. While the lookup is still
        // running the server is neither on the globe nor in the strip, because
        // putting it in the strip and then taking it out again reads as a
        // glitch rather than as a result.
        final miss = _unplaceable[id];
        if (miss != null) {
          if (miss == GeoMiss.private) {
            // The globe is usually opened before the servers on it have
            // finished connecting, and a machine cannot be asked where it is
            // until one of them has. Nothing else here looks again — a settled
            // miss is never re-resolved — so this is what causes the pass that
            // does the asking.
            // Watching the addresses rather than the connection: what this
            // waits for is the *extended* poll that carries them, which lands
            // some time after the server is up.
            _listenForSelfAddr(id);
          }
          misses.add(miss);
          unplaced.add(_buildUnplaced(spi, miss));
        }
        continue;
      }
      if (geo.source == GeoSource.selfReported) _listenForSelfAddr(id);
      items.add(
        GlobeItem(
          id: id,
          coord: geo.coord,
          // Watched narrowly: the dot's colour changes when a server connects
          // or drops, not when a reading lands. The card below watches the
          // whole state, in its own `Consumer`.
          color: _colorOf(ref.watch(serverProvider(id).select((s) => s.conn))),
          card: _buildCard(id, spi),
        ),
      );
    }

    return GlobeView(
      items: items,
      cardSize: _kCardSize,
      action: widget.action,
      unplaced: unplaced,
      unplacedLabel: misses.isEmpty ? null : _unplacedLabel(misses),
      // The download, offered where somebody has just found out they need it.
      //
      // This is the entry point that reaches anyone. `globeEnabled` is on by
      // default, so the switch in settings is a decision most installs never
      // make — and until the data is here nothing is placed but hand-typed
      // coordinates, so for those installs the strip *is* the globe. Asking
      // here means the 25 MB is proposed next to the servers it would place.
      unplacedAction:
          unplaced.isEmpty ||
              !misses.contains(GeoMiss.noData) ||
              GeoData.installed() != null
          ? null
          : Btn.text(
              text: libL10n.download,
              onTap: () => unawaited(GeoDataInstall.run(context)),
            ),
      // The first server in the list, so the globe opens facing the thing at
      // the top of the page it replaced.
      initialCoord: items.firstOrNull?.coord,
      onTapItem: (id) {
        final spi = servers[id];
        if (spi != null) _openServer(spi, from: 'dot');
      },
    );
  }

  /// Re-runs location resolution when an extended poll has something that can
  /// fill a private miss or replace an expired self-reported address.
  void _listenForSelfAddr(String id) {
    ref.listen(
      serverProvider(id).select((s) => s.status.ips),
      (_, ips) {
        if (ips.isNotEmpty && Stores.selfAddr.isStale(id)) {
          unawaited(_resolve());
        }
      },
      onError: (error, stack) {
        if (ref.read(serversProvider).servers.containsKey(id)) {
          FlutterError.reportError(
            FlutterErrorDetails(exception: error, stack: stack),
          );
        }
      },
    );
  }

  /// Opens a server, saying which of the two things that reach it was pressed.
  ///
  /// The dot is painted and hit-tested by hand while the card is an `InkWell`,
  /// so they are two paths to one place — and whether the dots are ever pressed
  /// decides whether the hit test earns the tolerance it carries. Past
  /// [GlobeView.labelLimit] the dot is the only path there is.
  void _openServer(Spi spi, {required String from}) {
    Diag.crumb(SbDiag.globe, 'open server', data: {'from': from});
    widget.onTapServer(spi);
  }

  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  String _connectionLabel(ServerConn conn) => switch (conn) {
    ServerConn.finished => _text('已连接', 'Connected'),
    ServerConn.failed => _text('连接失败', 'Connection failed'),
    ServerConn.connecting ||
    ServerConn.loading ||
    ServerConn.connected => _text('连接中', 'Connecting'),
    ServerConn.disconnected => _text('未连接', 'Disconnected'),
  };

  void _select(List<String> ids, {bool focus = false}) {
    setState(() => _selection = ids);
    widget.onSelection?.call(ids);
    if (focus && ids.isNotEmpty) {
      final geo = _located[ids.first];
      if (geo != null) widget.controller?.focus(geo.coord);
    }
  }

  Widget _buildDistribution(Map<String, Spi> servers) {
    final ids = widget.ids.where(servers.containsKey).toList();
    final preview = widget.mode == ServerGlobeMode.preview;
    final items = <GlobeItem>[];
    for (final id in ids) {
      final geo = _located[id];
      if (geo == null || geo.source == GeoSource.selfReported) {
        _listenForSelfAddr(id);
      }
      final conn = _connection(id);
      if (geo != null) {
        items.add(
          GlobeItem(
            id: id,
            coord: geo.coord,
            color: _colorOf(conn),
            card: const SizedBox.shrink(),
          ),
        );
      }
    }
    final globe = RepaintBoundary(
      child: GlobeView(
        key: const ValueKey('distribution-globe'),
        items: items,
        cardSize: Size.zero,
        initialCoord: items.firstOrNull?.coord,
        interactive: !preview,
        autoRotate: false,
        showLabels: false,
        clusterMarkers: true,
        animateEntrance: !preview,
        radiusFactor: .82,
        controller: widget.controller,
        onTapGroup: (ids) => _select(ids),
      ),
    );
    if (preview) return IgnorePointer(child: globe);
    final selected = _selection.where(ids.contains).toList();
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _text(
                      '${items.length} 已定位 · ${ids.length - items.length} 未定位',
                      '${items.length} located · ${ids.length - items.length} unplaced',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('globe-server-picker'),
                  onPressed: () => _chooseServer(servers, ids),
                  icon: const Icon(Icons.list, size: 18),
                  label: Text(_text('选择服务器', 'Servers')),
                ),
              ],
            ),
          ),
          Expanded(child: globe),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .45),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (selected.isEmpty)
                        Text(
                          _text(
                            '拖动旋转 · 双指缩放 · 点击标记查看服务器',
                            'Drag to rotate · Pinch to zoom · Tap a marker',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (selected.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              for (final conn in [
                                ServerConn.finished,
                                ServerConn.connecting,
                                ServerConn.failed,
                                ServerConn.disconnected,
                              ])
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 7,
                                      color: _colorOf(conn),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _connectionLabel(conn),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      if (selected.length > 1) ...[
                        Text(
                          _text(
                            '此位置有 ${selected.length} 台服务器',
                            '${selected.length} servers at this location',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        for (final id in selected)
                          ListTile(
                            dense: true,
                            title: Text(servers[id]!.name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _select([id], focus: true),
                          ),
                      ],
                      if (selected.length == 1)
                        _summary(servers[selected.single]!),
                      if (GeoData.installed() == null &&
                          ids.any((id) => _unplaceable[id] == GeoMiss.noData))
                        TextButton.icon(
                          onPressed: () => GeoDataInstall.run(context),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: Text(
                            _text('下载定位数据', 'Download location data'),
                          ),
                        ),
                      if (ids.any((id) => _unplaceable.containsKey(id)))
                        TextButton(
                          onPressed: () => _chooseServer(
                            servers,
                            ids.where(_unplaceable.containsKey).toList(),
                          ),
                          child: Text(
                            _text('查看未定位服务器', 'View unplaced servers'),
                          ),
                        ),
                      if (ids.isEmpty)
                        Text(
                          _text(
                            '当前筛选下没有服务器',
                            'No servers match the current filters',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(Spi spi) {
    final geo = _located[spi.id];
    final conn = _connections[spi.id] ?? ServerConn.disconnected;
    final source = switch (geo?.source) {
      GeoSource.manual => _text('手动坐标', 'Manual coordinates'),
      GeoSource.selfReported => _text(
        '服务器公网地址推算 · 近似位置',
        'Reported public IP · Approximate location',
      ),
      GeoSource.city => _text(
        'IP 定位 · 近似位置',
        'IP lookup · Approximate location',
      ),
      null => _text('未定位', 'Unplaced'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.dns_outlined, color: _colorOf(conn), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                spi.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: _text('关闭摘要', 'Close summary'),
              onPressed: () => _select([]),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
        Text(_connectionLabel(conn)),
        Text(source, style: Theme.of(context).textTheme.bodySmall),
        Text(
          geo?.coord.text ??
              (_unplaceable[spi.id] == GeoMiss.private
                  ? _text(
                      '内网地址，可手动设置坐标',
                      'Private address; set coordinates manually',
                    )
                  : _text('暂无可用位置数据', 'No location data available')),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        AppButton(
          onPressed: () => widget.onTapServer(spi),
          child: Flexible(
            child: Text(
              _text('查看详情', 'View details'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        TextButton(
          onPressed: () => widget.onEditServer(spi),
          child: Text(_text('编辑位置', 'Edit location')),
        ),
      ],
    );
  }

  Future<void> _chooseServer(Map<String, Spi> servers, List<String> ids) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AppFloatingDialog(
        title: Text(_text('选择服务器', 'Choose a server')),
        content: SizedBox(
          width: 440,
          height: MediaQuery.sizeOf(context).height * .5,
          child: ListView(
            children: [
              for (final id in ids)
                ListTile(
                  title: Text(servers[id]!.name),
                  subtitle: Text(
                    _located.containsKey(id)
                        ? _located[id]!.coord.text
                        : _text('未定位', 'Unplaced'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, id),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null || !widget.ids.contains(selected)) return;
    _select([selected], focus: true);
  }

  Color _colorOf(ServerConn conn) {
    final scheme = Theme.of(context).colorScheme;
    return switch (conn) {
      ServerConn.finished => Colors.green,
      ServerConn.failed => scheme.error,
      ServerConn.connecting ||
      ServerConn.loading ||
      ServerConn.connected => Colors.orange,
      ServerConn.disconnected => scheme.outline,
    };
  }

  /// The compact card: a name, and what it is doing.
  ///
  /// Not `_buildEachServerCard`. That one is charts and needs the width of a
  /// grid column; here there are up to fourteen of them arranged around a
  /// sphere, and the question a card has to answer is which server it is and
  /// whether it is all right.
  Widget _buildCard(String id, Spi spi) {
    return Consumer(
      builder: (context, ref, _) {
        final srv = ref.watch(serverProvider(id));
        final scheme = Theme.of(context).colorScheme;
        final status = srv.conn == ServerConn.finished
            ? '${(srv.status.cpu.usedPercent() ?? 0).toStringAsFixed(0)}% · '
                  '${(srv.status.mem.usedPercent * 100).toStringAsFixed(0)}%'
            : srv.conn.name;

        return Material(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
          elevation: 3,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openServer(spi, from: 'card'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Row(
                spacing: 7,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _colorOf(srv.conn),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spi.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.3,
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// A server with nowhere to be drawn, as a chip that opens its editor.
  ///
  /// The editor is where a coordinate is typed, and for [GeoMiss.private] it
  /// is not a fallback but the only answer there will ever be — a LAN address
  /// is not in any database and will not become so.
  Widget _buildUnplaced(Spi spi, GeoMiss miss) {
    return ActionChip(
      avatar: Icon(switch (miss) {
        GeoMiss.private => Icons.lan_outlined,
        GeoMiss.noData => Icons.add_location_alt_outlined,
      }, size: 15),
      label: Text(spi.name, style: const TextStyle(fontSize: 12)),
      tooltip: _labelOf(miss),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        // The strip's whole purpose is this press: it is a server the globe
        // cannot draw, offering the one thing that would fix it. The reason is
        // carried because it decides whether the offer makes sense — a manual
        // coordinate is the only answer a private address will ever have, while
        // `noData` may be a name that would resolve on another network.
        Diag.crumb(SbDiag.globe, 'edit unplaced', data: {'miss': miss.name});
        widget.onEditServer(spi);
      },
    );
  }

  String _labelOf(GeoMiss miss) => switch (miss) {
    GeoMiss.private => l10n.geoMissPrivate,
    GeoMiss.noData => l10n.geoMissNoData,
  };

  /// The caption over the strip: why the servers down there are down there.
  ///
  /// **The city data not being installed comes first, and says so in those
  /// words.** Without it every public server misses as [GeoMiss.noData], which
  /// reads as "no location data" — true of the app, and heard as a fact about
  /// the server. Next to the Download button beside it, the caption has to name
  /// the thing that button downloads, or the pair says nothing: with a LAN
  /// server in the strip as well the reasons differed, the caption fell back to
  /// "Unknown", and what was on screen was `Unknown  Download`.
  ///
  /// Otherwise every reason present, in the enum's order. It used to be the one
  /// reason when there was exactly one and nothing at all when there were two —
  /// but a caption naming both is wrong about neither, and each chip carries the
  /// icon that says which of them it is.
  String _unplacedLabel(Set<GeoMiss> misses) {
    if (misses.contains(GeoMiss.noData) && GeoData.installed() == null) {
      return '${l10n.geoData} · ${l10n.geoDataMissing}';
    }
    return [
      for (final miss in GeoMiss.values)
        if (misses.contains(miss)) _labelOf(miss),
    ].join(' · ');
  }
}
