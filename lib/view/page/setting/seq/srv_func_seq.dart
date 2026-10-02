import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/warm_settings.dart';

class ServerFuncBtnsOrderPage extends StatefulWidget {
    /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  const ServerFuncBtnsOrderPage({super.key, this.embedded = false});

  @override
  State<ServerFuncBtnsOrderPage> createState() => _ServerDetailOrderPageState();

  static const route = AppRouteNoArg(
    page: ServerFuncBtnsOrderPage.new,
    path: '/setting/seq/srv_func',
  );
}

class _ServerDetailOrderPageState extends State<ServerFuncBtnsOrderPage> {
  final prop = Stores.setting.serverFuncBtns;

  @override
  Widget build(BuildContext context) {
    final body = WarmSettingsSurface(child: _buildBody(context));
    if (widget.embedded) return body;
    return Scaffold(
      appBar: CustomAppBar(title: Text(libL10n.sequence)),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    return ValBuilder(
      listenable: prop.listenable(),
      builder: (keys) {
        final disabled = ServerFuncBtn.values
            .map((e) => e.index)
            .where((e) => !keys.contains(e))
            .toList();
        final allKeys = [...keys, ...disabled];
        return ReorderableListView.builder(
          key: const PageStorageKey('srv_func_seq'),
          padding: context.padBottom(const EdgeInsets.fromLTRB(18, 12, 18, 24)),
          header: WarmSettingsIntro(icon: Icons.tune,
            text: warmSettingsText(context, '勾选常用功能，拖动右侧手柄调整已启用按钮的顺序。修改后自动保存。',
              'Choose your tools and drag enabled buttons to reorder them. Changes save automatically.')),
          buildDefaultDragHandles: false,
          itemCount: allKeys.length,
          itemBuilder: (_, idx) => _buildListItem(allKeys[idx], idx, keys),
          onReorderItem: (o, n) {
            if (o >= keys.length || n >= keys.length) {
              Toast.show(libL10n.disabled);
              return;
            }
            if (o == n) {
              return;
            }
            final moved = keys.removeAt(o);
            keys.insert(n, moved);
            prop.set(keys);
          },
        );
      },
    );
  }

  Widget _buildListItem(int key, int idx, List<int> keys) {
    final funcBtn = ServerFuncBtn.values[key];
    final enabled = idx < keys.length;
    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18), clipBehavior: Clip.antiAlias, child: ListTile(
        title: Row(children: [Icon(funcBtn.icon, size: 22), const SizedBox(width: 12),
          Expanded(child: Text(funcBtn.toStr, style: TextStyle(fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: enabled ? 1 : .55))))]),
        leading: _buildCheckBox(keys, key, idx, idx < keys.length),
        trailing: enabled ? ReorderableDragStartListener(index: idx,
          child: const SizedBox(width: 40, height: 44, child: Icon(Icons.drag_handle))) : null,
      )),
    );
  }

  Widget _buildCheckBox(List<int> keys, int key, int idx, bool value) {
    return Checkbox(
      value: value,
      onChanged: (val) {
        if (val == null) return;
        if (val) {
          if (idx >= keys.length) {
            keys.add(key);
          } else {
            keys.insert(idx - 1, key);
          }
        } else {
          keys.remove(key);
        }
        prop.put(keys);
      },
    );
  }
}
