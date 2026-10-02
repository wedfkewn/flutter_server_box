import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/globe/view.dart';
import 'package:server_box/view/widget/server_globe.dart';

String _text(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

class ServerDistributionCard extends ConsumerStatefulWidget {
  const ServerDistributionCard({super.key, required this.ids});
  final List<String> ids;
  @override
  ConsumerState<ServerDistributionCard> createState() =>
      _ServerDistributionCardState();
}

class _ServerDistributionCardState
    extends ConsumerState<ServerDistributionCard> {
  final _session = ServerGlobeSession();
  @override
  void initState() {
    super.initState();
    _session.attach();
  }

  @override
  void dispose() {
    _session.detach();
    super.dispose();
  }

  void _open() {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ServerDistributionPage(ids: List.of(widget.ids), session: _session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Semantics(
      button: true,
      label: _text(context, '打开服务器分布地球仪', 'Open server globe'),
      child: InkWell(
        key: const ValueKey('server-distribution-card'),
        onTap: _open,
        child: SizedBox(
          height: 220,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                child: Row(
                  children: [
                    const Icon(Icons.public, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _text(context, '服务器分布', 'Server distribution'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.open_in_full, size: 18),
                  ],
                ),
              ),
              Expanded(
                child: ServerGlobe(
                  ids: widget.ids,
                  session: _session,
                  mode: ServerGlobeMode.preview,
                  onTapServer: (_) {},
                  onEditServer: (_) {},
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ListenableBuilder(
                  listenable: _session,
                  builder: (context, _) {
                    final count = widget.ids
                        .where(_session.located.containsKey)
                        .length;
                    return Text(
                      widget.ids.isEmpty
                          ? _text(
                              context,
                              '当前筛选下没有服务器',
                              'No servers match the filters',
                            )
                          : _text(
                              context,
                              '$count / ${widget.ids.length} 已定位 · 点击探索',
                              '$count / ${widget.ids.length} located · Tap to explore',
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ServerDistributionPage extends ConsumerStatefulWidget {
  const ServerDistributionPage({
    super.key,
    required this.ids,
    required this.session,
  });
  final List<String> ids;
  final ServerGlobeSession session;
  @override
  ConsumerState<ServerDistributionPage> createState() =>
      _ServerDistributionPageState();
}

class _ServerDistributionPageState
    extends ConsumerState<ServerDistributionPage> {
  final _controller = GlobeViewController();
  @override
  void initState() {
    super.initState();
    widget.session.attach();
  }

  @override
  void dispose() {
    widget.session.detach();
    _controller.dispose();
    super.dispose();
  }

  void _details(Spi spi) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ServerDetailPage(args: SpiRequiredArgs(spi)),
    ),
  );

  void _edit(Spi spi) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ServerEditPage(args: SpiRequiredArgs(spi)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(serversProvider.select((s) => s.servers));
    final ids = widget.ids.where(servers.containsKey).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_text(context, '服务器分布', 'Server distribution')),
        actions: [
          IconButton(
            key: const ValueKey('globe-reset'),
            tooltip: _text(context, '重置视角', 'Reset view'),
            onPressed: _controller.reset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stores.setting.globeEnabled.listenable().listenVal(
          (enabled) => enabled
              ? ServerGlobe(
                  ids: ids,
                  session: widget.session,
                  controller: _controller,
                  mode: ServerGlobeMode.explorer,
                  onTapServer: _details,
                  onEditServer: _edit,
                )
              : Center(
                  child: Text(_text(context, '地球仪已关闭', 'Globe is disabled')),
                ),
        ),
      ),
    );
  }
}
