part of 'tab.dart';

extension _WarmDashboard on _ServerPageState {
  Widget _buildWarmDashboard() {
    final state = ref.watch(serversProvider);
    final live = <ServerState>[
      for (final id in state.serverOrder) ref.watch(serverProvider(id)),
    ];

    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([_tag, _tags, _search, _ipLookupRevision]),
        builder: (context, _) {
          final allowed = _filterServers(state.serverOrder).toSet();
          final filtered = live
              .where((e) => allowed.contains(e.spi.id))
              .toList();
          final online = live
              .where((e) => e.conn == ServerConn.finished)
              .length;
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
    final l10n = context.l10n;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.warmOverview,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.warmDataMonitoring,
                      style: const TextStyle(color: WarmTheme.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.ipLookupTitle,
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const IpLookupPage()),
                  );
                  _ipLookupRevision.value++;
                },
                icon: const Icon(
                  Icons.travel_explore,
                  color: Color(0xff367cff),
                ),
              ),
              _WarmPill(
                icon: Icons.circle,
                label: l10n.warmMonitoring,
                color: WarmTheme.lemon,
                foreground: WarmTheme.olive,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            l10n.warmServerStatus,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _WarmStatusTile(
                  icon: Icons.check_circle,
                  value: online,
                  label: l10n.warmOnline,
                  color: WarmTheme.olive,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _WarmStatusTile(
                  icon: Icons.cloud_off_outlined,
                  value: offline,
                  label: l10n.warmOffline,
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
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.warmMyServers,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filledTonal(
          tooltip: context.libL10n.add,
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
            label: Text(tag.isEmpty ? context.l10n.warmAll : tag),
            onSelected: (_) => _tag.value = tag,
            selectedColor: const Color(0xffffb97f),
            backgroundColor: WarmTheme.canvas,
          );
        },
      ),
    );
  }

  Widget _warmEmpty(bool hasNoServers) {
    final l10n = context.l10n;
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
            hasNoServers ? l10n.warmNoServers : l10n.warmNoServersInFilter,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            hasNoServers ? l10n.warmAddServerTip : l10n.warmChooseAnotherTag,
            textAlign: TextAlign.center,
            style: const TextStyle(color: WarmTheme.muted),
          ),
          if (hasNoServers) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _onTapAddServer,
              icon: const Icon(Icons.add),
              label: Text(context.libL10n.add),
            ),
          ],
        ],
      ),
    );
  }

  Widget _warmServerCard(ServerState srv) {
    final l10n = context.l10n;
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.libL10n.terminal,
                    onPressed: () => _openWarmTerminal(srv.spi),
                    icon: const Icon(Icons.terminal, color: WarmTheme.copper),
                  ),
                  IconButton(
                    tooltip: context.libL10n.refresh,
                    onPressed: () {
                      Stores.ipLookupCache.forgetServer(srv.spi.id);
                      Stores.serviceReachabilityCache.forgetServer(srv.spi.id);
                      _ipLookupRevision.value++;
                      ref.read(serversProvider.notifier).refresh(spi: srv.spi);
                    },
                    icon: const Icon(
                      Icons.monitor_heart_outlined,
                      color: WarmTheme.copper,
                    ),
                  ),
                  _WarmPill(
                    icon: Icons.circle,
                    label: connected ? l10n.warmOnline : l10n.warmOffline,
                    color: connected
                        ? const Color(0xffe6ead8)
                        : const Color(0xfff4dddd),
                    foreground: connected
                        ? const Color(0xff276b31)
                        : WarmTheme.danger,
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
              _WarmNetworkBadges(
                key: ValueKey('${srv.spi.id}:${_ipLookupRevision.value}'),
                server: srv,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _WarmMetric(
                      label: l10n.warmCpu,
                      value: cpu,
                      color: const Color(0xff168bd2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WarmMetric(
                      label: l10n.warmMemory,
                      value: memory,
                      color: const Color(0xff9223b0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WarmMetric(
                      label: l10n.warmDisk,
                      value: disk,
                      color: const Color(0xffdc3d1e),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.warmCoreCount(ss.cpu.coresCount),
                      style: const TextStyle(
                        fontSize: 10,
                        color: WarmTheme.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${_warmGb(memoryUsed)}/${_warmGb(ss.mem.total)} GB',
                      style: const TextStyle(
                        fontSize: 10,
                        color: WarmTheme.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _warmDisk(ss.diskUsage),
                      style: const TextStyle(
                        fontSize: 10,
                        color: WarmTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: WarmTheme.muted,
                        ),
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
                      title: l10n.warmUpload,
                      speed: net.speedOut,
                      total: net.sizeOut,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WarmTransfer(
                      icon: Icons.download,
                      title: l10n.warmDownload,
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
                    label: l10n.warmAlert,
                    background: WarmTheme.lemon,
                    foreground: WarmTheme.olive,
                    onTap: () => _showWarmAlert(srv),
                  ),
                  const Spacer(),
                  _WarmAction(
                    icon: Icons.edit,
                    label: context.libL10n.edit,
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
                    label: context.libL10n.delete,
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
        title: Text('${ctx.libL10n.delete} ${srv.spi.name}?'),
        content: Text(ctx.libL10n.askContinue(ctx.libL10n.delete)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.libL10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WarmTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.libL10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(serversProvider.notifier).delServer(srv.spi.id);
    }
  }

  Future<void> _showWarmAlert(ServerState srv) async {
    final l10n = context.l10n;
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
          title: Column(
            children: [
              const Icon(
                Icons.notifications,
                color: WarmTheme.copper,
                size: 23,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.warmAlertSettings,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: WarmTheme.peach,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.computer, color: WarmTheme.copper),
                        const SizedBox(width: 10),
                        Text(
                          srv.spi.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.warmEnableAlerts,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              l10n.warmEnableAlertsTip,
                              style: const TextStyle(
                                color: WarmTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: enabled,
                        onChanged: (v) => update(() => enabled = v),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _WarmAlertSlider(
                    icon: Icons.memory,
                    label: l10n.warmCpuAlert,
                    value: cpu,
                    enabled: enabled,
                    onChanged: (v) => update(() => cpu = v),
                  ),
                  _WarmAlertSlider(
                    icon: Icons.dns,
                    label: l10n.warmMemoryAlert,
                    value: memory,
                    enabled: enabled,
                    onChanged: (v) => update(() => memory = v),
                  ),
                  _WarmAlertSlider(
                    icon: Icons.storage,
                    label: l10n.warmDiskAlert,
                    value: disk,
                    enabled: enabled,
                    onChanged: (v) => update(() => disk = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.libL10n.cancel),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Toast.success(l10n.warmAlertSaved);
              },
              icon: const Icon(Icons.save),
              label: Text(ctx.libL10n.save),
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

class _WarmNetworkBadges extends ConsumerStatefulWidget {
  const _WarmNetworkBadges({super.key, required this.server});

  final ServerState server;

  @override
  ConsumerState<_WarmNetworkBadges> createState() => _WarmNetworkBadgesState();
}

class _WarmNetworkBadgesState extends ConsumerState<_WarmNetworkBadges> {
  IpLookupResult? _result;
  final Map<ServiceKind, ServiceReachabilityResult> _services = {};
  bool _serviceLoading = false;
  late final List<Listenable> _settingListenables;

  @override
  void initState() {
    super.initState();
    _settingListenables = [
      Stores.setting.showServerNetworkInfo.listenable(),
      Stores.setting.probeChatGpt.listenable(),
      Stores.setting.probeNetflix.listenable(),
      Stores.setting.probeGemini.listenable(),
    ];
    for (final listenable in _settingListenables) {
      listenable.addListener(_settingsChanged);
    }
    _settingsChanged();
  }

  @override
  void dispose() {
    for (final listenable in _settingListenables) {
      listenable.removeListener(_settingsChanged);
    }
    super.dispose();
  }

  Set<ServiceKind> _enabledServices() => {
    if (Stores.setting.probeChatGpt.fetch()) ServiceKind.chatGpt,
    if (Stores.setting.probeNetflix.fetch()) ServiceKind.netflix,
    if (Stores.setting.probeGemini.fetch()) ServiceKind.gemini,
  };

  void _settingsChanged() {
    if (!Stores.setting.showServerNetworkInfo.fetch()) {
      _result = null;
    } else if (Stores.setting.ipLookupConsent.fetch()) {
      unawaited(_load());
    }
    final enabled = _enabledServices();
    _services.removeWhere((key, _) => !enabled.contains(key));
    if (enabled.isNotEmpty) unawaited(_loadServices(enabled));
    if (mounted) setState(() {});
  }

  Future<void> _loadServices(Set<ServiceKind> enabled) async {
    if (_serviceLoading) return;
    final server = widget.server;
    final target = server.spi.displayAddr;
    final missing = <ServiceKind>{};
    for (final service in enabled) {
      final cached = Stores.serviceReachabilityCache.fresh(
        server.spi.id,
        target,
        service,
      );
      if (cached == null) {
        missing.add(service);
      } else {
        _services[service] = cached;
      }
    }
    if (mounted) setState(() {});
    if (missing.isEmpty) return;
    _serviceLoading = true;
    try {
      final results = await ref
          .read(serverProvider(server.spi.id).notifier)
          .probeServices(missing);
      final now = DateTime.now();
      for (final service in missing) {
        final result =
            results[service] ??
            ServiceReachabilityResult(
              service: service,
              state: ServiceReachabilityState.unknown,
              checkedAt: now,
            );
        Stores.serviceReachabilityCache.put(server.spi.id, target, result);
        if (_enabledServices().contains(service)) _services[service] = result;
      }
    } catch (_) {
      final now = DateTime.now();
      for (final service in missing) {
        Stores.serviceReachabilityCache.put(
          server.spi.id,
          target,
          ServiceReachabilityResult(
            service: service,
            state: ServiceReachabilityState.unknown,
            checkedAt: now,
          ),
        );
      }
    } finally {
      _serviceLoading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _load() async {
    final server = widget.server;
    InternetAddress? address = SelfAddr.pick(server.status.ips);
    if (address == null) {
      final host = IpGeo.geoHostOf(server.spi);
      if (host == null) return;
      try {
        address = (await IpLookupService().resolveInput(host)).firstOrNull;
      } on IpLookupFailure {
        return;
      }
    }
    if (address == null) return;

    Stores.ipLookupCache.forgetServerExcept(server.spi.id, address.address);
    final cached = Stores.ipLookupCache.fresh(server.spi.id, address.address);
    if (cached != null) {
      if (mounted) setState(() => _result = cached);
      return;
    }

    try {
      final result = await IpLookupService().lookup(
        address,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      Stores.ipLookupCache.putResult(server.spi.id, result);
      if (mounted) setState(() => _result = result);
    } on IpLookupFailure {
      // Enrichment is optional. A failed third-party lookup must never make
      // the server card or its primary monitoring data look failed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final labels = <(String, String)>[];
    if (Stores.setting.showServerNetworkInfo.fetch() && result != null) {
      final country = [
        result.flagEmoji,
        result.countryCode,
      ].whereType<String>().join(' ');
      final network = [
        country,
        result.organization,
        result.networkDomain,
        result.asnLabel,
        if (result.isp != result.organization) result.isp,
      ].whereType<String>().where((value) => value.trim().isNotEmpty);
      labels.addAll(network.map((value) => (value, value)));
    }
    const names = {
      ServiceKind.chatGpt: 'ChatGPT',
      ServiceKind.netflix: 'Netflix',
      ServiceKind.gemini: 'Gemini',
    };
    final enabled = _enabledServices();
    for (final service in ServiceKind.values) {
      if (enabled.contains(service) && _services[service]?.reachable == true) {
        labels.add((names[service]!, context.l10n.serviceProbeDisclaimer));
      }
    }
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final label in labels)
            Tooltip(
              message: label.$2,
              child: _WarmOutlineChip(label: label.$1),
            ),
        ],
      ),
    );
  }
}

class _WarmStatusTile extends StatelessWidget {
  const _WarmStatusTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 104,
    decoration: BoxDecoration(
      color: const Color(0xfff6e6da),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(height: 5),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: WarmTheme.muted),
        ),
      ],
    ),
  );
}

class _WarmPill extends StatelessWidget {
  const _WarmPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 9, color: foreground),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
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
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 10, color: WarmTheme.ink),
    ),
  );
}

class _WarmMetric extends StatelessWidget {
  const _WarmMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${value.round()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
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
  const _WarmTransfer({
    required this.icon,
    required this.title,
    required this.speed,
    required this.total,
  });
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
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              total,
              style: const TextStyle(fontSize: 9, color: WarmTheme.muted),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          speed,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: WarmTheme.copper,
          ),
        ),
      ],
    ),
  );
}

class _WarmAction extends StatelessWidget {
  const _WarmAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });
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
    label: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _WarmAlertSlider extends StatelessWidget {
  const _WarmAlertSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
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
            child: Slider(
              value: value,
              min: 10,
              max: 100,
              divisions: 18,
              label: '${value.round()}%',
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        Text(
          context.l10n.warmAlertAbove(value.round()),
          style: const TextStyle(color: WarmTheme.muted, fontSize: 12),
        ),
      ],
    ),
  );
}
