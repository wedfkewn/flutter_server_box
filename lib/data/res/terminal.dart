import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/res/store.dart';
import 'package:xterm/ui.dart';

abstract final class TerminalThemes {
  static const dark = TerminalTheme(
    background: Color(0xff101418),
    foreground: Color(0xffdce1e8),
    cursor: Color(0xffcbd5e1),
    selection: Color(0xff334b72),
    selectionCursor: Color(0xff8fb5ff),
    black: Color(0xff101418),
    red: Color(0xffff8d8d),
    green: Color(0xff7ecd9a),
    yellow: Color(0xffe5b567),
    blue: Color(0xff8fb5ff),
    magenta: Color(0xffc4a1f0),
    cyan: Color(0xff76ced9),
    white: Color(0xffdce1e8),
    brightBlack: Color(0xffa0aab8),
    brightRed: Color(0xffffa6a6),
    brightGreen: Color(0xff94ddaf),
    brightYellow: Color(0xfff2cf8a),
    brightBlue: Color(0xffb2ccff),
    brightMagenta: Color(0xffdac1ff),
    brightCyan: Color(0xffa4e7ee),
    brightWhite: Color(0xffffffff),
    searchHitBackground: Color(0xfff8d775),
    searchHitBackgroundCurrent: Color(0xffa8ddb5),
    searchHitForeground: Color(0xff17202e),
  );
  static const light = TerminalTheme(
    background: Color(0xfff5f6f8),
    foreground: Color(0xff1b2433),
    cursor: Color(0xff475569),
    selection: Color(0xffdbe7ff),
    selectionCursor: Color(0xff1d4ed8),
    black: Color(0xff1b2433),
    red: Color(0xffb42318),
    green: Color(0xff167344),
    yellow: Color(0xff8a5800),
    blue: Color(0xff1d4ed8),
    magenta: Color(0xff7e3fb5),
    cyan: Color(0xff0e6878),
    white: Color(0xff475569),
    brightBlack: Color(0xff667085),
    brightRed: Color(0xffba3027),
    brightGreen: Color(0xff177245),
    brightYellow: Color(0xff865700),
    brightBlue: Color(0xff2756bd),
    brightMagenta: Color(0xff854cb1),
    brightCyan: Color(0xff156e7e),
    brightWhite: Color(0xff546174),
    searchHitBackground: Color(0xfff8d775),
    searchHitBackgroundCurrent: Color(0xffa8ddb5),
    searchHitForeground: Color(0xff17202e),
  );
}

extension TerminalThemeX on TerminalTheme {
  TerminalTheme copyWith({
    Color? cursor,
    Color? selectionCursor,
    Color? selection,
    Color? foreground,
    Color? background,
    Color? searchHitBackground,
    Color? searchHitBackgroundCurrent,
    Color? searchHitForeground,
    Color? red,
    Color? green,
    Color? yellow,
    Color? blue,
    Color? magenta,
    Color? cyan,
    Color? white,
    Color? brightBlack,
    Color? brightRed,
    Color? brightGreen,
    Color? brightYellow,
    Color? brightBlue,
    Color? brightMagenta,
    Color? brightCyan,
    Color? brightWhite,
    Color? black,
  }) {
    return TerminalTheme(
      cursor: cursor ?? this.cursor,
      selectionCursor: selectionCursor ?? this.selectionCursor,
      selection: selection ?? this.selection,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      searchHitBackground: searchHitBackground ?? this.searchHitBackground,
      searchHitBackgroundCurrent:
          searchHitBackgroundCurrent ?? this.searchHitBackgroundCurrent,
      searchHitForeground: searchHitForeground ?? this.searchHitForeground,
      red: red ?? this.red,
      green: green ?? this.green,
      yellow: yellow ?? this.yellow,
      blue: blue ?? this.blue,
      magenta: magenta ?? this.magenta,
      cyan: cyan ?? this.cyan,
      white: white ?? this.white,
      brightBlack: brightBlack ?? this.brightBlack,
      brightRed: brightRed ?? this.brightRed,
      brightGreen: brightGreen ?? this.brightGreen,
      brightYellow: brightYellow ?? this.brightYellow,
      brightBlue: brightBlue ?? this.brightBlue,
      brightMagenta: brightMagenta ?? this.brightMagenta,
      brightCyan: brightCyan ?? this.brightCyan,
      brightWhite: brightWhite ?? this.brightWhite,
      black: black ?? this.black,
    );
  }
}

/// How a terminal is configured to look, wherever one is shown.
///
/// Shared rather than read where it is needed, so the terminal in a dialog and
/// the terminal in a tab cannot end up on different fonts or a different theme.
abstract final class TerminalLook {
  static TerminalStyle get style {
    final family = Stores.setting.fontPath.fetch().getFileName();
    final size = Stores.setting.termFontSize.fetch();
    return TerminalStyle.fromTextStyle(
      TextStyle(fontFamily: family, fontSize: size),
    );
  }

  /// The terminal's own theme setting, falling back to the app's and then to
  /// what the system asked for.
  static bool isDark(BuildContext context) => switch (Stores
      .setting
      .termTheme
      .fetch()) {
    1 => false,
    2 => true,
    _ => switch (Stores.setting.themeMode.fetch()) {
      1 => false,
      2 || 3 => true,
      _ => context.isDark,
    },
  };

  static TerminalTheme themeOf(BuildContext context) {
    final theme = isDark(context) ? TerminalThemes.dark : TerminalThemes.light;
    return theme.copyWith(selectionCursor: UIs.primaryColor);
  }
}
