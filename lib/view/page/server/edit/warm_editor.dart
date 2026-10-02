part of 'edit.dart';

extension _WarmEditor on _ServerEditPageState {
  Widget _buildWarmEditor(List<Widget> actions) {
    final theme = Theme.of(context);
    final allTags = ref.watch(serversProvider).tags;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.warmEditServer), actions: actions),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_useSsh, _useMonitorHttp, _keyIdx, _keyPath, _warmPasswordShown, _tags]),
          builder: (_, _) => ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              ServerGroup(padding: 8, children: [Theme(
                data: theme.copyWith(listTileTheme: theme.listTileTheme.copyWith(visualDensity: const VisualDensity(vertical: -2))),
                child: _buildConnMethodSwitch(),
              )]),
              const SizedBox(height: 12),
              ServerGroup(title: l10n.warmBasicInfo, children: [
                _warmField(libL10n.name, _nameController, node: _nameFocus,
                  onSubmitted: (_) => _useSsh.value ? _focusScope.requestFocus(_ipFocus) : _focusScope.unfocus()),
                if (_useSsh.value) ...[
                  _warmField(libL10n.host, _ipController, node: _ipFocus, type: TextInputType.url,
                    hint: 'example.com', onSubmitted: (_) => _focusScope.requestFocus(_portFocus)),
                  Row(children: [
                    Expanded(child: _warmField(libL10n.port, _portController, node: _portFocus,
                      type: TextInputType.number, hint: '22', narrow: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _warmField(libL10n.user, _usernameController,
                      node: _usernameFocus, hint: 'root', narrow: true)),
                  ]),
                ],
                if (_tags.value.isNotEmpty) TagTile(tags: _tags, allTags: allTags),
              ]),
              if (_useSsh.value) ...[
                const SizedBox(height: 12),
                ServerGroup(title: l10n.warmAuthentication, children: [
                  SizedBox(width: double.infinity, child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.selected) ? theme.colorScheme.primary : Colors.transparent),
                      foregroundColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.selected) ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
                      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    segments: [
                      ButtonSegment(value: false, label: Text(libL10n.pwd)),
                      ButtonSegment(value: true, label: Text(l10n.privateKey)),
                    ],
                    selected: {_keyIdx.value != null || _keyPath.value != null},
                    onSelectionChanged: (selection) {
                      if (selection.first) {
                        if (_keyPath.value == null) _keyIdx.value = -1;
                      } else {
                        _keyIdx.value = null;
                        _keyPath.value = null;
                      }
                    },
                  )),
                  if (_keyIdx.value != null) _buildKeyAuth(),
                  _buildKeyPath(),
                  _warmField(libL10n.pwd, _passwordController, obscure: !_warmPasswordShown.value,
                    suffix: IconButton(
                      tooltip: libL10n.pwd,
                      icon: Icon(_warmPasswordShown.value ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => _warmPasswordShown.value = !_warmPasswordShown.value,
                    )),
                ]),
              ],
              if (_useMonitorHttp.value) ...[
                const SizedBox(height: 12),
                ServerGroup(title: 'Monitor HTTP', children: [_buildMonitorHttp()]),
              ],
              const SizedBox(height: 12),
              ServerGroup(padding: 8, children: [
                _autoConnect.listenVal((value) => SwitchListTile(
                  title: Text(l10n.autoConnect), value: value,
                  onChanged: (next) => _autoConnect.value = next,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                )),
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.tune, size: 20),
                  title: Text(l10n.warmAdvancedOptions),
                  children: [
                    if (_tags.value.isEmpty) TagTile(tags: _tags, allTags: allTags),
                    if (_useSsh.value) ...[_buildSystemType(), _buildJumpServer()],
                    _buildMore(),
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: AppButton(onPressed: _onSave, child: Text(libL10n.save)),
      )),
    );
  }

  Widget _warmField(String label, TextEditingController controller, {
    FocusNode? node, TextInputType? type, String? hint, bool narrow = false,
    bool obscure = false, Widget? suffix, ValueChanged<String>? onSubmitted,
  }) {
    final theme = Theme.of(context);
    final field = FTextField(
      control: FTextFieldControl.managed(controller: controller),
      focusNode: node, keyboardType: type, hint: hint,
      obscureText: obscure, autocorrect: false, enableSuggestions: false,
      onSubmit: onSubmitted,
      onTapOutside: (_) => _focusScope.unfocus(),
      suffixBuilder: suffix == null ? null : (_, _, _) => suffix,
    );
    return Semantics(label: label, child: Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: narrow ? Row(children: [
        Flexible(child: Text(label, style: theme.textTheme.bodySmall)),
        const SizedBox(width: 4), Expanded(flex: 2, child: field),
      ]) : Row(children: [
        SizedBox(width: 64, child: Text(label, style: theme.textTheme.bodyMedium)),
        Expanded(child: field),
      ]),
    ));
  }
}
