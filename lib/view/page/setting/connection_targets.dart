part of 'entry.dart';

/// Select a real SSH target for bastion configuration.
final class _ConnectionTargetsPage extends ConsumerWidget {
  const _ConnectionTargetsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref
        .watch(serversProvider)
        .servers
        .values
        .where((spi) => spi.ssh != null)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(context.l10n.warmBastionConfigTip),
        const SizedBox(height: 12),
        if (servers.isEmpty)
          ListTile(title: Text(context.l10n.settingsNoSshServers)),
        for (final spi in servers)
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: Text(spi.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ServerEditPage.route.go(context, args: SpiRequiredArgs(spi));
            },
          ),
      ],
    );
  }
}

final class _SettingsLogsPage extends StatelessWidget {
  const _SettingsLogsPage();

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      icon: const Icon(Icons.receipt_long_outlined),
      label: Text(context.libL10n.logs),
      onPressed: () => DebugPage.route.go(
        context,
        args: DebugPageArgs(
          title: '${context.libL10n.logs}(${BuildData.build})',
        ),
      ),
    ),
  );
}
