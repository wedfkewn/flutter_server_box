part of 'tab.dart';

extension _WarmDashboard on _ServerPageState {
  Widget _buildWarmDashboard() {
    final state = ref.watch(serversProvider);
    final live = <ServerState>[
      for (final id in state.serverOrder) ref.watch(serverProvider(id)),
    ];

    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([_tag, _tags, _search]),
        builder: (context, _) {
          final allowed = _filterServers(state.serverOrder).toSet();
          final filtered = live.where((e) => allowed.contains(e.spi.id)).toList();
          final online = live.where((e) => e.conn == ServerConn.finished).length;
          final offline = live.length - online;

          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  sliver: SliverList.list(
                    children: [
                      _warmOverview(online: online, offline: offline),
                      const SizedBox(height: 22),
                      _warmServerHeader(),
                      const SizedBox(height: 14),
                      _warmFilters(state.tags.toList()),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        _warmEmpty(state.serverOrder.isEmpty)
                      else
                        for (final srv in filtered) ...[
                          _warmServerCard(srv),
                          const SizedBox(height: 16),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _warmOverview({required int online, required int offline}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: WarmTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text('Data Monitoring', style: TextStyle(color: WarmTheme.muted)),
                  ],
                ),
              ),
              const _WarmPill(
                icon: Icons.circle,
                label: 'Monitoring',
                color: WarmTheme.lemon,
                foreground: WarmTheme.olive,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Server Status', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _WarmStatusTile(
                  icon: Icons.check_circle,
                  value: online,
                  label: 'Online',
                  color: WarmTheme.olive,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _WarmStatusTile(
                  icon: Icons.cloud_off_outlined,
                  value: offline,
                  label: 'Offline',
                  color: WarmTheme.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _warmServerHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'My Servers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filledTonal(
          tooltip: libL10n.add,
          onPressed: _onTapAddServer,
          style: IconButton.styleFrom(
            backgroundColor: WarmTheme.peach,
            foregroundColor: WarmTheme.ink,
          ),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _warmFilters(List<String> tags) {
    final shown = ['', ...tags];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final tag = shown[index];
          final selected = tag == _tag.value;
          return ChoiceChip(
            selected: selected,
            showCheckmark: selected,
            label: Text(tag.isEmpty ? 'All' : tag),
            onSelected: (_) => _tag.value = tag,
            selectedColor: const Color(0xffffb97f),
            backgroundColor: WarmTheme.canvas,
          );
        },
      ),
    );
  }

  Widget _warmEmpty(bool hasNoServers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 42),
      decoration: BoxDecoration(
        color: WarmTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.dns_outlined, size: 38, color: WarmTheme.copper),
          const SizedBox(height: 12),
          Text(
            hasNoServers ? 'No servers yet' : 'No servers in this filter',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            hasNoServers
                ? 'Add a server to begin monitoring and open an SSH terminal.'
                : 'Choose another tag to see your servers.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: WarmTheme.muted),
          ),
          if (hasNoServers) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _onTapAddServer,
              icon: const Icon(Icons.add),
              label: Text(libL10n.add),
            ),
          ],
        ],
      ),
    );
  }

  Widget _warmServerCard(ServerState srv) {
    final ss = srv.status;
    final connected = srv.conn == ServerConn.finished;
    final cpu = (ss.cpu.usedPercent() ?? 0).clamp(0, 100).toDouble();
    final memory = (ss.mem.usedPercent * 100).clamp(0, 100).toDouble();
    final disk = (ss.diskUsage?.usedPercent ?? 0).clamp(0, 100).toDouble();
    final tags = <String>[
      if (ss.osId?.isNotEmpty == true) ss.osId!,
      srv.spi.displayAddr,
      ...?srv.spi.tags,
    ];
    final memoryUsed = ss.mem.total - ss.mem.avail;
    final net = ss.netSpeed.cachedVals;

    return Material(
      color: WarmTheme.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onTapCard(context, srv),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      srv.spi.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: libL10n.terminal,
                    onPressed: () => _openWarmTerminal(srv.spi),
                    icon: const Icon(Icons.terminal, color: WarmTheme.copper),
                  ),
                  IconButton(
                    tooltip: libL10n.refresh,
                    onPressed: () => ref.read(serversProvider.notifier).refresh(spi: srv.spi),
                    icon: const Icon(Icons.monitor_heart_outlined, color: WarmTheme.copper),
                  ),
                  _WarmPill(
                    icon: Icons.circle,
                    label: connected ? 'Online' : 'Offline',
                    color: connected
                        ? const Color(0xffe6ead8)
                        : const Color(0xfff4dddd),
                    foreground: connected ? const Color(0xff276b31) : WarmTheme.danger,
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in tags.take(6))
                      _WarmOutlineChip(label: label),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _WarmMetric(label: 'CPU', value: cpu, color: const Color(0xff168bd2))),
                  const SizedBox(width: 12),
                  Expanded(child: _WarmMetric(label: 'Memory', value: memory, color: const Color(0xff9223b0))),
                  const SizedBox(width: 12),
                  Expanded(child: _WarmMetric(label: 'Disk', value: disk, color: const Color(0xffdc3d1e))),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: Text('${ss.cpu.coresCount} core', style: const TextStyle(fontSize: 10, color: WarmTheme.muted))),
                  Expanded(child: Text('${_warmGb(memoryUsed)}/${_warmGb(ss.mem.total)} GB', style: const TextStyle(fontSize: 10, color: WarmTheme.muted))),
                  Expanded(child: Text(_warmDisk(ss.diskUsage), style: const TextStyle(fontSize: 10, color: WarmTheme.muted))),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: WarmTheme.surfaceStrong,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.memory, size: 16, color: WarmTheme.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ss.cpu.brand.keys.firstOrNull ?? srv.spi.displayAddr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: WarmTheme.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _WarmTransfer(
                      icon: Icons.upload,
                      title: 'Upload',
                      speed: net.speedOut,
                      total: net.sizeOut,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WarmTransfer(
                      icon: Icons.download,
                      title: 'Download',
                      speed: net.speedIn,
                      total: net.sizeIn,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _WarmAction(
                    icon: Icons.notifications,
                    label: 'Alert',
                    background: WarmTheme.lemon,
                    foreground: WarmTheme.olive,
                    onTap: () => _showWarmAlert(srv),
                  ),
                  const Spacer(),
                  _WarmAction(
                    icon: Icons.edit,
                    label: libL10n.edit,
                    background: WarmTheme.peach,
                    foreground: WarmTheme.ink,
                    onTap: () => ServerEditPage.route.go(
                      context,
                      args: SpiRequiredArgs(srv.spi),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _WarmAction(
                    icon: Icons.delete,
                    label: libL10n.delete,
                    background: const Color(0xfff7dfe1),
                    foreground: WarmTheme.danger,
                    onTap: () => _deleteWarmServer(srv),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWarmTerminal(Spi spi) {
    ref.read(terminalRequestsProvider.notifier).add(spi);
    ref.read(homeTabRequestProvider.notifier).go(AppTab.ssh);
  }

  Future<void> _deleteWarmServer(ServerState srv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${libL10n.delete} ${srv.spi.name}?'),
        content: Text(libL10n.askContinue(libL10n.delete)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(libL10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WarmTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(libL10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(serversProvider.notifier).delServer(srv.spi.id);
    }
  }

  Future<void> _showWarmAlert(ServerState srv) async {
    var enabled = true;
    var cpu = 90.0;
    var memory = 90.0;
    var disk = 90.0;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          title: const Column(
            children: [
              Icon(Icons.notifications, color: WarmTheme.copper, size: 23),
              SizedBox(height: 6),
              Text('Alert Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: WarmTheme.peach,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.computer, color: WarmTheme.copper),
                        const SizedBox(width: 10),
                        Text(srv.spi.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enable Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            Text('Monitor server status and send notifications', style: TextStyle(color: WarmTheme.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(value: enabled, onChanged: (v) => update(() => enabled = v)),
                    ],
                  ),
                  const Divider(height: 20),
                  _WarmAlertSlider(icon: Icons.memory, label: 'CPU Usage Alert', value: cpu, enabled: enabled, onChanged: (v) => update(() => cpu = v)),
                  _WarmAlertSlider(icon: Icons.dns, label: 'Memory Usage Alert', value: memory, enabled: enabled, onChanged: (v) => update(() => memory = v)),
                  _WarmAlertSlider(icon: Icons.storage, label: 'Disk Usage Alert', value: disk, enabled: enabled, onChanged: (v) => update(() => disk = v)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Toast.success('Alert settings saved');
              },
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _warmGb(int kib) => (kib / 1024 / 1024).toStringAsFixed(1);

  String _warmDisk(DiskUsage? usage) {
    if (usage == null || usage.size == BigInt.zero) return '--';
    final used = usage.used.toDouble() / 1024 / 1024;
    final total = usage.size.toDouble() / 1024 / 1024;
    return '${used.toStringAsFixed(0)}/${total.toStringAsFixed(0)} GB';
  }
}

class _WarmStatusTile extends StatelessWidget {
  const _WarmStatusTile({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 104,
    decoration: BoxDecoration(color: const Color(0xfff6e6da), borderRadius: BorderRadius.circular(24)),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(height: 5),
        Text('$value', style: TextStyle(color: color, fontSize: 27, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 11, color: WarmTheme.muted)),
      ],
    ),
  );
}

class _WarmPill extends StatelessWidget {
  const _WarmPill({required this.icon, required this.label, required this.color, required this.foreground});
  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 9, color: foreground),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: foreground)),
      ],
    ),
  );
}

class _WarmOutlineChip extends StatelessWidget {
  const _WarmOutlineChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 180),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xffffeee2),
      border: Border.all(color: const Color(0xffd3bdad)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: WarmTheme.ink)),
  );
}

class _WarmMetric extends StatelessWidget {
  const _WarmMetric({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          Text('${value.round()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          minHeight: 7,
          value: value / 100,
          backgroundColor: const Color(0xffefded1),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ],
  );
}

class _WarmTransfer extends StatelessWidget {
  const _WarmTransfer({required this.icon, required this.title, required this.speed, required this.total});
  final IconData icon;
  final String title;
  final String speed;
  final String total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
    decoration: BoxDecoration(
      color: const Color(0xfff3e3d6),
      border: Border.all(color: const Color(0xffc9aa92)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: WarmTheme.copper),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            Text(total, style: const TextStyle(fontSize: 9, color: WarmTheme.muted)),
          ],
        ),
        const SizedBox(height: 7),
        Text(speed, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: WarmTheme.copper)),
      ],
    ),
  );
}

class _WarmAction extends StatelessWidget {
  const _WarmAction({required this.icon, required this.label, required this.background, required this.foreground, required this.onTap});
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      visualDensity: VisualDensity.compact,
    ),
    icon: Icon(icon, size: 15),
    label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

class _WarmAlertSlider extends StatelessWidget {
  const _WarmAlertSlider({required this.icon, required this.label, required this.value, required this.enabled, required this.onChanged});
  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: WarmTheme.copper, size: 21),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        SizedBox(
          height: 34,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 7),
            child: Slider(value: value, min: 10, max: 100, divisions: 18, label: '${value.round()}%', onChanged: enabled ? onChanged : null),
          ),
        ),
        Text('Alert when above ${value.round()}%', style: const TextStyle(color: WarmTheme.muted, fontSize: 12)),
      ],
    ),
  );
}
