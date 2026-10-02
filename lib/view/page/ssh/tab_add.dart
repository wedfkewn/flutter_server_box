part of 'tab.dart';

/// The first tab: pick a server to open a shell on.
///
/// Sorting is recomputed on every build rather than cached. The previous cache
/// rebuilt a name map on each build purely to decide whether it was still
/// valid, so it did the linear work regardless and saved only the sort — for a
/// list of servers, that is nothing worth the three fields of state it took to
/// arrange.
class _AddPage extends ConsumerStatefulWidget {
  const _AddPage({
    this.compact = false,
    this.prefix = const [],
    required this.sortVersion,
    required this.search,
    required this.onTap,
    required this.onLocal,
    required this.onLongPress,
  });

  /// Bumped when the sort changes. The order lives in the settings store, not
  /// in a provider, so nothing else would tell this page to rebuild.
  final bool compact;
  final List<Widget> prefix;
  final Listenable sortVersion;

  /// The bar's search. Read rather than listened to: [sortVersion] carries it.
  final InlineSearchController search;

  final void Function(Spi spi) onTap;

  /// Opens a shell on the machine the app is running on.
  final VoidCallback onLocal;


  final void Function(Spi spi) onLongPress;

  @override
  ConsumerState<_AddPage> createState() => _AddPageState();
}

class _AddPageState extends ConsumerState<_AddPage> {
  @override
  void initState() {
    super.initState();
    widget.sortVersion.addListener(_onSortChanged);
  }

  @override
  void dispose() {
    widget.sortVersion.removeListener(_onSortChanged);
    super.dispose();
  }

  void _onSortChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serversProvider);
    var order = _SortOrder.stored.apply(state.serverOrder, state.servers);

    // What is typed in the bar, applied to the servers here. The systems on
    // this device are left alone: they are two rows with fixed names, and a
    // search is for finding one server among many.
    final needle = widget.search.needle;
    if (needle.isNotEmpty) {
      order = [
        for (final id in order)
          if (state.servers[id] case final spi?)
            if (spi.name.toLowerCase().contains(needle) ||
                spi.displayAddr.toLowerCase().contains(needle))
              id,
      ];
    }

    // Not "empty" while this device is on the list: with no servers
    // configured, a shell here is still something this page can open.
    final empty =
        order.isEmpty &&
        (needle.isNotEmpty ||
            !LocalShellBackend.isSupported);
    if (empty && !widget.compact) {
      return EmptyPane(
        icon: needle.isEmpty ? Icons.dns_outlined : Icons.search_off,
        label: needle.isEmpty ? null : needle,
      );
    }

    // Sections rather than one flow of cards. The systems on this device and
    // the servers are two kinds of thing, and a masonry grid says only "here
    // are some cards" — which is why the systems used to be pinned above it in
    // a card of their own, collapsed behind a title that named them in a
    // subtitle. One row each, under a heading, says the same thing without a
    // control to open first.
    // One column at every width. The sections used to be laid side by side
    // above 600pt, which is a width this tab has already decided is too narrow
    // for a rail — so between 600 and 800 the picker answered with two columns
    // of cards on a screen that was not getting a second column anywhere else.
    return ListView(
      padding: widget.compact
          ? const EdgeInsets.fromLTRB(14, 0, 14, 12)
          : context.padBottom(UIs.roundRectCardPadding),
      children: [
        ...widget.prefix,
        if (empty && widget.compact) ...[
          _WarmConnectionSection(l10n.warmTerminalNewConnection),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(libL10n.empty),
          ),
        ],
        // First, and for the same reason the file tab lists it first: it is
        // always reachable, and it needs no credential to be.
        //
        // Both this and the systems below are dropped while a search is on:
        // they are rows with fixed names, and leaving them under a query that
        // does not match them makes them read as results.
        if (!widget.compact &&
            LocalShellBackend.isSupported &&
            needle.isEmpty) ...[
          CenterGreyTitle(libL10n.device),
          CardTile(
            icon: Icons.smartphone,
            title: libL10n.device,
            subtitle: LocalShellBackend.shellPath,
            onTap: widget.onLocal,
          ),
        ],
        if (order.isNotEmpty) ...[
          if (widget.compact)
            _WarmConnectionSection(l10n.warmTerminalNewConnection)
          else
            CenterGreyTitle(libL10n.servers),
          for (final id in order)
            if (state.servers[id] case final spi?)
              if (widget.compact)
                _WarmConnectionRow(
                  key: ValueKey('terminal-connect-$id'),
                  connection: true,
                  title: spi.name,
                  subtitle: spi.displayAddr,
                  onTap: () => widget.onTap(spi),
                  onLongPress: () => widget.onLongPress(spi),
                )
              else
                _ServerTile(
                  key: ValueKey(id),
                  spi: spi,
                  onTap: () => widget.onTap(spi),
                  onLongPress: () => widget.onLongPress(spi),
                ),
        ],
        if (widget.compact &&
            LocalShellBackend.isSupported &&
            needle.isEmpty) ...[
          _WarmConnectionSection(libL10n.device),
          _WarmConnectionRow(
            title: libL10n.device,
            subtitle: LocalShellBackend.shellPath,
            onTap: widget.onLocal,
            connection: true,
          ),
        ],
      ],
    );
  }
}

/// The same two things as [_AddPage], in a column too narrow for cards: the
/// shells that are running, and the servers one could be started on.
///
/// Not a variant of [_AddPage] with a `compact` flag. A grid of cards is for
/// browsing and picking; a rail is for switching while something else has your
/// attention, and it carries the running sessions that the picker has no
/// business knowing about.
class _SideBar extends ConsumerStatefulWidget {
  const _SideBar({
    required this.sessions,
    required this.sortVersion,
    required this.search,
    required this.actions,
    required this.onOpen,
    required this.onLocal,
    required this.onEdit,
    required this.onSelect,
    required this.onClose,
  });

  final SessionTabsController<_SshSession> sessions;

  /// Bumped when the sort changes. The order lives in the settings store, not
  /// in a provider, so nothing else would tell this rail to rebuild.
  final Listenable sortVersion;

  /// The bar's search. Read rather than listened to: [sortVersion] carries it.
  final InlineSearchController search;

  final List<Widget> actions;
  final void Function(Spi spi) onOpen;

  /// Opens a shell on the machine the app is running on.
  final VoidCallback onLocal;

  final void Function(Spi spi) onEdit;
  final void Function(int index) onSelect;
  final void Function(int index) onClose;

  @override
  ConsumerState<_SideBar> createState() => _SideBarState();
}

class _SideBarState extends ConsumerState<_SideBar> {
  @override
  void initState() {
    super.initState();
    widget.sortVersion.addListener(_onSortChanged);
  }

  @override
  void dispose() {
    widget.sortVersion.removeListener(_onSortChanged);
    super.dispose();
  }

  void _onSortChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serversProvider);
    var order = _SortOrder.stored.apply(state.serverOrder, state.servers);

    // The same narrowing the picker does, on the same query — see `_AddPage`.
    final needle = widget.search.needle;
    if (needle.isNotEmpty) {
      order = [
        for (final id in order)
          if (state.servers[id] case final spi?)
            if (spi.name.toLowerCase().contains(needle) ||
                spi.displayAddr.toLowerCase().contains(needle))
              id,
      ];
    }

    return ListenBuilder(
      listenable: widget.sessions,
      builder: () => SessionSideBar(
        names: widget.sessions.names,
        index: widget.sessions.index,
        onTap: widget.onSelect,
        onClose: widget.onClose,
        actions: widget.actions,
        search: widget.search,
        targets: [
          // Above the servers, the way the file rail puts this device above
          // them: it is the one place that is always reachable, and it needs
          // no credential to be.
          if (LocalShellBackend.isSupported && needle.isEmpty) ...[
            SideBarSection(libL10n.device),
            SideBarTile(title: libL10n.device, onTap: widget.onLocal),
          ],
          SideBarSection(libL10n.servers),
          for (final id in order)
            if (state.servers[id] case final spi?)
              SideBarTile(
                key: ValueKey(id),
                title: spi.name,
                leading: distIcon(spi.id, size: 17),
                // Always a new shell, never a jump to one that is already
                // open: the section above is where switching happens, and a
                // second shell on one server is an ordinary thing to want.
                onTap: () => widget.onOpen(spi),
                onLongPress: () => widget.onEdit(spi),
              ),
        ],
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    super.key,
    required this.spi,
    required this.onTap,
    required this.onLongPress,
  });

  final Spi spi;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return CardX(
      child: ListTile(
        leading: distIcon(spi.id, size: 26),
        title: Text(
          spi.name,
          style: UIs.text18,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          spi.displayAddr,
          style: UIs.text12Grey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        onLongPress: onLongPress,
      ).onSecondary(asSecondary(onLongPress)),
    );
  }
}
