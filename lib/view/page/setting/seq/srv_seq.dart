import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/view/page/setting/seq/reorder_proxy_decorator.dart';
import 'package:server_box/view/widget/dist_icon.dart';
import 'package:server_box/view/widget/warm_settings.dart';

class ServerOrderPage extends ConsumerStatefulWidget {
    /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  const ServerOrderPage({super.key, this.embedded = false});

  @override
  ConsumerState<ServerOrderPage> createState() => _ServerOrderPageState();

  static const route = AppRouteNoArg(
    page: ServerOrderPage.new,
    path: '/settings/order/server',
  );
}

class _ServerOrderPageState extends ConsumerState<ServerOrderPage> {
  late List<String> _order;

  @override
  void initState() {
    super.initState();
    _order = List<String>.from(ref.read(serversProvider).serverOrder);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ServersState>(serversProvider, (_, next) {
      if (listEquals(_order, next.serverOrder)) {
        return;
      }
      setState(() {
        _order = List<String>.from(next.serverOrder);
      });
    });

    // Not the bottom: the list takes that as padding of its own, so it can
    // be scrolled through rather than cutting the page short of it.
    final body = WarmSettingsSurface(child: SafeArea(bottom: false, child: _buildBody(context)));
    if (widget.embedded) return body;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.serverOrder)),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    final serverState = ref.watch(serversProvider);
    final order = _order;

    if (order.isEmpty) {
      return Center(child: Text(libL10n.empty));
    }
    return ReorderableListView.builder(
      footer: const SizedBox(height: 77),
      header: WarmSettingsIntro(icon: Icons.dns_outlined,
        text: warmSettingsText(context, '拖动右侧手柄调整首页的服务器顺序。修改后自动保存。',
          'Drag the handle to reorder servers on the homepage. Changes save automatically.')),
      onReorderItem: (oldIndex, newIndex) async {
        final targetIndex = newIndex;
        if (targetIndex == oldIndex) {
          return;
        }

        final newOrder = List<String>.from(order);
        final moved = newOrder.removeAt(oldIndex);
        newOrder.insert(targetIndex, moved);

        setState(() {
          _order = newOrder;
        });
        await ref.read(serversProvider.notifier).updateServerOrder(newOrder);
      },
      padding: context.padBottom(const EdgeInsets.fromLTRB(18, 12, 18, 24)),
      buildDefaultDragHandles: false,
      itemBuilder: (_, idx) {
        final id = order[idx];
        final spi = serverState.servers[id];
        return _buildItem(idx, id, spi);
      },
      itemCount: order.length,
      proxyDecorator: reorderProxyDecorator,
    );
  }

  Widget _buildItem(int index, String id, Spi? spi) {
    return Padding(
      key: ValueKey('server_item_$id'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18), clipBehavior: Clip.antiAlias,
          child: _buildCardTile(index, spi)),
    );
  }

  Widget _buildCardTile(int index, Spi? spi) {
    if (spi == null) {
      return const SizedBox();
    }

    return ListTile(
      title: Text(
        spi.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(spi.oldId, style: UIs.textGrey),
      // The distribution rather than the name's first letter, which said
      // nothing a row already showing the name did not.
      leading: distIcon(spi.id, size: 22),
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
    );
  }
}
