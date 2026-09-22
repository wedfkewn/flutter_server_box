part of 'entry.dart';

extension _WarmSettings on _SettingsPageState {
  Widget _buildWarmSettings(List<SettingsNode> nodes) {
    return _buildWarmSettingEntries(nodes);
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
            ? Material(
                key: ValueKey(node.id),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(WarmTheme.cardRadius),
                clipBehavior: Clip.antiAlias,
                child: row,
              )
            : row;
      },
    );
  }
}

class _WarmServerInfoSheet extends StatefulWidget {
  const _WarmServerInfoSheet();

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

  Future<void> _probe(void Function(bool) put, bool value) async {
    final noneEnabled =
        !Stores.setting.probeChatGpt.fetch() &&
        !Stores.setting.probeNetflix.fetch() &&
        !Stores.setting.probeGemini.fetch();
    if (value && noneEnabled) {
      final ok = await _confirm(
        context.l10n.serviceProbePrivacyTitle,
        context.l10n.serviceProbePrivacyBody,
      );
      if (!ok) return;
    }
    put(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text(
            l10n.warmCardBadges,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(l10n.serverInfoNetwork),
            subtitle: Text(l10n.serverInfoNetworkTip),
            value: Stores.setting.showServerNetworkInfo.fetch(),
            onChanged: _network,
          ),
          for (final entry in [
            (
              'ChatGPT',
              Stores.setting.probeChatGpt.fetch(),
              Stores.setting.probeChatGpt.put,
            ),
            (
              'Netflix',
              Stores.setting.probeNetflix.fetch(),
              Stores.setting.probeNetflix.put,
            ),
            (
              'Gemini',
              Stores.setting.probeGemini.fetch(),
              Stores.setting.probeGemini.put,
            ),
          ])
            SwitchListTile(
              title: Text(entry.$1),
              subtitle: Text(l10n.serviceProbeTip),
              value: entry.$2,
              onChanged: (value) => _probe(entry.$3, value),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.serviceProbeDisclaimer,
              style: const TextStyle(color: WarmTheme.muted, fontSize: 12),
            ),
          ),
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
