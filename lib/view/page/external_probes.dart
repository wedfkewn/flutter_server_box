import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/service/external_probe_controller.dart';
import 'package:server_box/data/model/app/external_probe.dart';
import 'package:server_box/data/provider/external_probe.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/widget/floating_dialog.dart';
import 'package:server_box/view/widget/probe_labels.dart';

class ExternalProbesPage extends ConsumerStatefulWidget {
  const ExternalProbesPage({super.key, required this.serverId});
  final String serverId;
  static Future<void> show(BuildContext context, String serverId) => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => ExternalProbesPage(serverId: serverId)));
  @override
  ConsumerState<ExternalProbesPage> createState() => _ExternalProbesPageState();
}

class _ExternalProbesPageState extends ConsumerState<ExternalProbesPage> {
  ProbeCategory? _category;
  String _query = '';
  bool _manage = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  String _t(String zh, String en) => probeText(context, zh, en);

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(externalProbeProvider(widget.serverId));
    final server = ref.watch(serverProvider(widget.serverId));
    return ListenableBuilder(listenable: controller, builder: (context, _) {
      final config = controller.config;
      final visible = [...config.enabled,
        ...config.targets.where((target) => !config.selected.contains(target.id))].where((target) =>
        (_category == null || (_category == ProbeCategory.custom ? target.isCustom : target.category == _category)) &&
        '${target.name} ${target.address}'.toLowerCase().contains(_query.toLowerCase())).toList();
      final cooldown = controller.retryAfter(config.selected);
      return Scaffold(
        appBar: AppBar(title: Column(children: [
          Text(_t('外网服务检测', 'External service checks')),
          Text(server.spi.name, style: Theme.of(context).textTheme.bodySmall),
        ]), centerTitle: true, actions: [
          IconButton(tooltip: _t('管理检测项目', 'Manage checks'),
            onPressed: controller.running ? null : () => setState(() => _manage = !_manage),
            icon: Icon(_manage ? Icons.done : Icons.tune)),
        ]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Column(children: [
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.public, size: 20), const SizedBox(width: 8),
                  Expanded(child: Text(_t('从所选服务器发起检测', 'Checks originate on the selected server'),
                    style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text('${config.selected.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Text(_t('当前为网站／端口连通性检测；不代表账号可用或流媒体完整解锁。',
                  'Checks website/port connectivity; account access and streaming availability are unverified.'),
                  style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(_t('已检测 ${controller.results.length} 项 · ${controller.results.values.where((e) => e.state == ProbeState.reachable).length} 项正常',
                  '${controller.results.length} checked · ${controller.results.values.where((e) => e.state == ProbeState.reachable).length} responded'),
                  style: Theme.of(context).textTheme.bodySmall),
                if (controller.running) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: controller.total == 0 ? null : controller.completed / controller.total),
                  const SizedBox(height: 6),
                  Text('${controller.completed}/${controller.total} · ${controller.cancelled ? _t('正在停止', 'Stopping') : _t('检测中', 'Checking')}'),
                ],
              ]))),
            if (_manage) SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(_t('连接后自动检测', 'Check automatically when connected')),
              subtitle: Text(_t('仅检测所选项目，优先使用有效缓存', 'Selected checks only; fresh cached results are reused')),
              value: config.autoCheck, onChanged: (value) => _save(controller, ProbeConfig(
                selected: config.selected, pinned: config.pinned, custom: config.custom, autoCheck: value))),
            if (_manage) Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text(_t('勾选自定义检测后会自动显示在首页小卡片；内置服务可置顶最多四项。',
                'Selected custom checks appear on the homepage; pin up to four built-in services.'),
                style: Theme.of(context).textTheme.bodySmall)),
            TextField(onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
                hintText: _t('搜索服务或地址', 'Search services or addresses'), isDense: true)),
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              ChoiceChip(label: Text(_t('全部', 'All')), selected: _category == null,
                onSelected: (_) => setState(() => _category = null)),
              for (final category in ProbeCategory.values) Padding(padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(label: Text(probeCategoryLabel(context, category)), selected: _category == category,
                  onSelected: (_) => setState(() => _category = category))),
            ])),
            if (controller.error != null) Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(_t('请等待冷却时间结束后重试', 'Wait for the retry cooldown'),
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ])),
          Expanded(child: visible.isEmpty
            ? Center(child: Text(_t('没有匹配项目，请调整搜索或分类', 'No matching checks; change the search or category')))
            : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: visible.length, itemBuilder: (context, index) => _row(controller, visible[index]))),
        ]),
        bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _manage ? FilledButton.icon(onPressed: () => _edit(controller), icon: const Icon(Icons.add),
            label: Text(_t('添加自定义检测', 'Add custom check')))
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!controller.running) TextButton.icon(onPressed: () => _edit(controller),
              icon: const Icon(Icons.add, size: 18), label: Text(_t('添加自定义检测', 'Add custom check'))),
            if (!controller.running && controller.results.values.any((e) => e.state != ProbeState.reachable))
              TextButton.icon(onPressed: () {
                final failed = controller.config.enabled.where((target) =>
                  controller.results[target.id] != null &&
                  controller.results[target.id]!.state != ProbeState.reachable &&
                  controller.retryAfter({target.id}) == 0).map((e) => e.id).toSet();
                if (failed.isEmpty) { _message(_t('请等待冷却时间结束后重试', 'Wait for the retry cooldown')); }
                else { controller.run(ids: failed); }
              }, icon: const Icon(Icons.refresh, size: 18), label: Text(_t('仅重试异常项目', 'Retry unsuccessful checks'))),
            FilledButton.icon(
            onPressed: controller.running
              ? (controller.cancelled ? null : controller.cancel)
              : (config.selected.isEmpty || cooldown > 0 ? null : () => controller.run()),
            icon: Icon(controller.running ? Icons.stop : Icons.play_arrow),
            label: Text(controller.running
              ? _t('停止检测', 'Stop checks')
              : cooldown > 0 ? _t('$cooldown 秒后可重新检测', 'Retry in ${cooldown}s')
                : _t('检测所选服务', 'Check selected services'))),
          ]))),
      );
    });
  }

  Widget _row(ExternalProbeController controller, ProbeTarget target) {
    final config = controller.config;
    final result = controller.results[target.id];
    final checking = controller.checking.contains(target.id);
    final selected = config.selected.contains(target.id);
    final stale = result != null && !result.isFresh(DateTime.now());
    final color = probeColor(context, result);
    return Card(margin: const EdgeInsets.only(bottom: 8), child: _manage
      ? ListTile(leading: Checkbox(value: selected, onChanged: (value) {
          final next = {...config.selected};
          if (value == true) { next.add(target.id); } else { next.remove(target.id); }
          _save(controller, ProbeConfig(selected: next,
            pinned: config.pinned.where(next.contains).toList(), custom: config.custom, autoCheck: config.autoCheck));
        }), title: Text(target.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(target.address, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!target.isCustom) IconButton(tooltip: _t('首页置顶（最多四项）', 'Pin to homepage (up to four)'),
            onPressed: !selected ? null : () {
              final pinned = [...config.pinned];
              if (pinned.contains(target.id)) { pinned.remove(target.id); }
              else if (pinned.length < 4) { pinned.add(target.id); }
              else { _message(_t('首页最多置顶四项', 'Pin up to four checks')); return; }
              _save(controller, ProbeConfig(selected: config.selected, pinned: pinned,
                custom: config.custom, autoCheck: config.autoCheck));
            }, icon: Icon(config.pinned.contains(target.id) ? Icons.push_pin : Icons.push_pin_outlined)),
          if (target.isCustom) PopupMenuButton<String>(onSelected: (action) {
            if (action == 'edit') { _edit(controller, target); } else { _delete(controller, target); }
          }, itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(_t('编辑', 'Edit'))),
            PopupMenuItem(value: 'delete', child: Text(_t('删除', 'Delete'))),
          ]),
        ]))
      : ExpansionTile(key: ValueKey('probe-${target.id}'),
        leading: Checkbox(value: selected, onChanged: (value) {
          final next = {...config.selected};
          if (value == true) { next.add(target.id); } else { next.remove(target.id); }
          _save(controller, ProbeConfig(selected: next,
            pinned: config.pinned.where(next.contains).toList(), custom: config.custom,
            autoCheck: config.autoCheck));
        }),
        trailing: target.isCustom ? Row(mainAxisSize: MainAxisSize.min, children: [
          PopupMenuButton<String>(onSelected: (action) {
            if (action == 'edit') { _edit(controller, target); } else { _delete(controller, target); }
          }, itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(_t('编辑', 'Edit'))),
            PopupMenuItem(value: 'delete', child: Text(_t('删除', 'Delete'))),
          ]),
          const Icon(Icons.expand_more),
        ]) : null,
        title: Text(target.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(checking ? _t('正在更新，上次结果保留', 'Updating; previous result retained')
          : '${probeStateLabel(context, result, tcp: target.protocol == ProbeProtocol.tcp)}${stale ? ' · ${_t('结果过期', 'Expired')}' : ''}',
          style: TextStyle(color: color)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(target.address, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          if (result != null) ...[
            Text(probeReasonLabel(context, result.reason)),
            if (result.httpStatus != null) Text('HTTP ${result.httpStatus}'),
            if (result.elapsedMs != null) Text('${_t('请求耗时', 'Request duration')}: ${result.elapsedMs} ms'),
            if (result.remoteIp != null) Text('${_t('目标 IP', 'Destination IP')}: ${result.remoteIp}'),
            Text('${result.transport ?? '—'} · ${result.checkedAt.toLocal().toString().split('.').first}'),
          ],
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: !selected || controller.running || controller.retryAfter({target.id}) > 0
              ? null : () => controller.run(ids: {target.id}),
            icon: const Icon(Icons.refresh, size: 18), label: Text(_t('单项重试', 'Retry check')))),
        ]));
  }

  void _save(ExternalProbeController controller, ProbeConfig config) {
    if (!controller.updateConfig(config)) _message(_t('保存失败，请重试', 'Could not save; try again'));
  }
  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _edit(ExternalProbeController controller, [ProbeTarget? target]) async {
    final result = await showDialog<ProbeTarget>(context: context,
      builder: (_) => _ProbeTargetDialog(target: target));
    if (!mounted || result == null) return;
    final config = controller.config;
    _save(controller, ProbeConfig(selected: {...config.selected, result.id},
      pinned: config.pinned, autoCheck: config.autoCheck,
      custom: [...config.custom.where((e) => e.id != result.id), result]));
  }

  Future<void> _delete(ExternalProbeController controller, ProbeTarget target) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AppFloatingDialog(
      title: Text(_t('删除 ${target.name}？', 'Delete ${target.name}?')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('取消', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('删除', 'Delete')))]));
    if (!mounted || confirmed != true) return;
    final config = controller.config;
    _save(controller, ProbeConfig(selected: {...config.selected}..remove(target.id),
      pinned: config.pinned.where((e) => e != target.id).toList(), autoCheck: config.autoCheck,
      custom: config.custom.where((e) => e.id != target.id).toList()));
  }
}

class _ProbeTargetDialog extends StatefulWidget {
  const _ProbeTargetDialog({this.target});
  final ProbeTarget? target;
  @override
  State<_ProbeTargetDialog> createState() => _ProbeTargetDialogState();
}

class _ProbeTargetDialogState extends State<_ProbeTargetDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.target?.name);
  late final _address = TextEditingController(text: widget.target?.address);
  late final _keyword = TextEditingController(text: widget.target?.keyword);
  late final _min = TextEditingController(text: '${widget.target?.statusMin ?? 200}');
  late final _max = TextEditingController(text: '${widget.target?.statusMax ?? 399}');
  late ProbeProtocol _protocol = widget.target?.protocol ?? ProbeProtocol.http;
  late ProbeCategory _category = widget.target?.category ?? ProbeCategory.custom;
  late String _method = widget.target?.method ?? 'GET';
  late int _timeout = widget.target?.timeoutSeconds ?? 8;
  late bool _redirect = widget.target?.followRedirects ?? true;
  String? _error;
  String _t(String zh, String en) => probeText(context, zh, en);
  @override
  void dispose() { for (final c in [_name, _address, _keyword, _min, _max]) { c.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) => AppFloatingDialog(
    title: Text(_t(widget.target == null ? '添加自定义检测' : '编辑自定义检测',
      widget.target == null ? 'Add custom check' : 'Edit custom check')),
    content: SizedBox(width: 440, child: SingleChildScrollView(child: Form(key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _name, maxLength: 80,
          decoration: InputDecoration(labelText: _t('名称', 'Name')),
          validator: (value) => value?.trim().isEmpty != false ? _t('请输入名称', 'Enter a name') : null),
        DropdownButtonFormField<ProbeCategory>(initialValue: _category,
          decoration: InputDecoration(labelText: _t('分类', 'Category')),
          items: [for (final category in ProbeCategory.values)
            DropdownMenuItem(value: category, child: Text(probeCategoryLabel(context, category)))],
          onChanged: (value) => setState(() => _category = value!)),
        DropdownButtonFormField<ProbeProtocol>(initialValue: _protocol,
          decoration: InputDecoration(labelText: _t('检测类型', 'Check type')),
          items: [DropdownMenuItem(value: ProbeProtocol.http, child: Text(_t('HTTP／HTTPS 网站', 'HTTP / HTTPS website'))),
            DropdownMenuItem(value: ProbeProtocol.tcp, child: Text(_t('TCP 端口', 'TCP port')))],
          onChanged: (value) => setState(() => _protocol = value!)),
        const SizedBox(height: 10),
        TextFormField(controller: _address, keyboardType: TextInputType.url,
          autocorrect: false, maxLength: 2048,
          decoration: InputDecoration(labelText: _t('检测地址', 'Address'),
            hintText: _protocol == ProbeProtocol.http ? 'https://example.com/health' : 'tcp://example.com:443'),
          validator: (value) => value?.trim().isEmpty != false ? _t('请输入地址', 'Enter an address') : null),
        DropdownButtonFormField<int>(initialValue: _timeout,
          decoration: InputDecoration(labelText: _t('超时时间', 'Timeout')),
          items: [for (final n in ({2, 5, 8, 15, _timeout}.toList()..sort()))
              DropdownMenuItem(value: n, child: Text(_t('$n 秒', '${n}s')))],
          onChanged: (value) => setState(() => _timeout = value!)),
        if (_protocol == ProbeProtocol.http) ...[
          DropdownButtonFormField<String>(initialValue: _method,
            decoration: InputDecoration(labelText: _t('请求方法', 'Request method')),
            items: [for (final method in ['GET', 'HEAD']) DropdownMenuItem(value: method, child: Text(method))],
            onChanged: (value) => setState(() { _method = value!; if (_method == 'HEAD') _keyword.clear(); })),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: TextFormField(controller: _min, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: _t('最小状态码', 'Minimum status')))), const SizedBox(width: 10),
            Expanded(child: TextFormField(controller: _max, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _t('最大状态码', 'Maximum status'))))]),
          TextFormField(controller: _keyword, enabled: _method != 'HEAD', maxLength: 200,
            decoration: InputDecoration(labelText: _t('响应关键词（可选）', 'Response keyword (optional)'),
              helperText: _t('区分大小写；最多读取 64 KB 响应', 'Case sensitive; reads up to 64 KB'))),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(_t('跟随重定向', 'Follow redirects')),
            value: _redirect, onChanged: (value) => setState(() => _redirect = value)),
        ],
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('取消', 'Cancel'))),
      FilledButton(onPressed: _submit, child: Text(_t('保存', 'Save')))]);

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final target = ProbeTarget(id: widget.target?.id ?? 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(), address: _address.text.trim(), category: _category,
      protocol: _protocol, method: _protocol == ProbeProtocol.http ? _method : 'GET',
      keyword: _protocol == ProbeProtocol.http ? _keyword.text : '', timeoutSeconds: _timeout,
      followRedirects: _redirect, statusMin: int.tryParse(_min.text) ?? -1,
      statusMax: int.tryParse(_max.text) ?? -1);
    if (target.validationError != null) {
      setState(() => _error = _t('请检查地址、端口、状态码范围和关键词。',
        'Check the address, port, status range and keyword.')); return;
    }
    Navigator.pop(context, target);
  }
}
