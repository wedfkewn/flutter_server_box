import 'package:flutter/material.dart';
import 'package:server_box/core/utils/program_logo.dart';
import 'package:server_box/data/res/brand_assets.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/brand_logo.dart';
import 'package:server_box/view/widget/floating_dialog.dart';

String _text(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

class BrandIconsPage extends StatelessWidget {
  const BrandIconsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Stores.setting;
    return Scaffold(
      appBar: AppBar(title: Text(_text(context, '程序图标', 'Program logos'))),
      body: SafeArea(child: ListenableBuilder(listenable: Listenable.merge([
        settings.showProgramLogos.listenable(), settings.processLogoMap.listenable(), settings.serviceLogoMap.listenable(),
      ]), builder: (context, _) => ListView(padding: const EdgeInsets.all(18), children: [
        AppCard(child: SwitchListTile(
          title: Text(_text(context, '显示程序 Logo', 'Show program logos')),
          subtitle: Text(_text(context, '用于进程和服务列表', 'In process and service lists')),
          value: settings.showProgramLogos.fetch(), onChanged: settings.showProgramLogos.put,
        )),
        const SizedBox(height: 16),
        Text(_text(context, '自定义图标', 'Custom logos'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(_text(context, '规则在所有服务器生效，名称精确匹配。', 'Exact name rules apply to every server.'),
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final service in [false, true]) ...[
          Text(service ? _text(context, '服务', 'Services') : _text(context, '进程', 'Processes')),
          const SizedBox(height: 8),
          AppCard(child: Column(children: [
            for (final rule in (service ? settings.serviceLogoMap.fetch() : settings.processLogoMap.fetch()).entries)
              ListTile(
                leading: BrandLogo(source: rule.value.startsWith('https://') ? rule.value : bundledProgramLogos[rule.value]),
                title: Text(rule.key, overflow: TextOverflow.ellipsis),
                subtitle: Text(rule.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _edit(context, service: service, name: rule.key, value: rule.value),
                trailing: IconButton(tooltip: _text(context, '删除规则', 'Delete rule'),
                  icon: const Icon(Icons.delete_outline), onPressed: () {
                    final property = service ? settings.serviceLogoMap : settings.processLogoMap;
                    property.put({...property.fetch()}..remove(rule.key));
                  }),
              ),
            ListTile(leading: const Icon(Icons.add), title: Text(_text(context, '添加规则', 'Add rule')),
              onTap: () => _edit(context, service: service)),
          ])),
          const SizedBox(height: 16),
        ],
        Text(_text(context, '内置图标可离线使用；图片链接首次加载需要联网。',
          'Bundled logos work offline; custom image links need a connection on first load.'),
          style: Theme.of(context).textTheme.bodySmall),
      ]))),
    );
  }

  Future<void> _edit(BuildContext context, {required bool service, String? name, String? value}) async {
    final nameController = TextEditingController(text: name);
    final urlController = TextEditingController(text: value?.startsWith('https://') == true ? value : '');
    var remote = value?.startsWith('https://') == true;
    var selected = bundledProgramLogos.containsKey(value) ? value! : 'python';
    var previewUrl = urlController.text;
    final form = GlobalKey<FormState>();
    final route = DialogRoute<(String, String)>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) => AppFloatingDialog(
        insetPadding: const EdgeInsets.all(16),
        title: Text(_text(context, '自定义图标', 'Custom logo')),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Form(key: form, child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(controller: nameController, decoration: InputDecoration(labelText:
              service ? _text(context, '服务名称', 'Service name') : _text(context, '程序名称', 'Executable name')),
              validator: (raw) => programLogoKey(raw ?? '', service: service).isEmpty ? _text(context, '请输入名称', 'Enter a name') : null),
            const SizedBox(height: 16),
            SegmentedButton<bool>(segments: [
              ButtonSegment(value: false, label: Text(_text(context, '内置', 'Bundled'))),
              ButtonSegment(value: true, label: Text(_text(context, '图片链接', 'Image URL'))),
            ], selected: {remote}, onSelectionChanged: (v) => update(() => remote = v.single)),
            const SizedBox(height: 16),
            if (remote) TextFormField(controller: urlController,
              decoration: InputDecoration(labelText: 'HTTPS URL', suffixIcon: IconButton(
                tooltip: _text(context, '预览', 'Preview'), icon: const Icon(Icons.refresh),
                onPressed: () {
                  BrandLogo.refreshSource(urlController.text.trim());
                  update(() => previewUrl = urlController.text.trim());
                })), keyboardType: TextInputType.url,
              validator: (v) {
                final uri = Uri.tryParse(v?.trim() ?? '');
                return uri?.scheme == 'https' && uri!.host.isNotEmpty ? null : _text(context, '请输入有效 HTTPS 图片链接', 'Enter a valid HTTPS image URL');
              })
            else DropdownButtonFormField<String>(initialValue: selected, isExpanded: true,
              items: [for (final key in bundledProgramLogos.keys) DropdownMenuItem(value: key,
                child: Row(children: [BrandLogo(source: bundledProgramLogos[key]), const SizedBox(width: 8), Text(key)]))],
              onChanged: (v) => update(() => selected = v!)),
            const SizedBox(height: 16),
            Center(child: BrandLogo(source: remote ? previewUrl : bundledProgramLogos[selected], size: 48)),
          ],
        )))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_text(context, '取消', 'Cancel'))),
          FilledButton(onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(dialogContext,
                (programLogoKey(nameController.text, service: service), remote ? urlController.text.trim() : selected));
            }
          }, child: Text(_text(context, '保存', 'Save'))),
        ],
      ),
    ));
    final result = await Navigator.of(context).push(route);
    if (result != null) {
      final property = service ? Stores.setting.serviceLogoMap : Stores.setting.processLogoMap;
      final rules = {...property.fetch()};
      if (name != null) rules.remove(name);
      rules[result.$1] = result.$2;
      property.put(rules);
    }
    // Dialog route exit still owns its text fields for a frame.
    await route.completed;
    nameController.dispose();
    urlController.dispose();
  }
}
