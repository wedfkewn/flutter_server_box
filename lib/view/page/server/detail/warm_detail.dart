part of 'view.dart';

extension _WarmDetail on _ServerDetailPageState {
  Widget _buildWarmDetail(ServerState si) {
    final ss = si.status;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final funcs = ServerFuncBtns(spi: si.spi, granted: si.remoteAccess, menu: true);
    final disk = ss.diskUsage;
    final cpu = ss.cpu.usedPercent(coreIdx: 0);
    final memory = ss.mem.total > 0 ? ss.mem.usedPercent * 100 : null;
    final online = si.conn == server_model.ServerConn.connected || si.conn == server_model.ServerConn.finished;
    final children = <Widget>[
      ?_buildLogo(si),
      ?_buildErrCard(si),
      ServerGroup(children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14, runSpacing: 8, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 10, color: online ? scheme.secondary : scheme.error),
              const SizedBox(width: 6),
              Text(online ? l10n.warmOnline : l10n.warmOffline,
                style: theme.textTheme.labelLarge),
            ]),
            if (funcs.btnsWith(si.remoteAccess).isNotEmpty) funcs,
          ]),
        if (_cardsOrder.contains(ServerDetailCards.about.name)) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            controller: _expand('warm-about', false),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ss.more[StatusCmdType.sys] ?? libL10n.about, style: theme.textTheme.bodyMedium),
              if (ss.more[StatusCmdType.host] case final host?) Text(host, style: theme.textTheme.bodySmall),
              if (ss.more[StatusCmdType.uptime] case final uptime?) Text(uptime, style: theme.textTheme.bodySmall),
            ]),
            leading: const Icon(Icons.dns_outlined, size: 20),
            children: [
              for (final entry in ss.more.entries)
                if (entry.key != StatusCmdType.sys && entry.key != StatusCmdType.host && entry.key != StatusCmdType.uptime)
                  _buildAboutRow(entry.key.i18n, entry.value),
              if (SelfAddr.pick(ss.ips) case final ip?)
                _buildAboutRow(l10n.publicIp, ip.address, secret: true),
            ],
          ),
        ],
      ]),
      LayoutBuilder(builder: (context, constraints) {
        final metrics = <Widget>[
          if (_cardsOrder.contains(ServerDetailCards.cpu.name))
            _warmMetric(l10n.warmCpu, Icons.memory, cpu, ss.cpu.user == null ? '-- user' : '${ss.cpu.user!.toStringAsFixed(1)}% user'),
          if (_cardsOrder.contains(ServerDetailCards.mem.name) && ss.mem.total > 0)
            _warmMetric(l10n.warmMemory, Icons.storage_outlined, memory, (ss.mem.total * 1024).bytes2Str),
          if (_cardsOrder.contains(ServerDetailCards.disk.name) && disk != null && disk.size != BigInt.zero)
            _warmMetric(l10n.warmDisk, Icons.save_outlined, disk.usedPercent.toDouble(), '${disk.used.kb2Str} / ${disk.size.kb2Str}'),
        ];
        if (metrics.isEmpty) return const SizedBox.shrink();
        if (MediaQuery.textScalerOf(context).scale(14) > 20 || constraints.maxWidth < 330) {
          return Column(children: [for (final metric in metrics) Padding(
            padding: const EdgeInsets.only(bottom: 8), child: metric)]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (index, metric) in metrics.indexed) ...[
            if (index > 0) const SizedBox(width: 8), Expanded(child: metric),
          ],
        ]);
      }),
    ];
    for (final card in _cardsOrder) {
      final type = ServerDetailCards.fromName(card);
      if (type == ServerDetailCards.about) continue;
      final child = switch (type) {
        ServerDetailCards.cpu => _warmCpuCard(si),
        ServerDetailCards.mem => _warmMemoryCard(si),
        _ => _cardBuildMap[type]?.call(si),
      };
      if (child != null) children.add(child);
    }
    return Scaffold(
      appBar: _buildAppBar(si),
      body: SafeArea(child: ListView.separated(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, index) => children[index],
      )),
    );
  }

  Widget _warmMetric(String label, IconData icon, double? value, String subtitle) {
    final theme = Theme.of(context);
    return ServerGroup(padding: 12, children: [
      Wrap(spacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Icon(icon, size: 17, color: theme.colorScheme.primary),
        Text(label, style: theme.textTheme.labelMedium),
      ]),
      const SizedBox(height: 8),
      AppValueText(value == null ? '--' : '${value.toStringAsFixed(0)}%', style: theme.textTheme.titleLarge),
      const SizedBox(height: 4), Text(subtitle, style: theme.textTheme.bodySmall),
    ]);
  }

  Widget _warmCpuCard(ServerState si) {
    final ss = si.status;
    return AppCard(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _warmChartHeading(l10n.warmCpuUsage, '${_warmPercent(ss.cpu.user)} user  ${_warmPercent(ss.cpu.idle)} idle'),
      if (_cpuViewAsProgress) ..._buildCPUProgress(ss.cpu),
      ?_buildCpuChart(si),
      ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        controller: _expand('warm-cpu-details', false),
        title: Text(ss.cpu.brand.keys.join(' / '), maxLines: 1, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall),
        children: [
          Wrap(spacing: 14, runSpacing: 8, children: [
            _buildDetailPercent(ss.cpu.user, 'user'), _buildDetailPercent(ss.cpu.idle, 'idle'),
            if (ss.system == SystemType.linux) ...[
              _buildDetailPercent(ss.cpu.sys, 'sys'), _buildDetailPercent(ss.cpu.iowait, 'io'),
            ],
          ]),
          for (final brand in ss.cpu.brand.entries) _buildCpuModelItem(brand),
        ],
      ),
    ]));
  }

  Widget? _warmMemoryCard(ServerState si) {
    final mem = si.status.mem;
    if (mem.total == 0) return null;
    final used = (mem.total * mem.usedPercent * 1024).round();
    return AppCard(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _warmChartHeading(l10n.warmMemoryUsage, '${used.bytes2Str} / ${(mem.total * 1024).bytes2Str}'),
      ?_buildMemChart(si),
      Wrap(spacing: 18, children: [
        Text('${(mem.free / mem.total * 100).toStringAsFixed(1)}% free', style: Theme.of(context).textTheme.bodySmall),
        Text('${(mem.availPercent * 100).toStringAsFixed(1)}% avail', style: Theme.of(context).textTheme.bodySmall),
      ]),
    ]));
  }

  Widget _warmChartHeading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 4, children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ]),
  );

  String _warmPercent(double? value) => value == null ? '--' : '${value.toStringAsFixed(1)}%';
}
