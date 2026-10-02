part of 'entry.dart';

extension _WarmSettings on _SettingsPageState {
  Widget _buildWarmSettings(List<SettingsNode> nodes) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppPageBody(child: ListView(
      key: const PageStorageKey('warm-settings-root'),
      padding: const EdgeInsets.fromLTRB(
        WarmTheme.pagePadding,
        24,
        WarmTheme.pagePadding,
        20,
      ),
      children: [
        Text(
          context.libL10n.setting,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          BuildData.name,
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.settingsCategoryIntro,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        for (final node in nodes)
          _WarmSettingsCategory(
            key: ValueKey('warm-category-${node.id}'),
            node: node,
            expanded: _warmExpandedId == node.id,
            onToggle: () => _onWarmToggle(node),
            onSelect: _onTab,
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            '${BuildData.name} v${BuildData.build}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    ));
  }

  Widget _buildWarmSettingEntries(List<SettingsNode> nodes) {
    return ListView.separated(
      key: PageStorageKey('warm-settings-${_path.lastOrNull?.id ?? 'root'}'),
      padding: EdgeInsets.fromLTRB(
        isMobile ? WarmTheme.pagePadding : 28,
        16,
        isMobile ? WarmTheme.pagePadding : 28,
        24,
      ),
      itemCount: nodes.length,
      separatorBuilder: (_, _) => SizedBox(height: isMobile ? 12 : 0),
      itemBuilder: (context, index) {
        final node = nodes[index];
        final row = _WarmSettingsRow(
          icon: node.icon,
          title: node.title,
          subtitle: node.isLeaf ? '' : context.l10n.settingsOpenCategory,
          onTap: () => _onTab(node),
          cardStyle: isMobile,
        );
        return isMobile
            ? AppCard(
                key: ValueKey(node.id),
                child: row,
              )
            : row;
      },
    );
  }
}

/// One inline category; its leaves still open the existing settings navigator.
class _WarmSettingsCategory extends StatelessWidget {
  const _WarmSettingsCategory({
    super.key,
    required this.node,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final SettingsNode node;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<SettingsNode> onSelect;

  String _leafTitle(BuildContext context, SettingsNode leaf) =>
      switch (leaf.id) {
        'terminal.setting' => context.l10n.settingsTerminalTitle,
        'terminal.knownHosts' => context.l10n.settingsKnownHostsTitle,
        _ => leaf.title,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              expanded: expanded,
              child: InkWell(
                key: ValueKey('warm-category-toggle-${node.id}'),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: expanded
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(node.icon, size: 23, color: scheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          node.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: expanded ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: WarmMotion.of(context, WarmMotion.page),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: Column(
                        children: [
                          for (var i = 0; i < node.children.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: 8,
                                endIndent: 8,
                                color: scheme.outlineVariant,
                              ),
                            InkWell(
                              key: ValueKey(
                                'warm-setting-${node.children[i].id}',
                              ),
                              onTap: () => onSelect(node.children[i]),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _leafTitle(context, node.children[i]),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 22,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarmServerInfoSheet extends StatefulWidget {
  const _WarmServerInfoSheet({this.embedded = false});

  final bool embedded;

  @override
  State<_WarmServerInfoSheet> createState() => _WarmServerInfoSheetState();
}

class _WarmServerInfoSheetState extends State<_WarmServerInfoSheet> {
  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        animationStyle: isMobile ? WarmMotion.dialog(context) : null,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.libL10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.ipLookupAgree),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _network(bool value) async {
    if (value && !Stores.setting.ipLookupConsent.fetch()) {
      final ok = await _confirm(
        context.l10n.ipLookupPrivacyTitle,
        context.l10n.ipLookupPrivacyBody,
      );
      if (!ok) return;
      Stores.setting.ipLookupConsent.put(true);
    }
    Stores.setting.showServerNetworkInfo.put(value);
    if (mounted) setState(() {});
  }

  Future<void> _openChecks() async {
    final servers = Stores.server.fetch();
    final id = await showModalBottomSheet<String>(context: context,
      showDragHandle: true, builder: (sheetContext) => SafeArea(child: ListView(
        shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(
            probeText(context, '选择要检测的服务器', 'Choose a server to check'),
            style: Theme.of(context).textTheme.titleLarge)),
          if (servers.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(
            probeText(context, '请先在首页添加服务器', 'Add a server on the homepage first'))),
          for (final server in servers) ListTile(leading: const Icon(Icons.dns_outlined),
            title: Text(server.name), subtitle: Text(server.displayAddr),
            onTap: () => Navigator.pop(sheetContext, server.id)),
        ])));
    if (id != null && mounted) await ExternalProbesPage.show(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Column(
        children: [
          if (!widget.embedded) Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
            child: Row(children: [
              BackButton(
                key: const ValueKey('server-info-back'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.warmCardBadges,
                style: Theme.of(context).textTheme.titleLarge)),
            ]),
          ),
          Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          SwitchListTile(
            title: Text(l10n.serverInfoNetwork),
            subtitle: Text(l10n.serverInfoNetworkTip),
            value: Stores.setting.showServerNetworkInfo.fetch(),
            onChanged: _network,
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(probeText(context, '外网服务检测', 'External service checks')),
            subtitle: Text(probeText(context,
              '分类目录、自定义检测和首页置顶，按服务器配置',
              'Service catalog, custom checks and homepage pins, per server')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openChecks,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.serviceProbeDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
          )),
        ],
      ),
    );
  }
}

class _WarmSettingsRow extends StatelessWidget {
  const _WarmSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.cardStyle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool cardStyle;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(cardStyle ? WarmTheme.cardRadius : 18),
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(
        vertical: cardStyle ? 16 : 8,
        horizontal: cardStyle ? 16 : 10,
      ),
      child: Row(
        children: [
          cardStyle
              ? Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      WarmTheme.controlRadius,
                    ),
                  ),
                  child: Icon(icon, size: 22, color: WarmTheme.copper),
                )
              : SizedBox(
                  width: 46,
                  child: Icon(icon, size: 23, color: WarmTheme.ink),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: WarmTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: WarmTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: WarmTheme.muted),
        ],
      ),
    ),
  );
}
