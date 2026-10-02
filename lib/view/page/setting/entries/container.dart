part of '../entry.dart';

extension _Container on _AppSettingsPageState {
  Widget _buildContainer() {
    final rows = <Widget>[
        _buildUsePodman(),
        _buildContainerTrySudo(),
        _buildContainerParseStat(),
      ];
    if (warmSettingsPhone(context)) {
      return Column(children: [
        WarmSettingsGroup(title: warmSettingsText(context, '容器运行', 'Container runtime'), children: rows.sublist(0, 2)),
        WarmSettingsGroup(title: warmSettingsText(context, '资源监控', 'Resource monitoring'), children: rows.sublist(2)),
      ]);
    }
    return Column(children: rows.map((e) => CardX(child: e)).toList());
  }

  Widget _buildUsePodman() {
    return ListTile(
      leading: const Icon(IonIcons.logo_docker),
      title: Text(l10n.usePodmanByDefault),
      trailing: StoreSwitch(prop: _setting.usePodman),
    );
  }

  Widget _buildContainerTrySudo() {
    return ListTile(
      leading: const Icon(EvaIcons.person_done),
      title: TipText(l10n.trySudo, l10n.containerTrySudoTip),
      trailing: StoreSwitch(prop: _setting.containerTrySudo),
    );
  }

  Widget _buildContainerParseStat() {
    return ListTile(
      leading: const Icon(MingCute.chart_line_line, size: _kIconSize),
      title: TipText(libL10n.stat, l10n.parseContainerStatsTip),
      trailing: StoreSwitch(prop: _setting.containerParseStat),
    );
  }
}
