import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/dns_lookup.dart';
import 'package:server_box/core/service/ip_geo.dart';
import 'package:server_box/core/service/ip_lookup.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/model/app/dns_lookup.dart';
import 'package:server_box/data/model/app/ip_lookup.dart';
import 'package:server_box/data/res/store.dart';

class IpLookupPage extends StatefulWidget {
  const IpLookupPage({super.key, this.service, this.dnsService});

  final IpLookupService? service;
  final DnsLookupService? dnsService;

  static const route = AppRouteNoArg(page: IpLookupPage.new, path: '/ip-check');

  @override
  State<IpLookupPage> createState() => _IpLookupPageState();
}

class _IpLookupPageState extends State<IpLookupPage> {
  final _input = TextEditingController();
  late final _service = widget.service ?? IpLookupService();
  late final _dnsService = widget.dnsService ?? DnsLookupService();
  CancelToken? _cancelToken;
  CancelToken? _dnsCancelToken;
  PublicIpPair? _publicIps;
  List<IpLookupResult> _results = const [];
  IpLookupFailure? _failure;
  bool _loadingPublic = false;
  bool _loadingQuery = false;
  bool _loadingDns = false;
  DnsLookupResult? _dnsResult;
  IpLookupFailure? _dnsFailure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _dnsCancelToken?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    if (!Stores.setting.ipLookupConsent.fetch()) {
      final accepted = await showDialog<bool>(
        context: context,
        animationStyle: isMobile ? WarmMotion.dialog(context) : null,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.privacy_tip_outlined),
          title: Text(ctx.l10n.ipLookupPrivacyTitle),
          content: Text(ctx.l10n.ipLookupPrivacyBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.libL10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.ipLookupAgree),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) {
        if (mounted) Navigator.pop(context);
        return;
      }
      Stores.setting.ipLookupConsent.put(true);
    }
    await _detectPublic();
  }

  Future<void> _detectPublic() async {
    _cancelToken?.cancel();
    final token = CancelToken();
    _cancelToken = token;
    setState(() {
      _loadingPublic = true;
      _failure = null;
    });
    final pair = await _service.discoverPublicIps(cancelToken: token);
    if (!mounted || token.isCancelled) return;

    final addresses = [
      pair.ipv4.address,
      pair.ipv6.address,
    ].whereType<InternetAddress>();
    final details = <IpLookupResult>[];
    for (final address in addresses) {
      try {
        details.add(
          await _service.lookup(
            address,
            languageCode: Localizations.localeOf(context).languageCode,
            cancelToken: token,
          ),
        );
      } on IpLookupFailure catch (error) {
        _failure ??= error;
        final offline = _offlineResult(address, error);
        if (offline != null) details.add(offline);
      }
    }
    if (!mounted || token.isCancelled) return;
    setState(() {
      _publicIps = pair;
      _results = details;
      _loadingPublic = false;
    });
  }

  Future<void> _query() async {
    FocusScope.of(context).unfocus();
    _cancelToken?.cancel();
    final token = CancelToken();
    _cancelToken = token;
    setState(() {
      _loadingQuery = true;
      _failure = null;
      _results = const [];
    });
    var addresses = <InternetAddress>[];
    try {
      addresses = await _service.resolveInput(_input.text);
      final results = <IpLookupResult>[];
      for (final address in addresses) {
        results.add(
          await _service.lookup(
            address,
            languageCode: Localizations.localeOf(context).languageCode,
            cancelToken: token,
          ),
        );
      }
      if (!mounted || token.isCancelled) return;
      setState(() => _results = results);
    } on IpLookupFailure catch (error) {
      if (!mounted || token.isCancelled) return;
      final offline = addresses
          .map((address) => _offlineResult(address, error))
          .whereType<IpLookupResult>()
          .toList(growable: false);
      setState(() {
        _failure = error;
        _results = offline;
      });
    } finally {
      if (mounted && !token.isCancelled) setState(() => _loadingQuery = false);
    }
  }

  Future<void> _queryDns() async {
    FocusScope.of(context).unfocus();
    String domain;
    try {
      domain = DnsLookupService.normalizeDomain(_input.text);
    } on IpLookupFailure catch (failure) {
      setState(() {
        _dnsFailure = failure;
        _dnsResult = null;
      });
      return;
    }
    if (!Stores.setting.dnsLookupConsent.fetch()) {
      final accepted = await showDialog<bool>(
        context: context,
        animationStyle: isMobile ? WarmMotion.dialog(context) : null,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.privacy_tip_outlined),
          title: Text(ctx.l10n.dnsLookupPrivacyTitle),
          content: Text(ctx.l10n.dnsLookupPrivacyBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.libL10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.ipLookupAgree),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      Stores.setting.dnsLookupConsent.put(true);
    }
    _dnsCancelToken?.cancel();
    final token = CancelToken();
    _dnsCancelToken = token;
    setState(() {
      _loadingDns = true;
      _dnsFailure = null;
      _dnsResult = null;
    });
    try {
      final result = await _dnsService.lookup(domain, cancelToken: token);
      if (mounted && !token.isCancelled) {
        setState(() => _dnsResult = result);
      }
    } on IpLookupFailure catch (failure) {
      if (mounted && !token.isCancelled) {
        setState(() => _dnsFailure = failure);
      }
    } finally {
      if (mounted && !token.isCancelled) {
        setState(() => _loadingDns = false);
      }
    }
  }

  IpLookupResult? _offlineResult(
    InternetAddress address,
    IpLookupFailure failure,
  ) {
    if (failure.kind != IpLookupFailureKind.network &&
        failure.kind != IpLookupFailureKind.timeout &&
        failure.kind != IpLookupFailureKind.rateLimited &&
        failure.kind != IpLookupFailureKind.service) {
      return null;
    }
    final coord = IpGeo.offlineCoordOf(address);
    if (coord == null) return null;
    return IpLookupResult(
      ip: address.address,
      type: address.type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4',
      latitude: coord.lat,
      longitude: coord.lon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ipLookupTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(
            l10n.ipLookupSubtitle,
            style: const TextStyle(color: WarmTheme.muted),
          ),
          const SizedBox(height: 18),
          _section(
            title: l10n.ipLookupCurrent,
            trailing: IconButton(
              tooltip: context.libL10n.refresh,
              onPressed: _loadingPublic ? null : _detectPublic,
              icon: const Icon(Icons.refresh),
            ),
            child: Column(
              children: [
                _publicRow(l10n.ipLookupIpv4, _publicIps?.ipv4),
                const Divider(height: 1),
                _publicRow(l10n.ipLookupIpv6, _publicIps?.ipv6),
                if (_loadingPublic) const LinearProgressIndicator(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _section(
            title: l10n.ipLookupInputTitle,
            child: Column(
              children: [
                TextField(
                  controller: _input,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: l10n.ipLookupInputHint,
                    prefixIcon: const Icon(Icons.travel_explore),
                  ),
                  onSubmitted: (_) => _loadingQuery ? null : _query(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loadingQuery ? null : _query,
                    icon: _loadingQuery
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(l10n.ipLookupAction),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadingDns ? null : _queryDns,
                    icon: _loadingDns
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.dns_outlined),
                    label: Text(l10n.dnsLookupAction),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: WarmMotion.of(context, WarmMotion.page),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_failure != null) ...[
                  const SizedBox(height: 14),
                  _ErrorCard(message: _failureText(_failure!)),
                ],
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    l10n.networkCheckReport,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.networkCheckReportTip,
                    style: const TextStyle(
                      color: WarmTheme.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final result in _results) ...[
                    RepaintBoundary(child: _ResultCard(result: result)),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
          AnimatedSize(
            duration: WarmMotion.of(context, WarmMotion.page),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_dnsFailure != null) ...[
                  const SizedBox(height: 14),
                  _ErrorCard(message: _dnsFailureText(_dnsFailure!)),
                ],
                if (_dnsResult case final result?) ...[
                  const SizedBox(height: 18),
                  Text(
                    '${l10n.networkCheckDnsSection} · ${result.domain}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (result.records.isEmpty)
                    _section(
                      title: l10n.dnsLookupNoRecords,
                      child: const SizedBox.shrink(),
                    ),
                  for (final type in DnsRecordType.values)
                    if (result.records.any(
                      (record) => record.type == type,
                    )) ...[
                      _section(
                        title: type.label,
                        child: Column(
                          children: [
                            for (final record in result.records.where(
                              (record) => record.type == type,
                            ))
                              _dnsRecordRow(record),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  if (result.failedTypes.isNotEmpty)
                    _ErrorCard(
                      message:
                          '${l10n.dnsLookupPartial}${result.failedTypes.map((type) => type.label).join(', ')}',
                    ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.dnsLookupSource,
                    style: const TextStyle(
                      color: WarmTheme.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.ipLookupSource,
            style: const TextStyle(color: WarmTheme.muted),
          ),
          const SizedBox(height: 5),
          Text(
            l10n.ipLookupDisclaimer,
            style: const TextStyle(color: WarmTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    Widget? trailing,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: WarmTheme.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _publicRow(String title, PublicIpResult? value) {
    final text = value?.address?.address ?? context.l10n.ipLookupNotDetected;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(text),
      trailing: value?.address == null
          ? null
          : IconButton(
              tooltip: context.libL10n.copy,
              onPressed: () => _copy(value!.address!.address),
              icon: const Icon(Icons.copy),
            ),
    );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) Toast.success(context.l10n.ipLookupCopied);
  }

  Widget _dnsRecordRow(DnsRecord record) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.name, style: const TextStyle(color: WarmTheme.muted)),
              SelectableText(record.value),
              Text(
                'TTL ${record.ttl}s',
                style: const TextStyle(color: WarmTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: context.libL10n.copy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: record.value));
            if (mounted) Toast.success(context.l10n.dnsLookupCopied);
          },
          icon: const Icon(Icons.copy_outlined),
        ),
      ],
    ),
  );

  String _dnsFailureText(IpLookupFailure failure) => switch (failure.kind) {
    IpLookupFailureKind.invalidInput ||
    IpLookupFailureKind.privateAddress => context.l10n.dnsLookupInvalid,
    IpLookupFailureKind.dns => context.l10n.dnsLookupDnsError,
    IpLookupFailureKind.network => context.l10n.ipLookupNetworkError,
    IpLookupFailureKind.timeout => context.l10n.ipLookupTimeout,
    IpLookupFailureKind.rateLimited => context.l10n.dnsLookupRateLimited,
    IpLookupFailureKind.service => context.l10n.dnsLookupServiceError,
  };

  String _failureText(IpLookupFailure failure) => switch (failure.kind) {
    IpLookupFailureKind.invalidInput => context.l10n.ipLookupInvalid,
    IpLookupFailureKind.privateAddress => context.l10n.ipLookupPrivate,
    IpLookupFailureKind.dns => context.l10n.ipLookupDnsError,
    IpLookupFailureKind.network => context.l10n.ipLookupNetworkError,
    IpLookupFailureKind.timeout => context.l10n.ipLookupTimeout,
    IpLookupFailureKind.rateLimited => context.l10n.ipLookupRateLimited,
    IpLookupFailureKind.service => context.l10n.ipLookupServiceError,
  };
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final IpLookupResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final location = [
      result.region,
      result.city,
    ].whereType<String>().join(' · ');
    final coordinates = result.latitude == null || result.longitude == null
        ? null
        : '${result.latitude!.toStringAsFixed(4)}, ${result.longitude!.toStringAsFixed(4)}';
    final rows = <(String, String?)>[
      (result.type, result.ip),
      (
        l10n.ipLookupCountry,
        [result.flagEmoji, result.country].whereType<String>().join(' '),
      ),
      (l10n.ipLookupCity, location),
      (l10n.ipLookupCoordinates, coordinates),
      (l10n.ipLookupIsp, result.isp),
      (l10n.ipLookupOrganization, result.organization),
      (l10n.ipLookupAsn, result.asnLabel),
      (l10n.ipLookupDomain, result.networkDomain),
      (
        l10n.ipLookupTimezone,
        [result.timezone, result.utcOffset].whereType<String>().join(' '),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WarmTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          for (final row in rows)
            if (row.$2?.trim().isNotEmpty == true)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  row.$1,
                  style: const TextStyle(color: WarmTheme.muted),
                ),
                subtitle: Text(
                  row.$2!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: row.$2 == result.ip
                    ? IconButton(
                        tooltip: context.libL10n.copy,
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: result.ip),
                          );
                          if (context.mounted) {
                            Toast.success(l10n.ipLookupCopied);
                          }
                        },
                        icon: const Icon(Icons.copy),
                      )
                    : null,
              ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
