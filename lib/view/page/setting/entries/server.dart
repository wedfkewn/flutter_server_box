part of '../entry.dart';

extension _Server on _AppSettingsPageState {
  Widget _buildServer() {
    return Column(
      children: [
        _buildConnectionStats(),
        _buildServerMore(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildConnectionStats() {
    return ListTile(
      leading: const Icon(Icons.analytics, size: _kIconSize),
      title: Text(l10n.connectionStats),
      subtitle: Text(l10n.connectionStatsDesc),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        ConnectionStatsPage.route.go(context);
      },
    );
  }

  Widget _buildDeleteServers() {
    return ListTile(
      title: Text(l10n.deleteServers),
      leading: const Icon(Icons.delete_forever),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        final keys = Stores.server.keys();
        final names = Map.fromEntries(
          keys.map(
            (e) => MapEntry(e, ref.read(serversProvider).servers[e]?.name ?? e),
          ),
        );
        final deleteKeys = await context.showPickDialog<String>(
          clearable: true,
          items: keys.toList(),
          display: (p0) => names[p0] ?? p0,
        );
        if (deleteKeys == null || deleteKeys.isEmpty) return;

        final md = deleteKeys.map((e) => '- ${names[e] ?? e}').join('\n');
        final sure = await context.showRoundDialog(
          title: libL10n.attention,
          child: SimpleMarkdown(data: md),
          actions: Btnx.cancelRedOk,
        );

        if (sure != true) return;
        for (final key in deleteKeys) {
          Stores.server.remove(key);
        }
        context.showSnackBar(libL10n.success);
      },
    );
  }

  Widget _buildTextScaler() {
    return ListTile(
      // title: Text(l10n.textScaler),
      // subtitle: Text(l10n.textScalerTip, style: UIs.textGrey),
      title: TipText(l10n.textScaler, l10n.textScalerTip),
      trailing: ValBuilder(
        listenable: _setting.textFactor.listenable(),
        builder: (val) => Text(val.toString(), style: UIs.text15),
      ),
      onTap: () => context.showRoundDialog(
        title: l10n.textScaler,
        child: Input(
          autoFocus: true,
          type: TextInputType.number,
          hint: '1.0',
          icon: Icons.format_size,
          controller: _textScalerCtrl,
          onSubmitted: _onSaveTextScaler,
          suggestion: false,
        ),
        actions: Btn.ok(
          onTap: () => _onSaveTextScaler(_textScalerCtrl.text),
        ).toList,
      ),
    );
  }

  void _onSaveTextScaler(String s) {
    final val = double.tryParse(s);
    if (val == null) {
      context.showSnackBar(libL10n.fail);
      return;
    }
    _setting.textFactor.put(val);
    RNodes.app.notify();
    context.pop();
  }

  Widget _buildDoubleColumnServersPage() {
    return ListTile(
      // title: Text(l10n.doubleColumnMode),
      // subtitle: Text(l10n.doubleColumnTip, style: UIs.textGrey),
      title: TipText(l10n.doubleColumnMode, l10n.doubleColumnTip),
      trailing: StoreSwitch(prop: _setting.doubleColumnServersPage),
    );
  }

  Widget _buildKeepStatusWhenErr() {
    return ListTile(
      title: Text(l10n.keepStatusWhenErr),
      subtitle: Text(l10n.keepStatusWhenErrTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.keepStatusWhenErr),
    );
  }

  Widget _buildServerMore() {
    return ExpandTile(
      leading: const Icon(MingCute.more_3_fill),
      title: Text(l10n.more),
      initiallyExpanded: false,
      children: [
        _buildServerTabPreferDiskAmount(),
        _buildRememberPwdInMem(),
        _buildTextScaler(),
        _buildKeepStatusWhenErr(),
        _buildDoubleColumnServersPage(),
        _buildUpdateInterval(),
        _buildMaxRetry(),
        _buildSSHConfigImport(),
      ],
    );
  }

  Widget _buildRememberPwdInMem() {
    return ListTile(
      // title: Text(l10n.rememberPwdInMem),
      // subtitle: Text(l10n.rememberPwdInMemTip, style: UIs.textGrey),
      title: TipText(l10n.rememberPwdInMem, l10n.rememberPwdInMemTip),
      trailing: StoreSwitch(prop: _setting.rememberPwdInMem),
    );
  }


  Widget _buildServerTabPreferDiskAmount() {
    return ListTile(
      title: Text(l10n.preferDiskAmount),
      trailing: StoreSwitch(prop: Stores.setting.serverTabPreferDiskAmount),
    );
  }

  Widget _buildSSHConfigImport() {
    return ListTile(
      title: Text(l10n.sshConfigImport),
      subtitle: Text(l10n.sshConfigImportTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.firstTimeReadSSHCfg),
    );
  }
}
