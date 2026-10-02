import 'dart:convert';
import 'package:flutter/painting.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart';

enum TerminalLogLevel { error, warning, info, debug }

/// Classifies visible, completed logical lines without changing terminal data.
class TerminalLogHighlighter {
  final Map<String, TerminalLogLevel?> _cache = <String, TerminalLogLevel?>{};
  int get cacheSize => _cache.length;
  static final _prefix = RegExp(
    r'^\s*(?:(?:\[?\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?\]?|\[?\d{2}:\d{2}:\d{2}(?:[.,]\d+)?\]?)\s+)?(?:\[(ERROR|FATAL|WARN|WARNING|INFO|DEBUG|TRACE)\]|(ERROR|FATAL|WARN|WARNING|INFO|DEBUG|TRACE)(?=\s|:|$))',
    caseSensitive: false);

  TerminalLogLevel? classify(String text) {
    if (text.length > 8192) return null;
    if (_cache.containsKey(text)) {
      final level = _cache.remove(text);
      _cache[text] = level;
      return level;
    }
    if (utf8.encode(text).length > 8192) return null;
    final match = _prefix.firstMatch(text);
    final token = (match?.group(1) ?? match?.group(2))?.toUpperCase();
    final level = switch (token) {
      'ERROR' || 'FATAL' => TerminalLogLevel.error,
      'WARN' || 'WARNING' => TerminalLogLevel.warning,
      'INFO' => TerminalLogLevel.info,
      'DEBUG' || 'TRACE' => TerminalLogLevel.debug,
      _ => null,
    };
    _cache[text] = level;
    if (_cache.length > 512) _cache.remove(_cache.keys.first);
    return level;
  }

  TerminalLogLevel? levelForRow(Terminal terminal, int row) {
    if (terminal.isUsingAltBuffer) return null;
    final lines = terminal.buffer.lines;
    if (row < 0 || row >= lines.length) return null;
    var start = row, end = row;
    var budget = 0;
    while (start > 0 && lines[start].isWrapped) {
      budget += lines[start].length;
      if (budget > 8192) return null;
      start--;
    }
    while (end + 1 < lines.length && lines[end + 1].isWrapped) {
      budget += lines[end].length;
      if (budget > 8192) return null;
      end++;
    }
    if (!lines[end].hasHardBreak ||
        (terminal.buffer.absoluteCursorY >= start && terminal.buffer.absoluteCursorY <= end)) {
      return null;
    }
    final text = StringBuffer();
    for (var i = start; i <= end; i++) {
      if (lines[i].wasRewritten || lines[i].length > 8192) return null;
      text.write(lines[i].getText(null, null, i == end));
      if (text.length > 8192) return null;
    }
    return classify(text.toString());
  }

  Color? colorForRow(Terminal terminal, int row, TerminalTheme theme) =>
    switch (levelForRow(terminal, row)) {
      TerminalLogLevel.error => theme.red,
      TerminalLogLevel.warning => theme.yellow,
      TerminalLogLevel.info => theme.blue,
      TerminalLogLevel.debug => theme.brightBlack,
      null => null,
    };
}
