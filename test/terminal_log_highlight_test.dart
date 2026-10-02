import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/terminal_log_highlight.dart';
import 'package:server_box/data/res/terminal.dart';
import 'package:xterm/core.dart';
import 'package:xterm/src/ui/painter.dart';
import 'package:xterm/ui.dart' hide TerminalThemes;

void main() {
  test('classifies severity prefixes and timestamps, not embedded words or commands', () {
    final highlighter = TerminalLogHighlighter();
    for (final text in ['ERROR disk unavailable', '[FATAL] stopped', '2026-10-02T12:00:00Z ERROR: failed', '[12:03:04] [ERROR] failed']) {
      expect(highlighter.classify(text), TerminalLogLevel.error);
    }
    expect(highlighter.classify('WARN retry'), TerminalLogLevel.warning);
    expect(highlighter.classify('[INFO] connected'), TerminalLogLevel.info);
    expect(highlighter.classify('trace checking'), TerminalLogLevel.debug);
    for (final text in ['echo ERROR', 'error_handler()', 'user@host:~\$ grep error', 'ordinary output']) {
      expect(highlighter.classify(text), isNull);
    }
  });

  test('waits for hard newline across packets and skips current input and rewritten progress', () {
    final terminal = Terminal()..resize(80, 24);
    final highlighter = TerminalLogHighlighter();
    terminal.write('ERR'); terminal.write('OR failed');
    expect(highlighter.levelForRow(terminal, 0), isNull);
    terminal.write('\r'); terminal.write('\n');
    expect(highlighter.levelForRow(terminal, 0), TerminalLogLevel.error);
    terminal.write('INFO 10%\rINFO 20%\r\n');
    expect(highlighter.levelForRow(terminal, 1), isNull);
    terminal.write('WARN 30%\r\x1b[KINFO 40%\r\n');
    expect(highlighter.levelForRow(terminal, 2), isNull);
    terminal.write('DEBUG pending');
    expect(highlighter.levelForRow(terminal, 3), isNull);
    terminal.write('\bX\r\n');
    expect(highlighter.levelForRow(terminal, 3), isNull);
  });

  test('wrapped Chinese logs and completion metadata survive resizing without changing copy text', () {
    final terminal = Terminal()..resize(12, 24);
    final highlighter = TerminalLogHighlighter();
    terminal.write('INFO 中文日志与emoji 😀 continued\r\n');
    final before = terminal.buffer.getText();
    expect(highlighter.levelForRow(terminal, 0), TerminalLogLevel.info);
    expect(highlighter.levelForRow(terminal, 1), TerminalLogLevel.info);
    expect(terminal.buffer.getText(), before);
    terminal.resize(40, 24);
    expect(highlighter.levelForRow(terminal, 0), TerminalLogLevel.info);
    expect(terminal.buffer.getText().trimRight(), 'INFO 中文日志与emoji 😀 continued');
    terminal.write('\x1b[?1049hERROR full-screen\r\n');
    expect(highlighter.levelForRow(terminal, 0), isNull);
    terminal.write('\x1b[?1049l');
    expect(highlighter.levelForRow(terminal, 0), TerminalLogLevel.info);
  });

  test('cache stays bounded and overlong UTF-8 rows are not classified', () {
    final highlighter = TerminalLogHighlighter();
    for (var i = 0; i < 1200; i++) { highlighter.classify('INFO message $i'); }
    expect(highlighter.cacheSize, 512);
    expect(highlighter.classify('ERROR ${'中' * 2800}'), isNull);
    expect(highlighter.classify('ERROR ${'x' * 8193}'), isNull);
    expect(highlighter.cacheSize, 512);
  });

  test('painter override preserves ANSI 16/256/RGB, inverse, faint and raw cells', () {
    final terminal = Terminal()..resize(80, 24);
    terminal.write('中\x1b[31m中\x1b[38;5;33m中\x1b[38;2;12;34;56m中\x1b[0m\x1b[7m中\x1b[0m\x1b[2m中');
    final line = terminal.buffer.lines[0];
    final raw = Uint32List.fromList(line.data);
    final text = line.getText();
    final painter = TerminalPainter(theme: TerminalThemes.light,
      textStyle: const TerminalStyle(), textScaler: TextScaler.noScaling);
    final recorder = PictureRecorder();
    final canvas = _ColorCanvas(Canvas(recorder));
    painter.paintLine(canvas, Offset.zero, line, foregroundOverride: const Color(0xff123456));
    expect(canvas.colors.map((c) => c & 0xffffffff), [0xff123456, TerminalThemes.light.red.toARGB32(),
      painter.resolveForegroundColor(CellColor.palette | 33).toARGB32(), 0xff0c2238,
      TerminalThemes.light.background.toARGB32(), 0x80123456]);
    expect(line.data, orderedEquals(raw));
    expect(line.getText(), text);
    recorder.endRecording().dispose();
    painter.dispose();
  });

  test('palette severity colors remain readable in both terminal themes', () {
    for (final theme in [TerminalThemes.light, TerminalThemes.dark]) {
      for (final color in [theme.red, theme.yellow, theme.blue, theme.brightBlack]) {
        final a = color.computeLuminance(), b = theme.background.computeLuminance();
        expect((a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('visible log lookup stays bounded with a large scrollback', () {
    final terminal = Terminal(maxLines: 20000)..resize(120, 40);
    for (var i = 0; i < 10000; i++) { terminal.write('INFO message $i 中文日志\r\n'); }
    final highlighter = TerminalLogHighlighter();
    final timer = Stopwatch()..start();
    for (var frame = 0; frame < 500; frame++) {
      for (var row = terminal.buffer.lines.length - 40; row < terminal.buffer.lines.length; row++) {
        highlighter.colorForRow(terminal, row, TerminalThemes.dark);
      }
    }
    timer.stop();
    // Diagnostic timing only: host CPU/JIT timings are not iPhone frame rates.
    // ignore: avoid_print
    print('500 frames / 40 visible rows / 10000 history rows: ${timer.elapsedMicroseconds / 500} us per frame');
    expect(highlighter.cacheSize, lessThanOrEqualTo(40));
  });
}

class _ColorCanvas implements Canvas {
  _ColorCanvas(this.inner);
  final Canvas inner;
  final colors = <int>[];
  @override
  void drawRawAtlas(Image image, Float32List transforms, Float32List rects, Int32List? colors,
    BlendMode? blendMode, Rect? cullRect, Paint paint) {
    this.colors.addAll(colors!);
    inner.drawRawAtlas(image, transforms, rects, colors, blendMode, cullRect, paint);
  }
  @override
  void drawRect(Rect rect, Paint paint) => inner.drawRect(rect, paint);
  @override
  void drawParagraph(Paragraph paragraph, Offset offset) => inner.drawParagraph(paragraph, offset);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}
