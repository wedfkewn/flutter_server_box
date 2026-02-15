part of '../entry.dart';

extension _App on _AppSettingsPageState {
  Widget _buildApp() {
    final specific = _buildPlatformSetting();
    final children = [
      _buildLocale(),
      _buildThemeMode(),
      ?specific,
    ];

    return Column(children: children.map((e) => e.cardx).toList());
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
