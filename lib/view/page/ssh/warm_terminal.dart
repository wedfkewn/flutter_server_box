part of 'tab.dart';

extension _WarmTerminal on _SSHTabPageState {
  Widget _buildWarmTerminal() => ListenableBuilder(
    listenable: Listenable.merge([_drawerOpen, _drawerDragOffset, _statusVersion]),
    builder: (context, _) {
      final current = _sessions.current;
      final open = current == null || _drawerOpen.value;
      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            _warmHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // One live view of each shell. The drawer resizes the PTY;
                  // it never creates a second terminal or restarts a session.
                  final drawerHeight = current == null
                      ? constraints.maxHeight * .76
                      : math.min(
                          392.0,
                          constraints.maxHeight *
                              (constraints.maxHeight < 300 ? .78 : .62),
                        );
                  return Column(
                    children: [
                      Expanded(
                        child: SessionTabsView<_SshSession>(
                          controller: _sessions,
                          leading: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                l10n.warmTerminalPickConnection,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                          builder: (_, tab) => tab.data.page,
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: open
                            ? current == null ? drawerHeight
                                : (drawerHeight - _drawerDragOffset.value)
                                    .clamp(32.0, drawerHeight)
                            : 0.0),
                        duration: _drawerDragging ? Duration.zero
                            : WarmMotion.of(context, WarmMotion.quick),
                        curve: Curves.easeOutCubic,
                        builder: (_, height, _) => height < .5
                            ? const SizedBox.shrink()
                            : ClipRect(child: SizedBox(
                                height: height,
                                width: double.infinity,
                                // Keep the list's constraints stable as the
                                // visible panel shrinks under the drag handle.
                                child: OverflowBox(
                                  alignment: Alignment.topCenter,
                                  minHeight: drawerHeight,
                                  maxHeight: drawerHeight,
                                  child: _warmDrawer(),
                                ),
                              )),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _warmHeader() {
    final current = _sessions.current;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .35),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 18, right: 4, top: 4, bottom: 4),
        child: Row(
          children: [
            Icon(Icons.terminal_outlined, size: 34, color: scheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                key: const ValueKey('terminal-session-picker'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _setDrawer(!_drawerOpen.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              current?.name ?? libL10n.terminal,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.expand_more, size: 20),
                        ],
                      ),
                      if (current != null)
                        Text(
                          _sessionAddr(_sessions.index) ??
                              current.data.page.args.source.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (current != null)
              _WarmTerminalStatus(
                status:
                    current.data.pageKey.currentState?.connectionStatus ??
                    TermSessionStatus.connecting,
                showLabel:
                    MediaQuery.sizeOf(context).width >= 360 &&
                    MediaQuery.textScalerOf(context).scale(1) < 1.5,
              ),
            _warmMenu(),
          ],
        ),
      ),
    );
  }

  Widget _warmMenu() => PopupMenuButton<String>(
    key: const ValueKey('terminal-tools-menu'),
    tooltip: libL10n.more,
    icon: const Icon(Icons.more_horiz),
    onSelected: (action) {
      switch (action) {
        case 'agent':
          _sessions.current?.data.pageKey.currentState?.openAgentFromToolbar();
        case 'snippet':
          _sessions.current?.data.pageKey.currentState
              ?.pickSnippetFromToolbar();
        case 'float':
          _toggleFloat();
        case 'sort':
          _showSortMenu();
        case 'history':
          _showHistory();
        case 'commands':
          showCommandReference(context);
      }
    },
    itemBuilder: (_) {
      final current = _sessions.current;
      final session = current?.data.pageKey.currentState?.session;
      final floating =
          session != null &&
          ref.read(terminalShellProvider.notifier).isFloating(session);
      PopupMenuEntry<String> item(String value, IconData icon, String label) =>
          PopupMenuItem(
            value: value,
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(label)),
              ],
            ),
          );
      return [
        item('commands', Icons.menu_book_outlined, commandUiText(context, '命令速查', 'Command reference')),
        if (current != null) ...[
          if (current.data.page.args.spi != null)
            item('agent', Icons.auto_awesome, l10n.askAi),
          item('snippet', Icons.code, libL10n.snippet),
          item(
            'float',
            Icons.picture_in_picture_alt_outlined,
            floating ? l10n.floatReturnToTab : l10n.floatOverTabs,
          ),
          const PopupMenuDivider(),
        ],
        item('sort', _SortOrder.stored.icon, libL10n.sort),
        item('history', Icons.history, l10n.serverHistory),
      ];
    },
  );

  Widget _warmDrawer() {
    final scheme = Theme.of(context).colorScheme;
    final canCollapse = _sessions.current != null;
    return AppCard(
      key: const ValueKey('terminal-connections-drawer'),
      child: Column(
        children: [
          Semantics(
            label: libL10n.close,
            button: true,
            enabled: canCollapse,
            child: Listener(
              onPointerCancel: (_) => _cancelDrawerDrag(),
              child: GestureDetector(
                key: const ValueKey('terminal-drawer-handle'),
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onTap: canCollapse ? () => _setDrawer(false) : null,
                onVerticalDragStart: canCollapse ? (_) {
                  _drawerDragging = true;
                  _drawerDragOffset.value = 0;
                } : null,
                onVerticalDragUpdate: canCollapse ? (details) {
                  _drawerDragOffset.value = math.max(
                    0.0, _drawerDragOffset.value + details.delta.dy);
                } : null,
                onVerticalDragEnd: canCollapse ? (details) {
                  if (!_drawerDragging) return;
                  final close = _drawerDragOffset.value >= 64 ||
                      (_drawerDragOffset.value > 12 &&
                          (details.primaryVelocity ?? 0) > 700);
                  _drawerDragging = false;
                  if (close) {
                    _setDrawer(false);
                  } else {
                    _drawerDragOffset.value = 0;
                  }
                } : null,
                onVerticalDragCancel: canCollapse ? _cancelDrawerDrag : null,
                child: SizedBox(
                  height: 32,
                  width: double.infinity,
                  child: Center(child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: .4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )),
                ),
              ),
            ),
          ),
          SizedBox(
            height: math.max(
              62,
              MediaQuery.textScalerOf(context).scale(20) * 1.6 + 16,
            ),
            child: InlineSearchBar(
              controller: _search,
              child: Padding(
                padding: const EdgeInsets.only(left: 18, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.warmTerminalConnections,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: libL10n.search,
                      onPressed: _search.start,
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      key: const ValueKey('terminal-collapse-drawer'),
                      tooltip: libL10n.close,
                      onPressed: _sessions.current == null
                          ? null
                          : () => _setDrawer(false),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(
            indent: 18,
            endIndent: 18,
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: .35),
          ),
          Expanded(
            child: _AddPage(
              compact: true,
              prefix: [
                _WarmConnectionSection(l10n.warmTerminalCurrentSessions),
                if (_sessions.tabs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      l10n.warmTerminalNoSessions,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                for (final tab in _sessions.tabs)
                  _WarmConnectionRow(
                    key: ValueKey('terminal-session-${tab.id}'),
                    title: tab.name,
                    subtitle: _sessionAddr(_sessions.names.indexOf(tab.name)),
                    selected: identical(tab, _sessions.current),
                    status:
                        tab.data.pageKey.currentState?.connectionStatus ??
                        TermSessionStatus.connecting,
                    onTap: () =>
                        _selectWarmSession(_sessions.names.indexOf(tab.name)),
                    trailing: IconButton(
                      tooltip: '${libL10n.close} ${tab.name}',
                      onPressed: () =>
                          _confirmClose(_sessions.names.indexOf(tab.name)),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ),
              ],
              sortVersion: Listenable.merge([_sortVersion, _search]),
              search: _search,
              onTap: _openServer,
              onLocal: () => _open(const LocalSource()),
              onLongPress: (spi) =>
                  ServerEditPage.route.go(context, args: SpiRequiredArgs(spi)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarmConnectionSection extends StatelessWidget {
  const _WarmConnectionSection(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      if (title == l10n.warmTerminalNewConnection)
        Divider(
          height: 1,
          indent: 6,
          endIndent: 6,
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .35),
        ),
    ],
  );
}

class _WarmConnectionRow extends StatelessWidget {
  const _WarmConnectionRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.trailing,
    this.status,
    this.connection = false,
  });
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Widget? trailing;
  final TermSessionStatus? status;
  final bool connection;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: connection
            ? Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: .35),
                ),
              )
            : null,
      ),
      child: Material(
        color: selected
            ? (dark ? scheme.secondaryContainer : WarmTheme.surfaceStrong)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: connection
                        ? Colors.transparent
                        : dark
                        ? scheme.surfaceContainerHigh
                        : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    connection ? Icons.dns_outlined : Icons.terminal_outlined,
                    color: connection
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                    size: connection ? 28 : 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _WarmTerminalStatus(
                      status: status!,
                      showLabel: false,
                    ),
                  ),
                if (trailing != null)
                  trailing!
                else if (connection)
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarmTerminalStatus extends StatelessWidget {
  const _WarmTerminalStatus({required this.status, this.showLabel = true});
  final TermSessionStatus status;
  final bool showLabel;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      TermSessionStatus.connected => (
        l10n.warmTerminalConnected,
        Theme.of(context).brightness == Brightness.dark
            ? scheme.tertiary
            : WarmTheme.olive,
      ),
      TermSessionStatus.connecting => (
        l10n.warmTerminalConnecting,
        scheme.onSurfaceVariant,
      ),
      TermSessionStatus.disconnected => (
        l10n.warmTerminalDisconnected,
        scheme.error,
      ),
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
