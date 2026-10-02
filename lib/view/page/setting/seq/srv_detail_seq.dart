import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/setting/seq/reorder_proxy_decorator.dart';
import 'package:server_box/view/widget/warm_settings.dart';

class ServerDetailOrderPage extends StatefulWidget {
    /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  const ServerDetailOrderPage({super.key, this.embedded = false});

  @override
  State<ServerDetailOrderPage> createState() => _ServerDetailOrderPageState();

  static const route = AppRouteNoArg(
    page: ServerDetailOrderPage.new,
    path: '/settings/order/server_detail',
  );
}

class _ServerDetailOrderPageState extends State<ServerDetailOrderPage> {
  final prop = Stores.setting.detailCardOrder;
  final disabledProp = Stores.setting.detailCardDisabled;

  late List<String> _order;
  late Set<String> _enabled;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final keys = prop.fetch();
    final disabled = disabledProp.fetch();
    _order = List<String>.from(keys);
    for (final d in disabled) {
      if (!_order.contains(d)) {
        _order.add(d);
      }
    }
    _enabled = Set<String>.from(keys.where((k) => !disabled.contains(k)));
  }

  @override
  Widget build(BuildContext context) {
    // Not the bottom: the list takes that as padding of its own, so it can
    // be scrolled through rather than cutting the page short of it.
    final body = WarmSettingsSurface(child: SafeArea(bottom: false, child: _buildBody(context)));
    if (widget.embedded) return body;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.serverDetailOrder)),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    return ReorderableListView.builder(
      key: const PageStorageKey('srv_detail_seq'),
      padding: context.padBottom(const EdgeInsets.fromLTRB(18, 12, 18, 24)),
      header: WarmSettingsIntro(icon: Icons.dashboard_customize_outlined,
        text: warmSettingsText(context, '拖动右侧手柄调整卡片顺序，勾选决定是否显示。修改后自动保存。',
          'Drag the handle to reorder cards and tick to show them. Changes save automatically.')),
      buildDefaultDragHandles: false,
      itemCount: _order.length,
      proxyDecorator: reorderProxyDecorator,
      itemBuilder: (_, idx) => _buildListItem(_order[idx], idx),
      onReorderItem: _handleReorder,
    );
  }

  Widget _buildListItem(String key, int idx) {
    final isEnabled = _enabled.contains(key);
    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.only(bottom: 8), child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18), clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 23, right: 11),
          leading: Icon(ServerDetailCards.fromName(key)?.icon),
          title: Text(
            switch (key) {
              'mem' => warmSettingsText(context, '内存', 'Memory'),
              'swap' => warmSettingsText(context, '交换空间', 'Swap'),
              'gpu' => 'GPU',
              _ => ServerDetailCards.fromName(key)?.toStr ?? key,
            },
            style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme
              .onSurface.withValues(alpha: isEnabled ? 1 : .55)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCheckBox(key, isEnabled),
              ReorderableDragStartListener(
                index: idx,
                child: const SizedBox(width: 40, height: 44, child: Icon(Icons.drag_handle)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckBox(String key, bool isEnabled) {
    return Checkbox(value: isEnabled, onChanged: (_) => _toggleEnabled(key));
  }

  void _handleReorder(int oldIndex, int newIndex) {
    final targetIndex = newIndex;
    if (targetIndex == oldIndex) {
      return;
    }

    setState(() {
      final item = _order.removeAt(oldIndex);
      _order.insert(targetIndex, item);
    });
    _saveChanges();
  }

  void _toggleEnabled(String key) {
    setState(() {
      if (_enabled.contains(key)) {
        _enabled.remove(key);
      } else {
        _enabled.add(key);
      }
    });
    _saveChanges();
  }

  void _saveChanges() {
    prop.put(_order);
    final disabledList = _order.where((k) => !_enabled.contains(k)).toList();
    disabledProp.put(disabledList);
  }
}
