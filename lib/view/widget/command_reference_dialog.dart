import 'dart:math' as math;
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart' as f;
import 'package:server_box/data/model/app/command_reference.dart';
import 'package:server_box/data/res/command_reference.dart';
import 'package:server_box/view/widget/app_ui.dart';

String commandUiText(BuildContext context, String zh, String en) =>
  Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

Future<void> showCommandReference(BuildContext context, {bool guide = false}) =>
  showDialog<void>(context: context, builder: (_) => AppUiScope(
    child: CommandReferenceDialog(guide: guide)));

class CommandReferenceDialog extends StatefulWidget {
  const CommandReferenceDialog({super.key, this.guide = false});
  final bool guide;
  @override
  State<CommandReferenceDialog> createState() => _CommandReferenceDialogState();
}

class _CommandReferenceDialogState extends State<CommandReferenceDialog> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  CommandCategory? _category;
  CommandReference? _selected;
  bool get _chinese => Localizations.localeOf(context).languageCode == 'zh';
  String t(String zh, String en) => commandUiText(context, zh, en);
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = math.max(0.0, media.size.height - media.viewInsets.vertical - media.padding.vertical - 48);
    final title = widget.guide ? t('命令高亮配置指南', 'Command highlighting guide') :
      _selected?.name ?? t('命令速查', 'Command reference');
    return PopScope(canPop: _selected == null, onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _selected != null) setState(() => _selected = null);
    }, child: Dialog(
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(key: const ValueKey('command-reference-surface'),
        height: math.min(available * .85, 720), child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 4), child: Row(children: [
          if (_selected != null) IconButton(key: const ValueKey('command-reference-back'),
            tooltip: t('返回列表', 'Back to list'), icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selected = null))
          else const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.menu_book_outlined)),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
          IconButton(key: const ValueKey('command-reference-close'), tooltip: libL10n.close,
            onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
        ])),
        const Divider(height: 1),
        Expanded(child: widget.guide ? _guide() : _selected == null ? _list() : _detail(_selected!)),
      ])),
    ));
  }

  Widget _list() {
    final results = commandReferences.where((doc) => (_category == null || _category == doc.category) &&
      doc.matches(_search.text)).toList();
    return ListView.builder(key: const PageStorageKey('command-reference-list'), controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), itemCount: 3 + math.max(1, results.length),
      itemBuilder: (context, index) {
        if (index == 0) { return f.FTextField(key: const ValueKey('command-reference-search'),
          control: f.FTextFieldControl.managed(controller: _search, onChange: (_) => setState(() {})),
          hint: t('搜索命令或用途', 'Search commands or purposes'),
          autocorrect: false, enableSuggestions: false, textInputAction: TextInputAction.search,
          onSubmit: (_) => FocusScope.of(context).unfocus(),
          prefixBuilder: (_, _, _) => const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.search, size: 20)),
          suffixBuilder: (_, _, _) => _search.text.isEmpty ? const SizedBox.shrink() : IconButton(
            tooltip: libL10n.clear, onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close, size: 18))); }
        if (index == 1) { return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Wrap(
          spacing: 6, runSpacing: 6, children: [
            ChoiceChip(label: Text(libL10n.all), labelStyle: Theme.of(context).textTheme.bodyMedium,
              selected: _category == null,
              onSelected: (_) => setState(() => _category = null)),
            for (final category in CommandCategory.values) ChoiceChip(label: Text(category.label.localized(_chinese)),
              labelStyle: Theme.of(context).textTheme.bodyMedium,
              selected: _category == category, onSelected: (_) => setState(() => _category = category)),
          ])); }
        if (index == 2) { return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(
          t('${results.length} 个条目 · 离线可用', '${results.length} entries · Available offline'),
          style: Theme.of(context).textTheme.bodySmall)); }
        if (results.isEmpty) { return Padding(padding: const EdgeInsets.all(24), child: Text(
          t('没有匹配的命令，试试名称或用途。', 'No matching commands. Try a name or purpose.'))); }
        final doc = results[index - 3];
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: AppCard(
          child: ListTile(key: ValueKey('command-${doc.name}'),
            title: Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(doc.summary.localized(_chinese)), trailing: const Icon(Icons.chevron_right),
            onTap: () { FocusScope.of(context).unfocus(); setState(() => _selected = doc); })));
      });
  }

  Widget _heading(String zh, String en) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(t(zh, en), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)));

  Widget _detail(CommandReference doc) => ListView(key: ValueKey('command-detail-${doc.name}'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      Text(doc.summary.localized(_chinese), style: Theme.of(context).textTheme.titleMedium),
      _heading('适用条件', 'Requirements'), Text(doc.requirements.localized(_chinese)),
      _heading('语法', 'Syntax'), SelectableText(doc.syntax, style: const TextStyle(fontFamily: 'monospace')),
      _heading('常用参数', 'Common options'),
      for (final option in doc.options) Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(option.flag, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          Text(option.description.localized(_chinese)),
        ])),
      _heading('示例', 'Examples'),
      for (final example in doc.examples) Padding(padding: const EdgeInsets.only(bottom: 12), child:
        CommandExampleBlock(example: example)),
      TextButton.icon(onPressed: () => doc.source.launchUrl(), icon: const Icon(Icons.open_in_new, size: 18),
        label: Text(t('官方文档（需要网络）', 'Official documentation (online)'))),
    ]);

  Widget _guide() => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
    Text(t('输入时逐词高亮由服务器 Shell 提供。以下命令仅供复制，请在目标服务器上手动执行。',
      'Live command highlighting is provided by the server shell. Copy these commands and run them manually on the target server.')),
    _heading('Fish · 内置高亮', 'Fish · Built-in highlighting'),
    Text(t('先检查 Fish 是否安装。已安装时运行 fish 进入临时会话，输入 exit 返回原来的 Shell；不修改默认 Shell。未安装时按发行版官方说明安装。',
      'Check whether Fish is installed. Run fish for a temporary session and exit to return; the default shell stays unchanged. If absent, follow your distribution’s official installation instructions.')),
    const CommandExampleBlock(example: CommandExample('command -v fish', ('检查 Fish', 'Check Fish'))),
    const CommandExampleBlock(example: CommandExample('fish', ('进入已安装的 Fish', 'Enter an installed Fish shell'))),
    TextButton(onPressed: () => 'https://fishshell.com/docs/current/interactive.html'.launchUrl(),
      child: Text(t('Fish 官方说明', 'Official Fish documentation'))),
    _heading('Zsh · 语法高亮插件', 'Zsh · Syntax highlighting plugin'),
    Text(t('需要 Zsh 与 Git。检查后，在插件目录尚不存在时复制克隆命令。进入 Zsh 后加载插件；若要持久启用，请手动把 source 行放在 .zshrc 的最后，按照官方安装说明操作。',
      'Requires Zsh and Git. Check them first; clone only if the plugin directory does not exist. Source the plugin inside Zsh. For persistence, manually add the source line at the end of .zshrc following the official installation instructions.')),
    const CommandExampleBlock(example: CommandExample('command -v zsh; command -v git', ('检查 Zsh 与 Git', 'Check Zsh and Git'))),
    const CommandExampleBlock(example: CommandExample(r'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.local/share/zsh-syntax-highlighting"',
      ('下载插件；需要网络', 'Download the plugin; requires network access'))),
    const CommandExampleBlock(example: CommandExample('zsh', ('进入已安装的 Zsh', 'Enter an installed Zsh shell'))),
    const CommandExampleBlock(example: CommandExample(r'source "$HOME/.local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"',
      ('仅在当前 Zsh 会话加载', 'Load in the current Zsh session only'))),
    TextButton(onPressed: () => 'https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md'.launchUrl(),
      child: Text(t('Zsh 插件官方安装说明', 'Official Zsh plugin installation guide'))),
    _heading('Bash', 'Bash'),
    Text(t('App 配色不能为 Bash 提供完整的逐词输入高亮。可以继续使用 Bash 的原有提示符和程序彩色输出，或手动进入已安装的 Fish / Zsh。',
      'App colors cannot provide complete live syntax highlighting for Bash. Keep its existing prompt and program colors, or manually enter an installed Fish / Zsh shell.')),
  ]);
}

class CommandExampleBlock extends StatefulWidget {
  const CommandExampleBlock({super.key, required this.example});
  final CommandExample example;
  @override
  State<CommandExampleBlock> createState() => _CommandExampleBlockState();
}

class _CommandExampleBlockState extends State<CommandExampleBlock> {
  bool _copied = false;
  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: AppCard(child: Padding(
      padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.example.description.localized(chinese)), const SizedBox(height: 10),
        SelectableText(widget.example.code, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: AppButton(secondary: true,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.example.code));
            if (mounted) setState(() => _copied = true);
          }, child: Text(commandUiText(context, _copied ? '已复制' : '复制', _copied ? 'Copied' : 'Copy')))),
      ]))));
  }
}
