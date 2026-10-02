part of '../entry.dart';

extension _Server on _AppSettingsPageState {
  void _showInvalidUrlDialog() {
    context.showRoundDialog(
      title: libL10n.fail,
      child: Text(libL10n.invalidUrl),
      actions: Btnx.oks,
    );
  }

  Widget _buildServer() {
    final rows = <Widget>[
        _buildDistIcon(),
        ListTile(leading: const Icon(Icons.apps_outlined),
          title: Text(Localizations.localeOf(context).languageCode == 'zh' ? '程序图标' : 'Program logos'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BrandIconsPage()))),
        _buildNetViewType(),
        _buildConnectionStats(),
        _buildDeleteServers(),
        _buildCpuView(),
        _buildGlobe(),
        _buildServerMore(),
      ];
    if (warmSettingsPhone(context)) {
      return Column(children: [
        WarmSettingsGroup(title: warmSettingsText(context, '信息与图表', 'Information and charts'), children: [rows[0], rows[1], rows[2], rows[5], rows[6]]),
        WarmSettingsGroup(title: warmSettingsText(context, '连接与刷新', 'Connections and refresh'), children: [rows[3], rows[7]]),
        WarmSettingsGroup(title: warmSettingsText(context, '服务器管理', 'Server management'), children: [rows[4]]),
      ]);
    }
    return Column(children: rows.map((e) => CardX(child: e)).toList());
  }

  Widget _buildNetViewType() {
    return ListTile(
      leading: const Icon(ZondIcons.network, size: _kIconSize),
      title: Text(l10n.netViewType),
      trailing: ValBuilder(
        listenable: _setting.netViewType.listenable(),
        builder: (val) => Text(val.toStr, style: UIs.text15),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.netViewType,
          items: NetViewType.values,
          display: (p0) => p0.toStr,
          initial: _setting.netViewType.fetch(),
        );
        if (selected != null) {
          _setting.netViewType.put(selected);
        }
      },
    );
  }

  Widget _buildConnectionStats() {
    return ListTile(
      leading: const Icon(Icons.analytics, size: _kIconSize),
      title: Text(l10n.connectionStats),
      subtitle: Text(l10n.connectionStatsDesc, style: UIs.textGrey),
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
        final notifier = ref.read(serversProvider.notifier);
        for (final key in deleteKeys) {
          await notifier.delServer(key);
        }
        Toast.success(libL10n.success);
      },
    );
  }

  Widget _buildTextScaler() {
    return ListTile(
      title: TipText(libL10n.textScaler, l10n.textScalerTip),
      trailing: ValBuilder(
        listenable: _setting.textFactor.listenable(),
        builder: (val) => Text(val.toString(), style: UIs.text15),
      ),
      onTap: () => context.showRoundDialog(
        title: libL10n.textScaler,
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
      Toast.error(libL10n.fail);
      return;
    }
    _setting.textFactor.put(val);
    RNodes.app.notify();
    context.popDialog();
  }

  Widget _buildDoubleColumnServersPage() {
    return ListTile(
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
      title: Text(libL10n.more),
      initiallyExpanded: false,
      children: [
        _buildServerTabPreferDiskAmount(),
        _buildRememberPwdInMem(),
        _buildTextScaler(),
        _buildKeepStatusWhenErr(),
        _buildDoubleColumnServersPage(),
        _buildUpdateInterval(),
        _buildMaxRetry(),
        if (isDesktop) _buildSSHConfigAutoImportToggle(),
      ],
    );
  }

  Widget _buildRememberPwdInMem() {
    return ListTile(
      title: TipText(l10n.rememberPwdInMem, l10n.rememberPwdInMemTip),
      trailing: StoreSwitch(prop: _setting.rememberPwdInMem),
    );
  }

  Widget _buildCpuView() {
    return ExpandTile(
      leading: const Icon(OctIcons.cpu, size: _kIconSize),
      title: Text('CPU ${l10n.view}'),
      children: [
        ListTile(
          title: Text(l10n.noLineChart),
          subtitle: Text(l10n.cpuViewAsProgressTip, style: UIs.textGrey),
          trailing: StoreSwitch(prop: _setting.cpuViewAsProgress),
        ),
        ListTile(
          title: Text(l10n.displayCpuIndex),
          trailing: StoreSwitch(prop: _setting.displayCpuIndex),
        ),
      ],
    );
  }

  /// Bundled distribution artwork with optional custom URL/name overrides.
  Widget _buildDistIcon() {
    return ExpandTile(
      leading: const Icon(Icons.dns_outlined),
      title: TipText(l10n.distIcon, warmSettingsText(context,
        '内置发行版 Logo，也支持自定义图片链接。',
        'Bundled distribution logos with optional custom image URLs.')),
      initiallyExpanded: false,
      children: [
        ListTile(
          // The tip doubles as this row's title: inside a section already
          // called "Distribution marks", repeating the name says nothing,
          // while what the switch does is the thing worth reading.
          title: Text(l10n.distIconTip),
          trailing: StoreSwitch(
            prop: _setting.showDistMark,
          ),
        ),
        _buildServerMarkUrl(),
        _buildServerLogoUrl(),
        _buildDistNameMap(),
      ],
    );
  }

  /// A custom address overrides the bundled distribution artwork.
  Widget _buildServerMarkUrl() {
    void onSave(String raw) {
      final url = resolveLogoUrl(raw);
      // Emptying the address restores bundled artwork.
      if (url.isEmpty) {
        _setting.serverMarkUrl.put('');
        context.popDialog();
        return;
      }
      if (!isFetchableLogoUrl(url)) {
        _showInvalidUrlDialog();
        return;
      }
      _setting.serverMarkUrl.put(url);
      context.popDialog();
    }

    return ListTile(
      leading: const Icon(Icons.label_outline),
      title: TipText(l10n.markUrl, l10n.markUrlTip),
      subtitle: ValBuilder(
        listenable: _setting.serverMarkUrl.listenable(),
        builder: (url) => Text(
          url.isEmpty ? libL10n.empty : url,
          style: UIs.textGrey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        _serverMarkCtrl.text = _setting.serverMarkUrl.fetch();
        context.showRoundDialog(
          title: l10n.markUrl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Input(
                controller: _serverMarkCtrl,
                autoFocus: true,
                hint: 'https://example.com/{DIST}.svg',
                icon: Icons.link,
                maxLines: 1,
                suggestion: false,
                onSubmitted: onSave,
              ),
              ListTile(
                title: Text(libL10n.doc),
                trailing: const Icon(Icons.open_in_new),
                onTap: Urls.customLogoDoc.launchUrl,
              ),
            ],
          ),
          actions: Btn.ok(onTap: () => onSave(_serverMarkCtrl.text)).toList,
        );
      },
    );
  }

  /// The exceptions to `{DIST}` — see [distFileName].
  ///
  /// A key-value editor rather than a picker over `Dist.values`: the keys are
  /// the app's own case names and the values are whatever the collection the
  /// user chose happens to call those files. Only the disagreements are
  /// written down, so the list is normally empty and is a handful at most.
  Widget _buildDistNameMap() {
    return ValBuilder(
      listenable: _setting.distNameMap.listenable(),
      builder: (map) => ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: TipText(l10n.distNameMap, l10n.distNameMapTip),
        subtitle: Text(
          // The count, not the pairs: a subtitle listing them would be a line
          // of `arch=archlinux, rhel=redhat, …` that elides after two.
          map.isEmpty ? libL10n.empty : '${map.length}',
          style: UIs.textGrey,
        ),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () async {
          final result = await KvEditor.route.go(
            context,
            KvEditorArgs(data: Map.of(map)),
          );
          // Null is a back-button, which is not the same as saving an empty
          // map — that is how every override is cleared.
          if (result == null) return;
          _setting.distNameMap.put(result);
        },
      ),
    );
  }

  Widget _buildServerLogoUrl() {
    void onSave(String raw) {
      // Emptying the field clears it. An empty string is not a fetchable URL,
      // so it was refused as invalid — and unset is the state this starts in
      // and shows as [libL10n.empty], which left no way back to it.
      if (raw.trim().isEmpty) {
        _setting.serverLogoUrl.put('');
        context.popDialog();
        return;
      }
      // A GitHub page URL is rewritten to the one that serves the file. It is
      // what the address bar gives you, and left alone it fetches HTML that
      // reaches the decoder as `Invalid image data`.
      final url = resolveLogoUrl(raw);
      if (!isFetchableLogoUrl(url)) {
        _showInvalidUrlDialog();
        return;
      }
      _setting.serverLogoUrl.put(url);
      context.popDialog();
    }

    return ListTile(
      leading: const Icon(Icons.image),
      title: TipText(l10n.logoUrl, l10n.logoUrlTip),
      subtitle: ValBuilder(
        listenable: _setting.serverLogoUrl.listenable(),
        builder: (url) => Text(
          url.isEmpty ? libL10n.empty : url,
          style: UIs.textGrey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        _serverLogoCtrl.text = _setting.serverLogoUrl.fetch();
        context.showRoundDialog(
          title: l10n.logoUrl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Input(
                controller: _serverLogoCtrl,
                autoFocus: true,
                hint: 'https://example.com/logo.png',
                icon: Icons.link,
                // One line, so the text sits in the middle of the field. A URL
                // has nowhere to wrap anyway, and with room for two the single
                // line it holds was drawn against the top with a blank line
                // under it.
                maxLines: 1,
                suggestion: false,
                onSubmitted: onSave,
              ),
              ListTile(
                title: Text(libL10n.doc),
                trailing: const Icon(Icons.open_in_new),
                onTap: Urls.customLogoDoc.launchUrl,
              ),
            ],
          ),
          actions: Btn.ok(onTap: () => onSave(_serverLogoCtrl.text)).toList,
        );
      },
    );
  }

  Widget _buildServerTabPreferDiskAmount() {
    return ListTile(
      title: Text(l10n.preferDiskAmount),
      trailing: StoreSwitch(prop: Stores.setting.serverTabPreferDiskAmount),
    );
  }

  Widget _buildSSHConfigAutoImportToggle() {
    return ListTile(
      title: Text(l10n.sshConfigImport),
      subtitle: Text(l10n.sshConfigImportTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.firstTimeReadSSHCfg),
    );
  }
}
