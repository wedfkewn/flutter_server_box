import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/res/build_data.dart';

/// Platform user-agent helpers for legacy analytics compatibility.
abstract final class DiagnosticsPlatform {
  /// A `User-Agent` for a destination that reads one, or null on a platform
  /// this cannot describe.
  ///
  /// **Why an app sends a browser-shaped string.** OpenPanel derives the
  /// device and the *session* from this header, through `ua-parser-js`, and
  /// treats anything it cannot parse as server-to-server traffic: such an
  /// event is stored but opens no session, so `device_id` and `session_id` are
  /// written empty. Its dashboard counts visitors out of the `sessions` table,
  /// which means a client sending dio's default `Dart/3.x (dart:io)` reports
  /// events and zero users — data that looks like a consent bug and is not
  /// one. The `Mozilla/5.0 (...)` prefix is what the parser needs to find the
  /// platform; the `ServerBox/<build>` suffix is what says this is not a
  /// browser, and both halves are read.
  ///
  /// **The same boundary as the rest of this file**: a token here names the
  /// hardware and the OS release and nothing that identifies a person or an
  /// install. That is narrower than a real browser's UA, which is why the
  /// forms below are shorter than the ones they imitate.
  ///
  /// Every form is verified against `ua-parser-js` rather than assumed, and
  /// two near misses are the reason the fallbacks look the way they do: a bare
  /// `(iPad)` parses to nothing at all and would be read as a server, and
  /// dropping only the digits from the iOS form leaves `os.version` as the
  /// literal string `like`.
  static Future<String?> userAgent() async {
    final platform = await _uaPlatform();
    if (platform == null) return null;
    return 'Mozilla/5.0 ($platform) ${BuildData.name}/${BuildData.build}';
  }

  static Future<String?> _uaPlatform() async {
    try {
      final plugin = DeviceInfoPlugin();
      return switch (Pfs.type) {
        Pfs.android => await _uaAndroid(plugin),
        Pfs.ios => await _uaIos(plugin),
        Pfs.macos => await _uaMacos(plugin),
        // Neither needs a platform call: `device_info_plus` reads
        // `/etc/os-release` on Linux, which describes a distribution the
        // parser mostly does not know, and the Windows form below is what
        // every browser on Windows still sends.
        Pfs.linux => _uaLinux,
        Pfs.windows => _uaWindows,
        _ => null,
      };
    } catch (e, s) {
      Loggers.app.warning('DiagnosticsPlatform.userAgent', e, s);
      return _uaUnversioned;
    }
  }

  static const _uaLinux = 'X11; Linux x86_64';

  /// `NT 10.0` on Windows 11 as well — the kernel version never moved, and a
  /// browser reports it the same way. The real release is in the Sentry
  /// context, which is a different dataset and a different question.
  static const _uaWindows = 'Windows NT 10.0; Win64; x64';

  /// What is left when the platform call fails: enough for the parser to place
  /// the OS, no version, no model.
  static String? get _uaUnversioned => switch (Pfs.type) {
    Pfs.android => 'Linux; Android',
    // Not `iPad`, which parses to nothing. An iPad reaching here is counted as
    // a generic iPhone; the alternative is being counted as a server.
    Pfs.ios => 'iPhone',
    Pfs.macos => 'Macintosh',
    Pfs.linux => _uaLinux,
    Pfs.windows => _uaWindows,
    _ => null,
  };

  /// Strips what would break the header's own structure — a `;` or a `)` in a
  /// vendor's model name would end the token or the whole platform section.
  static String _uaToken(String raw) =>
      raw.replaceAll(RegExp(r'[^\w .+-]'), '').trim();

  static Future<String> _uaAndroid(DeviceInfoPlugin plugin) async {
    final info = await plugin.androidInfo;
    final release = _uaToken(info.version.release);
    if (release.isEmpty) return 'Linux; Android';
    final model = _uaToken(info.model);
    if (model.isEmpty) return 'Linux; Android $release';
    return 'Linux; Android $release; $model';
  }

  static Future<String> _uaIos(DeviceInfoPlugin plugin) async {
    final info = await plugin.iosInfo;
    // `18.5` is written `18_5` here, which is the form the parser reads.
    final version = _uaToken(info.systemVersion).replaceAll('.', '_');
    if (version.isEmpty) return 'iPhone';
    // `model` is the generic family, `iPhone` or `iPad` — not `modelName`,
    // which is the marketing name and belongs in the Sentry context instead.
    return info.model.contains('iPad')
        ? 'iPad; CPU OS $version like Mac OS X'
        : 'iPhone; CPU iPhone OS $version like Mac OS X';
  }

  static Future<String> _uaMacos(DeviceInfoPlugin plugin) async {
    final info = await plugin.macOsInfo;
    // `Intel` on Apple Silicon too: Safari says so, and it is what the parser
    // matches on. The actual architecture is in the Sentry device context.
    return 'Macintosh; Intel Mac OS X '
        '${info.majorVersion}_${info.minorVersion}';
  }
}
