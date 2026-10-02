part of '../entry.dart';

extension _SFTP on _AppSettingsPageState {
  Widget _buildSFTP() {
    final rows = <Widget>[
        _buildSftpEditor(),
        _buildSftpRmrDir(),
        _buildSftpOpenLastPath(),
        _buildSftpShowFoldersFirst(),
      ];
    if (warmSettingsPhone(context)) {
      return Column(children: [
        WarmSettingsGroup(title: warmSettingsText(context, '文件浏览', 'File browsing'), children: rows.sublist(2)),
        WarmSettingsGroup(title: warmSettingsText(context, '编辑与删除', 'Editing and deletion'), children: rows.sublist(0, 2)),
      ]);
    }
    return Column(children: rows.map((e) => CardX(child: e)).toList());
  }

  Widget _buildSftpOpenLastPath() {
    return ListTile(
      leading: const Icon(MingCute.history_line),
      title: TipText(l10n.openLastPath, l10n.openLastPathTip),
      trailing: StoreSwitch(prop: _setting.sftpOpenLastPath),
    );
  }

  Widget _buildSftpShowFoldersFirst() {
    return ListTile(
      leading: const Icon(MingCute.folder_fill),
      title: Text(l10n.sftpShowFoldersFirst),
      trailing: StoreSwitch(prop: _setting.sftpShowFoldersFirst),
    );
  }

  Widget _buildSftpRmrDir() {
    return ListTile(
      leading: const Icon(MingCute.delete_2_fill),
      title: TipText('rm -r', l10n.sftpRmrDirSummary),
      trailing: StoreSwitch(prop: _setting.sftpRmrDir),
    );
  }

  Widget _buildSftpEditor() {
    return _setting.sftpEditor.listenable().listenVal((val) {
      return ListTile(
        leading: const Icon(MingCute.edit_fill),
        title: TipText(libL10n.editor, l10n.sftpEditorTip),
        trailing: WarmSettingValue(val.isEmpty ? libL10n.inner : val),
        onTap: () => showTextSettingDialog(
          title: libL10n.select,
          initialValue: val,
          label: libL10n.editor,
          hint: '\$EDITOR / vim / nano ...',
          icon: Icons.edit,
          onSave: _setting.sftpEditor.put,
        ),
      );
    });
  }
}
