part of '../entry.dart';

extension _App on _AppSettingsPageState {
  Widget _buildApp() {
    final specific = _buildPlatformSetting();
    final children = [
      _buildLocale(),
      _buildThemeMode(),
      _buildIpinfoToken(),
      ?specific,
    ];

    return Column(children: children.map((e) => e.cardx).toList());
  }

  Widget _buildIpinfoToken() {
    return _setting.ipinfoToken.listenable().listenVal((val) {
      final hasToken = val.isNotEmpty;
      return ListTile(
        leading: const Icon(Icons.location_on),
        title: Text(context.l10n.ipinfoToken),
        subtitle: Text(hasToken ? '••••••••' : libL10n.empty, style: UIs.textGrey),
        onTap: () => _showIpinfoTokenDialog(),
      );
    });
  }

  Future<void> _showIpinfoTokenDialog() async {
    return withTextFieldController((ctrl) async {
      final fetched = _setting.ipinfoToken.fetch();
      if (fetched != null && fetched.isNotEmpty) ctrl.text = fetched;

      void onSave() {
        _setting.ipinfoToken.put(ctrl.text.trim());
        context.pop();
      }

      await context.showRoundDialog(
        title: context.l10n.ipinfoToken,
        child: Input(
          controller: ctrl,
          autoFocus: true,
          label: context.l10n.ipinfoToken,
          hint: 'Enter your ipinfo.io token',
          icon: MingCute.key_2_line,
          obscureText: false,
          suggestion: true,
          onSubmitted: (_) => onSave(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _setting.ipinfoToken.delete();
              context.pop();
            },
            child: Text(libL10n.clear),
          ),
          TextButton(onPressed: onSave, child: Text(libL10n.ok)),
        ],
      );
    });
  }

  Widget? _buildPlatformSetting() {
    return null;
  }

  Widget _buildUpdateInterval() {
    return ListTile(
      title: Text(l10n.updateServerStatusInterval),
      onTap: () async {
        final val = await context.showPickSingleDialog(
          title: libL10n.setting,
          items: List.generate(10, (idx) => idx == 1 ? null : idx),
          initial: _setting.serverStatusUpdateInterval.fetch(),
          display: (p0) => p0 == 0 ? libL10n.manual : '$p0 ${l10n.second}',
        );
        if (val != null) {
          _setting.serverStatusUpdateInterval.put(val);
        }
      },
      trailing: ValBuilder(
        listenable: _setting.serverStatusUpdateInterval.listenable(),
        builder: (val) => Text('$val ${l10n.second}', style: UIs.text15),
      ),
    );
  }


  Widget _buildMaxRetry() {
    return ValBuilder(
      listenable: _setting.maxRetryCount.listenable(),
      builder: (val) => ListTile(
        title: Text(l10n.maxRetryCount),
        onTap: () async {
          final selected = await context.showPickSingleDialog(
            title: l10n.maxRetryCount,
            items: List.generate(10, (index) => index),
            display: (p0) => '$p0 ${l10n.times}',
            initial: val,
          );
          if (selected != null) {
            _setting.maxRetryCount.put(selected);
          }
        },
        trailing: Text('$val ${l10n.times}', style: UIs.text15),
      ),
    );
  }

  Widget _buildThemeMode() {
    // Issue #57
    final len = ThemeMode.values.length;
    return ListTile(
      leading: const Icon(MingCute.moon_stars_fill),
      title: Text(libL10n.themeMode),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: libL10n.themeMode,
          items: List.generate(len + 2, (index) => index),
          display: (p0) => _buildThemeModeStr(p0),
          initial: _setting.themeMode.fetch(),
        );
        if (selected != null) {
          _setting.themeMode.put(selected);
          RNodes.app.notify();
        }
      },
      trailing: ValBuilder(
        listenable: _setting.themeMode.listenable(),
        builder: (val) => Text(_buildThemeModeStr(val), style: UIs.text15),
      ),
    );
  }

  String _buildThemeModeStr(int n) {
    switch (n) {
      case 1:
        return libL10n.bright;
      case 2:
        return libL10n.dark;
      case 3:
        return 'AMOLED';
      case 4:
        return '${libL10n.auto} AMOLED';
      default:
        return libL10n.auto;
    }
  }

  Widget _buildLocale() {
    return ListTile(
      leading: const Icon(IonIcons.language),
      title: Text(libL10n.language),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: libL10n.language,
          items: AppLocalizations.supportedLocales,
          display: (p0) => p0.nativeName,
          initial: _setting.locale.fetch().toLocale,
        );
        if (selected != null) {
          _setting.locale.put(selected.code);
          context.pop();
          RNodes.app.notify();
        }
      },
      trailing: ListenBuilder(
        listenable: _setting.locale.listenable(),
        builder: () => Text(context.localeNativeName, style: UIs.text15),
      ),
    );
  }


}
