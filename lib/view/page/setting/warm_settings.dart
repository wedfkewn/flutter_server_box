part of 'entry.dart';

extension _WarmSettings on _SettingsPageState {
  Widget _buildWarmSettings(List<SettingsNode> nodes) {
    final l10n = context.l10n;
    SettingsNode byId(String id) => nodes
        .expand((node) => node.flattened)
        .firstWhere((node) => node.id == id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      children: [
        _WarmSettingsSection(l10n.warmAppearanceSettings),
        _WarmSettingsRow(
          icon: Icons.palette,
          title: context.libL10n.themeMode,
          subtitle: l10n.warmLight,
          onTap: () => _onTab(byId('app.setting')),
        ),
        _WarmSettingsRow(
          icon: Icons.view_agenda,
          title: l10n.warmCardBadges,
          subtitle: l10n.warmCardBadgesTip,
          onTap: () => _onTab(byId('server.setting')),
        ),
        _WarmSettingsSection(l10n.warmSecuritySettings),
        Stores.setting.privacyBlur.listenable().listenVal(
          (enabled) => _WarmSettingsRow(
            icon: Icons.visibility_off,
            title: l10n.warmPrivacyMode,
            subtitle: l10n.warmPrivacyModeTip,
            trailing: Switch(
              value: enabled,
              onChanged: (value) => Stores.setting.privacyBlur.put(value),
            ),
            onTap: () => Stores.setting.privacyBlur.put(!enabled),
          ),
        ),
        _WarmSettingsRow(
          icon: Icons.cloud_sync,
          title: l10n.warmCloudBackup,
          subtitle: l10n.warmCloudBackupTip,
          onTap: () => _onTab(byId('backup.sync')),
        ),
        _WarmSettingsRow(
          icon: Icons.route,
          title: l10n.warmBastionConfig,
          subtitle: l10n.warmBastionConfigTip,
          onTap: () => _onTab(byId('terminal.setting')),
        ),
        _WarmSettingsRow(
          icon: Icons.cable,
          title: l10n.warmTunnelConfig,
          subtitle: l10n.warmTunnelConfigTip,
          onTap: () => _onTab(byId('terminal.setting')),
        ),
        _WarmSettingsRow(
          icon: Icons.delete,
          title: l10n.warmClearSecureData,
          subtitle: l10n.warmClearSecureDataTip,
          danger: true,
          onTap: () => _onTab(byId('privateKey')),
        ),
        _WarmSettingsSection(l10n.warmAppSettings),
        _WarmSettingsRow(
          icon: Icons.timer,
          title: l10n.warmDefaultStatusSpeed,
          subtitle: '${Stores.setting.serverStatusUpdateInterval.fetch()} s',
          onTap: () => _onTab(byId('server.setting')),
        ),
        _WarmSettingsRow(
          icon: Icons.translate,
          title: context.libL10n.language,
          subtitle: Stores.setting.locale.fetch().isEmpty
              ? l10n.warmSystem
              : Stores.setting.locale.fetch(),
          onTap: () => _onTab(byId('app.setting')),
        ),
        _WarmSettingsRow(
          icon: Icons.format_size,
          title: l10n.warmTerminalFontSize,
          subtitle: '${Stores.setting.termFontSize.fetch()} pt',
          onTap: () => _onTab(byId('terminal.setting')),
        ),
        _WarmSettingsRow(
          icon: Icons.font_download,
          title: l10n.warmTerminalFont,
          subtitle: l10n.warmSystemMonospace,
          onTap: () => _onTab(byId('terminal.setting')),
        ),
      ],
    );
  }
}

class _WarmSettingsSection extends StatelessWidget {
  const _WarmSettingsSection(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        color: WarmTheme.copper,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _WarmSettingsRow extends StatelessWidget {
  const _WarmSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Icon(
              icon,
              size: 23,
              color: danger ? WarmTheme.danger : WarmTheme.ink,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: danger ? WarmTheme.danger : WarmTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: WarmTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    ),
  );
}
