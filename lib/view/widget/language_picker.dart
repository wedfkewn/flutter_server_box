import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/app_ui.dart';

/// Keeps the settings page underneath the floating language selector.
Future<Locale?> showLanguagePicker(BuildContext context, {Locale? initial}) {
  return showDialog<Locale>(
    context: context,
    builder: (_) => AppUiScope(child: LanguagePicker(initial: initial ?? context.locale)),
  );
}

String languageDisplayName(Locale locale) {
  if (locale.languageCode == 'zh') {
    return locale.countryCode == 'TW' ? '中文（繁體）' : '中文（简体）';
  }
  return locale.nativeName.replaceFirst(' (${locale.code})', '');
}

const _searchAliases = <String, String>{
  'az': '阿塞拜疆语 Azerbaijani', 'de': '德语 German',
  'en': '英语 English', 'es': '西班牙语 Spanish',
  'fr': '法语 French', 'id': '印度尼西亚语 Indonesian',
  'it': '意大利语 Italian', 'ja': '日语 Japanese',
  'ko': '韩语 Korean', 'nl': '荷兰语 Dutch',
  'pt': '葡萄牙语 Portuguese', 'ru': '俄语 Russian',
  'tr': '土耳其语 Turkish', 'uk': '乌克兰语 Ukrainian',
  'zh': '简体中文 Simplified Chinese',
  'zh_TW': '繁体中文 Traditional Chinese',
};

class LanguagePicker extends StatefulWidget {
  const LanguagePicker({super.key, required this.initial});
  final Locale initial;

  @override
  State<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<LanguagePicker> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late Locale _selected;
  late final List<Locale> _locales;

  @override
  void initState() {
    super.initState();
    final supported = AppLocalizations.supportedLocales;
    _selected = supported.firstWhere((l) => l.code == widget.initial.code,
      orElse: () => supported.firstWhere((l) => l.languageCode == widget.initial.languageCode,
        orElse: () => const Locale('en')));
    // Freeze order while selecting, so rows never jump under the finger.
    _locales = [...supported]..sort((a, b) {
      int rank(Locale l) => l == _selected ? 0 : switch (l.code) {
        'zh' => 1, 'zh_TW' => 2, 'en' => 3, 'ja' => 4, 'ko' => 5, 'de' => 6, _ => 7,
      };
      final order = rank(a).compareTo(rank(b));
      return order == 0 ? a.code.compareTo(b.code) : order;
    });
    _search.addListener(_onSearch);
  }

  void _onSearch() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final media = MediaQuery.of(context);
    final height = math.max(0.0, math.min(520.0,
      media.size.height - media.viewInsets.vertical - media.padding.vertical - 48));
    final query = _search.text.trim().toLowerCase();
    final matches = _locales.where((l) =>
      '${languageDisplayName(l)} ${l.code} ${_searchAliases[l.code] ?? ''}'
        .toLowerCase().contains(query)).toList();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 360),
      backgroundColor: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(key: const ValueKey('language-picker'), height: height, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(children: [
          Row(children: [
            Icon(Icons.translate, color: colors.primary, size: 23),
            const SizedBox(width: 10),
            Expanded(child: Text(libL10n.language, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
            IconButton(key: const ValueKey('language-close'),
              tooltip: libL10n.close, onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 22)),
          ]),
          const SizedBox(height: 8),
          FTextField(
            key: const ValueKey('language-search'),
            control: FTextFieldControl.managed(controller: _search),
            style: FTextFieldStyleDelta.delta(
              color: FVariantsValueDelta.delta([FVariantValueDeltaOperation.all(colors.surfaceContainerHigh)]),
              border: FVariantsValueDelta.delta([FVariantValueDeltaOperation.base(
                FTheme.of(context).textFieldStyles.md.border.base.copyWith(borderSide: BorderSide.none))]),
            ),
            hint: context.locale.languageCode == 'zh' ? '搜索语言' : libL10n.search,
            autocorrect: false, enableSuggestions: false,
            textInputAction: TextInputAction.search,
            onSubmit: (_) => FocusScope.of(context).unfocus(),
            prefixBuilder: (_, _, _) => Padding(padding: const EdgeInsets.only(left: 12),
              child: Icon(Icons.search, size: 20, color: colors.onSurfaceVariant)),
            suffixBuilder: (_, _, _) => query.isEmpty ? const SizedBox.shrink() :
              IconButton(tooltip: libL10n.clear, onPressed: _search.clear,
                icon: const Icon(Icons.close, size: 18)),
          ),
          if (height >= 330) Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [Expanded(child: Text(
              '${context.locale.languageCode == 'zh' ? '当前' : libL10n.language}：${languageDisplayName(_selected)}',
              key: const ValueKey('language-current'),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              maxLines: 2, overflow: TextOverflow.ellipsis))]),
          ) else const SizedBox(height: 8),
          Expanded(child: matches.isEmpty ? Center(child: Text(libL10n.empty)) :
            Scrollbar(controller: _scroll, child: ListView.separated(
              controller: _scroll, padding: EdgeInsets.zero,
              itemCount: matches.length,
              separatorBuilder: (_, index) => Divider(height: 1,
                indent: 12, endIndent: 12, color: colors.outlineVariant.withValues(alpha: .35)),
              itemBuilder: (_, index) {
                final locale = matches[index];
                final selected = locale == _selected;
                return Semantics(selected: selected, button: true, child: Material(
                  color: selected ? colors.primary.withValues(alpha: .09) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12), clipBehavior: Clip.antiAlias,
                  child: InkWell(key: ValueKey('language-${locale.code}'),
                    onTap: () => setState(() => _selected = locale),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Row(children: [
                        Expanded(child: Text(languageDisplayName(locale),
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500))),
                        const SizedBox(width: 8),
                        Text(locale.code, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                        SizedBox(width: 28, child: selected ? Icon(Icons.check, color: colors.primary, size: 20) : null),
                      ])),
                  ),
                ));
              },
            ))),
          Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .4)),
          Align(alignment: Alignment.centerRight, child: TextButton(
            key: const ValueKey('language-done'),
            onPressed: () => Navigator.of(context).pop(_selected),
            child: Text(libL10n.done, style: const TextStyle(fontWeight: FontWeight.w600)),
          )),
        ]),
      )),
    );
  }
}
