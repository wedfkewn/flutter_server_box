import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/provider/port_forward_provider.dart';
import 'package:server_box/data/res/store.dart';

final class PortForwardPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const PortForwardPage({super.key, required this.args});

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: PortForwardPage.new,
    path: '/port_forward',
  );

  @override
  ConsumerState<PortForwardPage> createState() => _PortForwardPageState();
}

final class _PortForwardPageState extends ConsumerState<PortForwardPage> {
  late final PortForwardNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(portForwardProvider(widget.args.spi.id).notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showBetaWarning();
    });
  }

  void _showBetaWarning() {
    if (Stores.setting.portForwardBetaWarned.fetch()) return;
    var noMore = false;
    context.showRoundDialog(
      title: libL10n.attention,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(context.l10n.betaTip)),
          UIs.height13,
          StatefulBuilder(
            builder: (context, setState) {
              return Row(
                children: [
                  Checkbox(
                    value: noMore,
                    onChanged: (v) {
                      setState(() => noMore = v ?? false);
                      Stores.setting.portForwardBetaWarned.put(noMore);
                    },
                  ),
                  Text(l10n.noPromptAgain),
                ],
              );
            },
          ),
        ],
      ),
      actions: [Btnx.ok],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(
          up: l10n.portForwardBetaTitle,
          down: widget.args.spi.name,
        ),
        actions: [IconButton(tooltip: libL10n.add, icon: const Icon(Icons.add), onPressed: _onAdd)],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final state = ref.watch(portForwardProvider(widget.args.spi.id));
    final configs = state.configs;

    if (configs.isEmpty) {
      return _buildEmpty();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: configs.length,
      itemBuilder: (context, index) {
        final config = configs[index];
        final status = state.activeForwards[config.id];
        return _buildConfigTile(config, status);
      },
    );
  }

  Widget _buildEmpty() {
    if (MediaQuery.sizeOf(context).width < 700) return _buildWarmEmpty();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.compare_arrows, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(libL10n.empty, style: UIs.textGrey),
          const SizedBox(height: 8),
          Text(context.l10n.portForward_startPrompt, style: UIs.text13Grey),
        ],
      ),
    );
  }

  Widget _buildWarmEmpty() {
    final theme = Theme.of(context);
    final loc = context.l10n;
    Widget type(IconData icon, String title, String tip) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: theme.colorScheme.onSurface), const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleSmall), const SizedBox(height: 4),
          Text(tip, style: theme.textTheme.bodySmall),
        ])),
      ]),
    );
    return SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
      children: [
        Center(child: CircleAvatar(radius: 56, backgroundColor: theme.colorScheme.surfaceContainerLow,
          child: Icon(Icons.compare_arrows, size: 52, color: theme.colorScheme.primary))),
        const SizedBox(height: 32),
        Text(loc.warmNoPortRules, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(loc.warmPortRulesTip, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant, height: 1.6)),
        const SizedBox(height: 24),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: FilledButton(
          onPressed: _onAdd,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Text(loc.warmAddRule),
        )),
        const SizedBox(height: 38), const Divider(), const SizedBox(height: 12),
        Text(loc.warmForwardTypes, style: theme.textTheme.titleSmall),
        type(Icons.computer_outlined, loc.warmLocalForward, loc.warmLocalForwardTip),
        type(Icons.dns_outlined, loc.warmRemoteForward, loc.warmRemoteForwardTip),
        type(Icons.shuffle, loc.warmDynamicForward, loc.warmDynamicForwardTip),
      ],
    ));
  }

  Widget _buildConfigTile(PortForwardConfig config, PortForwardStatus? status) {
    final isActive = status?.isActive ?? false;
    final hasError = status?.error != null;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        isActive ? Icons.link : Icons.link_off,
        color: isActive
            ? colorScheme.primary
            : (hasError ? colorScheme.error : colorScheme.onSurfaceVariant),
      ),
      title: Text(config.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(config.displayAddr, style: UIs.text13Grey),
          if (hasError)
            Text(
              status!.error!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: isActive,
            onChanged: (_) => _notifier.toggleForward(config.id),
          ),
          PopupMenu(
            items: [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 18),
                    const SizedBox(width: 8),
                    Text(libL10n.edit),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete, size: 18),
                    const SizedBox(width: 8),
                    Text(libL10n.delete),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'edit') {
                _onEdit(config);
              } else if (val == 'delete') {
                _onDelete(config);
              }
            },
          ),
        ],
      ),
      isThreeLine: hasError,
    ).cardx.paddingSymmetric(horizontal: 13, vertical: 4);
  }

  void _onAdd() {
    _showConfigDialog(null);
  }

  void _onEdit(PortForwardConfig config) {
    _showConfigDialog(config);
  }

  void _onDelete(PortForwardConfig config) async {
    final sure = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(context.l10n.portForward_deleteConfirmFmt(config.name)),
      actions: Btnx.cancelOk,
    );
    if (sure == true) {
      await _notifier.removeConfig(config.id);
    }
  }

  void _showConfigDialog(PortForwardConfig? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _PortForwardConfigDialog(
        existing: existing,
        serverId: widget.args.spi.id,
        onSave: (config) async {
          if (existing == null) {
            await _notifier.addConfig(config);
          } else {
            final wasActive =
                ref
                    .read(portForwardProvider(widget.args.spi.id))
                    .activeForwards[existing.id]
                    ?.isActive ??
                false;
            await _notifier.updateConfig(existing, config);
            if (wasActive) {
              await _notifier.startForward(config.id);
            }
          }
        },
      ),
    );
  }
}

class _PortForwardConfigDialog extends StatefulWidget {
  final PortForwardConfig? existing;
  final String serverId;
  final Future<void> Function(PortForwardConfig config) onSave;

  const _PortForwardConfigDialog({
    required this.existing,
    required this.serverId,
    required this.onSave,
  });

  @override
  State<_PortForwardConfigDialog> createState() =>
      _PortForwardConfigDialogState();
}

class _PortForwardConfigDialogState extends State<_PortForwardConfigDialog> {
  late final TextEditingController nameController;
  late final TextEditingController localHostController;
  late final TextEditingController localPortController;
  late final TextEditingController remoteHostController;
  late final TextEditingController remotePortController;
  late PortForwardType _selectedType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.existing?.name ?? '');
    localHostController = TextEditingController(
      text: widget.existing?.localHost ?? '',
    );
    localPortController = TextEditingController(
      text: widget.existing?.localPort.toString() ?? '',
    );
    remoteHostController = TextEditingController(
      text: widget.existing?.remoteHost ?? '',
    );
    remotePortController = TextEditingController(
      text: widget.existing?.remotePort?.toString() ?? '',
    );
    _selectedType = widget.existing?.type ?? PortForwardType.local;
  }

  @override
  void dispose() {
    nameController.dispose();
    localHostController.dispose();
    localPortController.dispose();
    remoteHostController.dispose();
    remotePortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? libL10n.add : libL10n.edit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Input(controller: nameController, hint: libL10n.name),
            const SizedBox(height: 8),
            _buildTypeSelector(),
            const SizedBox(height: 8),
            _buildAddressFields(localHostController, localPortController, _localHostHint, _localPortHint),
            if (_selectedType != PortForwardType.dynamic) ...[
              const SizedBox(height: 8),
              _buildAddressFields(remoteHostController, remotePortController, _remoteHostHint, _remotePortHint),
            ],
          ],
        ),
      ),
      actions: [
        Btn.cancel(),
        Btn.ok(onTap: _onSave),
      ],
    );
  }

  String get _localHostHint => context.l10n.portForward_localHost;

  Widget _buildAddressFields(TextEditingController host, TextEditingController port, String hostLabel, String portLabel) {
    final fields = [Input(controller: host, hint: hostLabel),
      Input(controller: port, hint: portLabel, type: TextInputType.number)];
    if (MediaQuery.sizeOf(context).width < 360 || MediaQuery.textScalerOf(context).scale(14) > 20) {
      return Column(mainAxisSize: MainAxisSize.min, children: [fields.first, const SizedBox(height: 8), fields.last]);
    }
    return Row(children: [Expanded(child: fields.first), const SizedBox(width: 8), Expanded(child: fields.last)]);
  }

  String get _localPortHint => context.l10n.portForward_localPort;

  String get _remoteHostHint => _selectedType == PortForwardType.dynamic
      ? ''
      : context.l10n.portForward_remoteHost;

  String get _remotePortHint => _selectedType == PortForwardType.dynamic
      ? ''
      : context.l10n.portForward_remotePort;

  Widget _buildTypeSelector() {
    if (MediaQuery.sizeOf(context).width < 700) {
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final type in PortForwardType.values) ChoiceChip(
          label: Text(switch (type) {
            PortForwardType.local => _localTypeLabel,
            PortForwardType.remote => _remoteTypeLabel,
            PortForwardType.dynamic => _dynamicTypeLabel,
          }),
          selected: _selectedType == type,
          onSelected: (_) => setState(() => _selectedType = type),
        ),
      ]);
    }
    return SegmentedButton<PortForwardType>(
      segments: [
        ButtonSegment(
          value: PortForwardType.local,
          label: Text(_localTypeLabel),
          icon: const Icon(Icons.arrow_forward, size: 16),
        ),
        ButtonSegment(
          value: PortForwardType.remote,
          label: Text(_remoteTypeLabel),
          icon: const Icon(Icons.arrow_back, size: 16),
        ),
        ButtonSegment(
          value: PortForwardType.dynamic,
          label: Text(_dynamicTypeLabel),
          icon: const Icon(Icons.hub, size: 16),
        ),
      ],
      selected: {_selectedType},
      onSelectionChanged: (selection) {
        setState(() {
          _selectedType = selection.first;
        });
      },
    );
  }

  String get _localTypeLabel => libL10n.local;

  String get _remoteTypeLabel => libL10n.remote;

  String get _dynamicTypeLabel => 'SOCKS5';

  Future<void> _onSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final name = nameController.text.trim();
      final localHost = localHostController.text.trim();
      final localPort = int.tryParse(localPortController.text.trim()) ?? 0;
      final remoteHost = remoteHostController.text.trim();
      final remotePort = int.tryParse(remotePortController.text.trim()) ?? 0;

      if (name.isEmpty ||
          localHost.isEmpty ||
          localPort <= 0 ||
          localPort > 65535) {
        if (mounted) Toast.show(libL10n.invalid);
        return;
      }

      if (_selectedType != PortForwardType.dynamic) {
        if (remoteHost.isEmpty || remotePort <= 0 || remotePort > 65535) {
          if (mounted) Toast.show(libL10n.invalid);
          return;
        }
      }

      final config = PortForwardConfig(
        id: widget.existing?.id ?? ShortId.generate(),
        serverId: widget.serverId,
        name: name,
        type: _selectedType,
        localHost: localHost,
        localPort: localPort,
        remoteHost: _selectedType == PortForwardType.dynamic
            ? null
            : remoteHost,
        remotePort: _selectedType == PortForwardType.dynamic
            ? null
            : remotePort,
      );

      await widget.onSave(config);
      if (mounted) context.pop();
    } catch (e, s) {
      Loggers.app.warning('Failed to save port forward config', e, s);
      if (mounted) Toast.error(libL10n.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
