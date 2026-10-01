part of 'tab.dart';

extension _WarmDashboard on _ServerPageState {
  Widget _buildWarmDashboard() {
    final order = ref.watch(
      serversProvider.select((state) => state.serverOrder),
    );
    final tags = ref.watch(serversProvider.select((state) => state.tags));
    // Search and tag filtering read server names/addresses from this map.
    // Monitoring updates live in each server provider, not in this one.
    ref.watch(serversProvider.select((state) => state.servers));

    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([_tag, _tags, _search, _ipLookupRevision]),
        builder: (context, _) {
          final filtered = _filterServers(order);

          return RefreshIndicator(
            onRefresh: _refreshWarmDashboard,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    WarmTheme.pagePadding,
                    16,
                    WarmTheme.pagePadding,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final online = order.where((id) {
                              return ref.watch(
                                    serverProvider(id).select((s) => s.conn),
                                  ) ==
                                  ServerConn.finished;
                            }).length;
                            return _warmOverview(
                              online: online,
                              offline: order.length - online,
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        _warmServerHeader(),
                        const SizedBox(height: 12),
                        _warmFilters(tags.toList()),
                        const SizedBox(height: WarmTheme.sectionGap),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      WarmTheme.pagePadding,
                      0,
                      WarmTheme.pagePadding,
                      18,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _warmEmpty(order.isEmpty),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      WarmTheme.pagePadding,
                      0,
                      WarmTheme.pagePadding,
                      18,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final id = filtered[index];
                          return Padding(
                            key: ValueKey(id),
                            padding: const EdgeInsets.only(
                              bottom: WarmTheme.sectionGap,
                            ),
                            child: RepaintBoundary(
                              child: Consumer(
                                builder: (context, ref, _) => _warmServerCard(
                                  ref.watch(serverProvider(id)),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: filtered.length,
                        findChildIndexCallback: (key) {
                          if (key is! ValueKey<String>) return null;
                          final index = filtered.indexOf(key.value);
                          return index < 0 ? null : index;
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshWarmDashboard() async {
    Stores.ipLookupCache.clear();
    Stores.serviceReachabilityCache.clear();
    _ipLookupRevision.value++;
    await _refreshAll();
  }

  void _refreshWarmServer(ServerState server) {
    Stores.ipLookupCache.forgetServer(server.spi.id);
    Stores.serviceReachabilityCache.forgetServer(server.spi.id);
    _ipLookupRevision.value++;
    unawaited(ref.read(serversProvider.notifier).refresh(spi: server.spi));
  }

  Widget _warmOverview({required int online, required int offline}) {
    final l10n = context.l10n;
    return Column(
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
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.libL10n.refresh,
              onPressed: _refreshWarmDashboard,
              icon: const Icon(Icons.refresh),
            ),
            TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  isMobile
                      ? WarmPageRoute<void>(
                          builder: (_) => const IpLookupPage(),
                          reduceMotion: MediaQuery.of(
                            context,
                          ).disableAnimations,
                        )
                      : MaterialPageRoute<void>(
                          builder: (_) => const IpLookupPage(),
                        ),
                );
                _ipLookupRevision.value++;
              },
              icon: const Icon(Icons.travel_explore),
              label: Text(l10n.ipLookupTitle),
            ),
          ],
        ),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.warmDataMonitoring,
              style: const TextStyle(color: WarmTheme.muted),
            ),
            _WarmPill(
              icon: Icons.circle,
              label: l10n.warmMonitoring,
              color: Colors.transparent,
              foreground: WarmTheme.olive,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _WarmStatusCount(
              value: online,
              label: l10n.warmOnline,
              color: WarmTheme.olive,
            ),
            const Text('/', style: TextStyle(color: WarmTheme.muted)),
            _WarmStatusCount(
              value: offline,
              label: l10n.warmOffline,
              color: WarmTheme.muted,
            ),
          ],
        ),
      ],
    );
  }

  Widget _warmServerHeader() {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.warmMyServers,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        FilledButton.icon(
          onPressed: _onTapAddServer,
          icon: const Icon(Icons.add),
          label: Text(l10n.warmAddServer),
        ),
      ],
    );
  }

  Widget _warmFilters(List<String> tags) {
    final shown = ['', ...tags];
    return SizedBox(
      height: math.max(40, MediaQuery.textScalerOf(context).scale(14) + 24),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final tag = shown[index];
          final selected = tag == _tag.value;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text(tag.isEmpty ? context.l10n.warmAll : tag),
            onSelected: (_) => _tag.value = tag,
            labelStyle: TextStyle(
              color: selected ? Colors.white : WarmTheme.ink,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: WarmTheme.copper,
            backgroundColor: WarmTheme.surface,
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
        borderRadius: BorderRadius.circular(WarmTheme.cardRadius),
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
    final cpu = ss.cpu.usedPercent();
    // InitStatus.mem is a denominator placeholder, not a collected reading.
    final memory = ss.mem.total > 0 && !identical(ss.mem, InitStatus.mem)
        ? ss.mem.usedPercent * 100
        : null;
    final disk = ss.diskUsage?.size != BigInt.zero
        ? ss.diskUsage?.usedPercent
        : null;
    final memoryUsed =
        ss.mem.total - (ss.mem.avail == 0 ? ss.mem.free : ss.mem.avail);
    final net = ss.netSpeed.cachedVals;

    return Material(
      color: WarmTheme.surface,
      borderRadius: BorderRadius.circular(WarmTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onTapCard(context, srv),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            WarmTheme.cardPadding,
            18,
            WarmTheme.cardPadding,
            16,
          ),
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
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: context.libL10n.refresh,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _refreshWarmServer(srv),
                      child: _WarmPill(
                        icon: Icons.circle,
                        label: connected ? l10n.warmOnline : l10n.warmOffline,
                        color: connected
                            ? const Color(0xffe6ead8)
                            : const Color(0xfff4dddd),
                        foreground: connected
                            ? const Color(0xff276b31)
                            : WarmTheme.danger,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openWarmTerminal(srv.spi),
                    icon: const Icon(Icons.terminal, size: 18),
                    label: Text(context.libL10n.terminal),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _WarmNetworkBadges(
                key: ValueKey('${srv.spi.id}:${_ipLookupRevision.value}'),
                server: srv,
              ),
              Row(
                children: [
                  Expanded(
                    child: _WarmMetric(
                      label: l10n.warmCpu,
                      value: cpu,
                      color: const Color(0xff168bd2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WarmMetric(
                      label: l10n.warmMemory,
                      value: memory,
                      color: const Color(0xff9223b0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WarmMetric(
                      label: l10n.warmDisk,
                      value: disk,
                      color: const Color(0xffdc3d1e),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ss.cpu.coresCount > 0
                          ? l10n.warmCoreCount(ss.cpu.coresCount)
                          : '—',
                      style: const TextStyle(
                        fontSize: 10,
                        color: WarmTheme.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      memory == null
                          ? '—'
                          : '${_warmGb(memoryUsed)}/${_warmGb(ss.mem.total)} GB',
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
              if (ss.cpu.brand.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: WarmTheme.surfaceStrong,
                    borderRadius: BorderRadius.circular(
                      WarmTheme.controlRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.memory,
                        size: 16,
                        color: WarmTheme.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ss.cpu.brand.keys.first,
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
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
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
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WarmAction(
                      icon: Icons.notifications,
                      label: l10n.warmAlert,
                      background: Colors.transparent,
                      foreground: WarmTheme.olive,
                      onTap: () => _showWarmAlert(srv),
                    ),
                    _WarmAction(
                      icon: Icons.edit,
                      label: context.libL10n.edit,
                      background: Colors.transparent,
                      foreground: WarmTheme.ink,
                      onTap: () => ServerEditPage.route.go(
                        context,
                        args: SpiRequiredArgs(srv.spi),
                      ),
                    ),
                    _WarmAction(
                      icon: Icons.delete,
                      label: context.libL10n.delete,
                      background: Colors.transparent,
                      foreground: WarmTheme.danger,
                      onTap: () => _deleteWarmServer(srv),
                    ),
                  ],
                ),
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
      animationStyle: isMobile ? WarmMotion.dialog(context) : null,
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
      animationStyle: isMobile ? WarmMotion.dialog(context) : null,
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
    if (usage == null || usage.size == BigInt.zero) return '—';
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
  Set<ServiceKind> _observedServices = {};
  bool _serviceLoading = false;
  int _lookupGeneration = 0;
  int _probeGeneration = 0;
  late String _target;
  String? _publicIp;
  DateTime? _lastProbeAttempt;
  late final List<Listenable> _settingListenables;

  static const _serviceNames = {
    ServiceKind.chatGpt: 'ChatGPT',
    ServiceKind.netflix: 'Netflix',
    ServiceKind.gemini: 'Gemini',
  };

  String get _currentTarget => widget.server.spi.displayAddr;

  String? get _currentPublicIp =>
      SelfAddr.pick(widget.server.status.ips)?.address;

  @override
  void initState() {
    super.initState();
    _target = _currentTarget;
    _publicIp = _currentPublicIp;
    _settingListenables = [
      Stores.setting.ipLookupConsent.listenable(),
      Stores.setting.showServerNetworkInfo.listenable(),
      Stores.setting.probeChatGpt.listenable(),
      Stores.setting.probeNetflix.listenable(),
      Stores.setting.probeGemini.listenable(),
    ];
    for (final listenable in _settingListenables) {
      listenable.addListener(_settingsChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settingsChanged();
  }

  @override
  void didUpdateWidget(covariant _WarmNetworkBadges oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetChanged =
        _target != _currentTarget ||
        widget.server.spi.shouldReconnect(oldWidget.server.spi);
    final ipChanged = _publicIp != _currentPublicIp;
    if (targetChanged) {
      _target = _currentTarget;
      _probeGeneration++;
      _serviceLoading = false;
      _lastProbeAttempt = null;
      _services.clear();
      Stores.serviceReachabilityCache.forgetServer(widget.server.spi.id);
    }
    if (targetChanged || ipChanged) {
      _publicIp = _currentPublicIp;
      _lookupGeneration++;
      _result = null;
      if (Stores.setting.showServerNetworkInfo.fetch() &&
          Stores.setting.ipLookupConsent.fetch()) {
        unawaited(_load());
      }
    }
    if (targetChanged || widget.server.conn == ServerConn.finished) {
      unawaited(_loadServices(_enabledServices()));
    }
  }

  @override
  void dispose() {
    _lookupGeneration++;
    _probeGeneration++;
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
    _lookupGeneration++;
    if (!Stores.setting.showServerNetworkInfo.fetch() ||
        !Stores.setting.ipLookupConsent.fetch()) {
      _result = null;
    } else if (Stores.setting.ipLookupConsent.fetch()) {
      unawaited(_load());
    }
    final enabled = _enabledServices();
    if (enabled.length != _observedServices.length ||
        !enabled.containsAll(_observedServices)) {
      _observedServices = enabled;
      _probeGeneration++;
      _serviceLoading = false;
    }
    _services.removeWhere((key, _) => !enabled.contains(key));
    if (enabled.isNotEmpty) unawaited(_loadServices(enabled));
    if (mounted) setState(() {});
  }

  Future<void> _loadServices(Set<ServiceKind> enabled) async {
    if (_serviceLoading || enabled.isEmpty) return;
    final server = widget.server;
    final target = _target;
    final generation = _probeGeneration;
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
    // An optional badge must not reconnect a server the user disconnected.
    // Cached readings can still be shown, but new probes wait for monitoring.
    if (missing.isEmpty || server.conn != ServerConn.finished) return;
    final now = DateTime.now();
    if (_lastProbeAttempt != null &&
        now.difference(_lastProbeAttempt!) < const Duration(minutes: 1)) {
      return;
    }
    _lastProbeAttempt = now;
    _serviceLoading = true;
    if (mounted) setState(() {});
    try {
      final results = await ref
          .read(serverProvider(server.spi.id).notifier)
          .probeServices(missing);
      if (!mounted || generation != _probeGeneration) return;
      final now = DateTime.now();
      for (final service in missing) {
        if (!_enabledServices().contains(service)) continue;
        final result =
            results[service] ??
            ServiceReachabilityResult(
              service: service,
              state: ServiceReachabilityState.unknown,
              checkedAt: now,
            );
        Stores.serviceReachabilityCache.put(server.spi.id, target, result);
        _services[service] = result;
      }
    } catch (_) {
      if (!mounted || generation != _probeGeneration) return;
      final now = DateTime.now();
      for (final service in missing) {
        if (_enabledServices().contains(service)) {
          _services[service] = ServiceReachabilityResult(
            service: service,
            state: ServiceReachabilityState.unknown,
            checkedAt: now,
          );
        }
      }
    } finally {
      if (mounted && generation == _probeGeneration) {
        setState(() => _serviceLoading = false);
      }
    }
  }

  Future<void> _load() async {
    final generation = ++_lookupGeneration;
    final server = widget.server;
    final languageCode = Localizations.localeOf(context).languageCode;
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
    if (address == null || !mounted || generation != _lookupGeneration) return;

    Stores.ipLookupCache.forgetServerExcept(server.spi.id, address.address);
    final cached = Stores.ipLookupCache.fresh(server.spi.id, address.address);
    if (cached != null) {
      setState(() => _result = cached);
      return;
    }

    try {
      final result = await IpLookupService().lookup(
        address,
        languageCode: languageCode,
      );
      if (!mounted || generation != _lookupGeneration) return;
      Stores.ipLookupCache.putResult(server.spi.id, result);
      setState(() => _result = result);
    } on IpLookupFailure {
      // Enrichment is optional. A failed third-party lookup must never make
      // the server card or its primary monitoring data look failed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;
    final labels = <String>[
      if (widget.server.status.osId?.isNotEmpty == true)
        widget.server.status.osId!,
      widget.server.spi.displayAddr,
      ...?widget.server.spi.tags,
    ];
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
      labels.addAll(network);
    }
    final enabled = _enabledServices();
    // Keep the two requested checks discoverable before they are enabled.
    // Their switches still control whether any outbound request is made.
    final shown = {ServiceKind.chatGpt, ServiceKind.netflix, ...enabled};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WarmSectionTitle(
          title: l10n.warmServerInfo,
          reportLabel: l10n.warmReport,
          onReport: () => _showReport(result),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final label in labels.toSet())
              Tooltip(
                message: label,
                child: _WarmOutlineChip(label: label),
              ),
          ],
        ),
        const Divider(height: 24),
        _WarmSectionTitle(
          title: l10n.warmServiceChecks,
          reportLabel: l10n.warmDetectionReport,
          onReport: () => _showReport(result),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final service in shown)
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _showReport(result),
                child: _WarmPill(
                  icon: _serviceIcon(service),
                  iconSize: 14,
                  label:
                      '${_serviceNames[service]} · ${_serviceStateText(service)}',
                  color: _services[service]?.reachable == true
                      ? const Color(0xffe6ead8)
                      : const Color(0xfff0e5dd),
                  foreground: _serviceColor(service),
                ),
              ),
          ],
        ),
        const Divider(height: 24),
      ],
    );
  }

  IconData _serviceIcon(ServiceKind service) {
    if (!_enabledServices().contains(service)) {
      return Icons.radio_button_unchecked;
    }
    return switch (_services[service]?.state) {
      ServiceReachabilityState.reachable => Icons.check_circle_outline,
      ServiceReachabilityState.unreachable => Icons.cancel_outlined,
      ServiceReachabilityState.unknown || null => Icons.radio_button_unchecked,
    };
  }

  Color _serviceColor(ServiceKind service) {
    if (!_enabledServices().contains(service)) return WarmTheme.muted;
    return switch (_services[service]?.state) {
      ServiceReachabilityState.reachable => const Color(0xff276b31),
      ServiceReachabilityState.unreachable => WarmTheme.danger,
      ServiceReachabilityState.unknown || null => WarmTheme.muted,
    };
  }

  Future<void> _showReport(IpLookupResult? result) async {
    final l10n = context.l10n;
    final shown = {
      ServiceKind.chatGpt,
      ServiceKind.netflix,
      ..._enabledServices(),
    };
    final rows = <(String, String)>[
      (context.libL10n.name, widget.server.spi.name),
      (context.libL10n.host, widget.server.spi.displayAddr),
      (
        l10n.warmSystem,
        widget.server.status.more[StatusCmdType.sys] ??
            widget.server.status.osId ??
            '',
      ),
      if (result != null) ...[
        (result.type, result.ip),
        (
          l10n.ipLookupCountry,
          [result.flagEmoji, result.country].whereType<String>().join(' '),
        ),
        (l10n.ipLookupIsp, result.isp ?? ''),
        (l10n.ipLookupOrganization, result.organization ?? ''),
        (l10n.ipLookupAsn, result.asnLabel ?? ''),
        (l10n.ipLookupDomain, result.networkDomain ?? ''),
      ],
    ].where((row) => row.$2.trim().isNotEmpty).toList(growable: false);
    final openSettings = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              l10n.networkCheckReport,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.networkCheckReportTip,
              style: const TextStyle(color: WarmTheme.muted),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.public_off_outlined),
                title: Text(l10n.ipLookupNotDetected),
                subtitle: Text(l10n.ipLookupDisclaimer),
              )
            else
              for (final row in rows)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    row.$1,
                    style: const TextStyle(color: WarmTheme.muted),
                  ),
                  subtitle: Text(
                    row.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            const Divider(height: 22),
            Text(
              l10n.networkCheckServices,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final service in shown)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _serviceIcon(service),
                  color: _serviceColor(service),
                ),
                title: Text(_serviceNames[service]!),
                subtitle: Text(
                  [
                    _serviceStateText(service),
                    if (_services[service] != null)
                      _services[service]!.checkedAt
                          .toLocal()
                          .toString()
                          .split('.')
                          .first,
                  ].join(' · '),
                ),
              ),
            Text(
              l10n.serviceProbeDisclaimer,
              style: const TextStyle(color: WarmTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.tune),
              label: Text(l10n.warmCardBadges),
            ),
          ],
        ),
      ),
    );
    if (openSettings == true && mounted) {
      await SettingsPage.showServerInfo(context);
    }
  }

  String _serviceStateText(ServiceKind service) {
    if (!_enabledServices().contains(service)) {
      return context.l10n.serviceProbeDisabled;
    }
    final result = _services[service];
    if (result == null) {
      return _serviceLoading
          ? context.l10n.serviceProbeChecking
          : context.l10n.serviceProbePending;
    }
    return switch (result.state) {
      ServiceReachabilityState.reachable => context.l10n.networkCheckReachable,
      ServiceReachabilityState.unreachable =>
        context.l10n.networkCheckUnreachable,
      ServiceReachabilityState.unknown => context.l10n.serviceProbeUnavailable,
    };
  }
}

class _WarmSectionTitle extends StatelessWidget {
  const _WarmSectionTitle({
    required this.title,
    required this.reportLabel,
    required this.onReport,
  });

  final String title;
  final String reportLabel;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      TextButton(
        onPressed: onReport,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
        child: Text('$reportLabel ›', style: const TextStyle(fontSize: 11)),
      ),
    ],
  );
}

class _WarmStatusCount extends StatelessWidget {
  const _WarmStatusCount({
    required this.value,
    required this.label,
    required this.color,
  });
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(width: 8),
      Text(
        '$value',
        style: TextStyle(
          color: color,
          fontSize: 23,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _WarmPill extends StatelessWidget {
  const _WarmPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
    this.iconSize = 9,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: foreground),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
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
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 10.5,
        height: 1.15,
        color: WarmTheme.ink,
      ),
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
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reading = value?.isFinite == true ? value!.clamp(0, 100) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              reading == null ? '—' : '${reading.round()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: (reading ?? 0) / 100,
            backgroundColor: const Color(0xffefded1),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 16, color: WarmTheme.copper),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              speed == '--' ? '—' : speed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      if (total != '--')
        Padding(
          padding: const EdgeInsets.only(left: 22, top: 4),
          child: Text(
            total,
            style: const TextStyle(fontSize: 9, color: WarmTheme.muted),
          ),
        ),
    ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
