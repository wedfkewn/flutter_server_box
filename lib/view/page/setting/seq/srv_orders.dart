import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/setting/seq/srv_detail_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_func_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_seq.dart';
import 'package:server_box/view/widget/warm_settings.dart';

/// The three orderings a server has, on one page.
///
/// They were three rows in the settings menu, and a row is not enough to tell
/// them apart: "server order", "detail page widget order" and "sequence" all
/// read as the same thing until you have opened one and seen what is in it.
/// As tabs they are named next to each other, which is the only place the
/// difference is visible.
///
/// The three pages are unchanged and still routable on their own — the server
/// settings page links straight to the last of them, where the tabs would be
/// three choices in answer to a question the user did not ask.
class ServerOrdersPage extends StatelessWidget {
  /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice. The tabs are needed either way,
  /// so they move out of the bar and sit above the content instead.
  final bool embedded;

  const ServerOrdersPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final phone = warmSettingsPhone(context);
    final scheme = Theme.of(context).colorScheme;
    final tabs = TabBar(
      isScrollable: phone,
      tabAlignment: phone ? TabAlignment.start : TabAlignment.fill,
      dividerColor: phone ? Colors.transparent : null,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: phone ? BoxDecoration(color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14)) : null,
      labelColor: phone ? scheme.onPrimaryContainer : null,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      tabs: [
        Tab(text: phone ? warmSettingsText(context, '服务器', 'Servers') : l10n.serverOrder),
        Tab(text: phone ? warmSettingsText(context, '详情卡片', 'Detail cards') : l10n.serverDetailOrder),
        Tab(text: phone ? warmSettingsText(context, '功能按钮', 'Tools') : l10n.serverFuncBtns),
      ],
    );

    const views = TabBarView(
      children: [
        ServerOrderPage(embedded: true),
        ServerDetailOrderPage(embedded: true),
        ServerFuncBtnsOrderPage(embedded: true),
      ],
    );

    return DefaultTabController(
      length: 3,
      child: embedded
          ? Column(children: [Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: tabs), const Expanded(child: views)])
          : Scaffold(
              appBar: CustomAppBar(
                title: Text(libL10n.sequence),
                bottom: tabs,
              ),
              body: views,
            ),
    );
  }

  static const route = AppRouteNoArg(
    page: ServerOrdersPage.new,
    path: '/settings/order',
  );
}
