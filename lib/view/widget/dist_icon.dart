import 'dart:async';
import 'package:fl_lib/fl_lib.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/logo_url.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/app_dialog.dart';
import 'package:server_box/view/widget/brand_logo.dart';

/// User-configured distribution image URL; bundled original-color SVGs are
/// used when no valid URL is configured. Existing URL tokens stay compatible.
String? distMarkUrl({required Dist? dist, required bool dark}) {
  final configured = Stores.setting.serverMarkUrl.fetch();
  if (configured.isEmpty) return null;

  var url = resolveLogoUrl(configured);
  if (url.contains(_distToken)) {
    if (dist == null) return null;
    url = url.replaceAll(_distToken, distFileName(dist));
  }
  url = url.replaceAll(_brightToken, dark ? 'dark' : 'light');
  if (!isFetchableLogoUrl(url)) return null;
  return url;
}

/// What `{DIST}` becomes for [dist] — its own case name unless the user has
/// said otherwise.
///
/// The case name is the app's published contract and cannot change. But it
/// only matches the file names of the collection it was written against, and
/// the collection is now the user's choice: font-logos names Arch `archlinux`
/// and RHEL `redhat`, so somebody pointing `{DIST}` at it needs those two
/// renamed and the other sixty-odd left alone.
///
/// No table is shipped for this on purpose. There is no single right one — a
/// mapping correct for one collection is wrong for the next — and a wrong
/// entry would be worse than none, since it silently fetches the wrong logo
/// rather than nothing. `Stores.setting.distNameMap` is where the exceptions
/// go, edited by hand.
String distFileName(Dist dist) =>
    Stores.setting.distNameMap.fetch()[dist.name] ?? dist.name;

const _distToken = '{DIST}';
const _brightToken = '{BRIGHT}';

/// The mark for a server, or **null** when marks are switched off.
///
/// Null rather than an empty widget, and that is the whole point: a
/// zero-sized box still occupies a `leading` slot, and `ListTile` reserves
/// width for one whatever it holds. Off has to mean no pixels, so the decision
/// belongs to the caller — every one of them omits the slot on null.
Widget? distIcon(String serverId, {double size = 20}) =>
    Stores.setting.showDistMark.fetch() ? DistIcon(serverId, size: size) : null;

/// [distIcon] for a caller that already knows the distribution.
Widget? distIconOf(Dist? dist, {double size = 20}) =>
    Stores.setting.showDistMark.fetch() ? DistIconOf(dist, size: size) : null;

/// Live distribution first, persisted identity while a server is offline.
class DistIcon extends ConsumerWidget {
  const DistIcon(this.serverId, {super.key, this.size = 20});

  /// `Spi.id`. An id and not a `Dist`, so a caller holding only the record it
  /// is listing does not have to reach for the status itself.
  final String serverId;

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Stores.setting.showDistMark.fetch()) return const SizedBox.shrink();

    // Read off the map rather than `serverProvider(id)`, which throws for an
    // id it does not know — the known-hosts page lists ids of servers that may
    // since have been deleted.
    final known = ref.watch(serversProvider).servers.containsKey(serverId);
    // The live reading first: it is the newer of the two, and on a server
    // being polled right now it is what the cache is about to be set to.
    final live = known
        ? ref.watch(serverProvider(serverId)).status.dist
        : null;

    // Rebuilt when the cache changes, so a row drawn before the first poll
    // picks up the answer when it lands rather than staying blank until
    // something else happens to rebuild it.
    return StreamBuilder<void>(
      stream: Stores.serverDist.changes,
      builder: (_, _) =>
          DistIconOf(live ?? Stores.serverDist.get(serverId), size: size),
    );
  }
}

/// [DistIcon] for a caller that already knows the distribution.
///
/// Split out so a widget test, and any code path that has the `Dist` in hand,
/// does not need a provider scope with a server in it. Prefer [DistIcon] where
/// there is a server id: it also reads the cache, so a mark is drawn for a
/// server that has been seen before but not yet polled — which is every server
/// for the first few seconds after a restart.
class DistIconOf extends StatelessWidget {
  const DistIconOf(this.dist, {super.key, this.size = 20});

  final Dist? dist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final settings = Stores.setting;
    return ListenableBuilder(listenable: Listenable.merge([
      settings.showDistMark.listenable(), settings.serverMarkUrl.listenable(),
      settings.distNameMap.listenable(),
    ]), builder: (context, _) {
      if (!settings.showDistMark.fetch()) return const SizedBox.shrink();
      return BrandLogo(
        source: distMarkUrl(dist: dist, dark: Theme.of(context).brightness == Brightness.dark) ?? dist?.markAsset,
        size: size,
        label: dist?.name,
        fallback: dist?.isLinux == true ? MingCute.linux_fill : BoxIcons.bxs_server,
      );
    });
  }
}

/// What the marks are and what they are not.
///
/// Legacy notice shared by the custom-image configuration flows.
String distLegalMarkdown(AppLocalizations l10n) => l10n.distIconIntroLegal;

/// The same notice for a plain-text slot.
String distLegalPlain(AppLocalizations l10n) => l10n.distIconIntroLegal;

/// Puts the terms up and answers whether the person accepted them.
///
/// The terms are `assets/distro/README.md` itself, rendered as markdown — the
/// same file that records, per shipped mark, which licence permits shipping it
/// and what the four rejected ones say instead. A paraphrase would be a second
/// thing to keep true; this way there is one.
///
/// Capped in height and scrollable, because it is long. And the accept button
/// waits [_kReadPause] before it can be pressed: the point of putting this up
/// is that somebody looks at it, and a dialog whose only button is already
/// under the thumb is one that gets dismissed without a glance.
Future<bool> confirmDistIconTerms(BuildContext context) async {
  final l10n = context.l10n;
  final agreed = await context.showAppRoundDialog<bool>(
    title: l10n.distIcon,
    childBuilder: (ctx) => ConstrainedBox(
      // Half the window, so the dialog never grows past what it can scroll
      // inside — and on a phone in landscape it is the height that runs out.
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.5),
      child: SingleChildScrollView(child: _DistTerms(l10n: l10n)),
    ),
    actionsBuilder: (_) => [Btn.cancel(), const _DelayedOk()],
  );
  // Dismissing by tapping outside is not agreement.
  return agreed == true;
}

/// How long the accept button stays out of reach.
const _kReadPause = Duration(seconds: 3);

/// The README, or the short notice if it cannot be read.
///
/// It is an asset, so reading it is a future; a `FutureBuilder` rather than
/// loading it before the dialog opens, which would leave a gap between the tap
/// and anything appearing.
class _DistTerms extends StatelessWidget {
  const _DistTerms({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/distro/README.md'),
      builder: (_, snapshot) {
        // The short notice while it loads and if it fails. Never nothing:
        // an empty dialog with a countdown on its button is a puzzle.
        final data = snapshot.data ?? distLegalMarkdown(l10n);
        return SimpleMarkdown(
          data: data,
          styleSheet: MarkdownStyleSheet(
            p: UIs.text13Grey,
            h1: UIs.text15Bold,
            h2: UIs.text13Bold,
            tableBody: UIs.text12Grey,
          ),
        );
      },
    );
  }
}

/// An OK button that cannot be pressed for [_kReadPause], counting down.
///
/// Its own widget so the timer lives with the thing it disables, and so the
/// dialog around it stays a plain `showAppRoundDialog` call.
class _DelayedOk extends StatefulWidget {
  const _DelayedOk();

  @override
  State<_DelayedOk> createState() => _DelayedOkState();
}

class _DelayedOkState extends State<_DelayedOk> {
  Timer? _timer;
  int _left = _kReadPause.inSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _left <= 0;
    return TextButton(
      // Null, not a no-op: a button that looks pressable and does nothing is
      // worse than one that looks unavailable.
      onPressed: ready ? () => Navigator.of(context).pop(true) : null,
      child: Text(ready ? libL10n.ok : '${libL10n.ok} ($_left)'),
    );
  }
}
