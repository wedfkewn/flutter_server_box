import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/app/ip_info.dart';
import 'package:server_box/data/provider/ip_info.dart';

class IpLocationQuery extends ConsumerStatefulWidget {
  final String ip;

  const IpLocationQuery({
    super.key,
    required this.ip,
  });

  @override
  ConsumerState<IpLocationQuery> createState() => _IpLocationQueryState();
}

class _IpLocationQueryState extends ConsumerState<IpLocationQuery> {
  @override
  void initState() {
    super.initState();
    // Auto fetch when initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetch();
    });
  }

  @override
  void didUpdateWidget(covariant IpLocationQuery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ip != widget.ip) {
      _fetch();
    }
  }

  void _fetch() {
    ref.read(ipInfoProvider(widget.ip).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final asyncIpInfo = ref.watch(ipInfoProvider(widget.ip));

    return asyncIpInfo.when(
      data: (ipInfo) {
        if (ipInfo == null) return const SizedBox.shrink();
        return _buildInfo(context, ipInfo);
      },
      error: (err, stack) => InkWell(
        onTap: _fetch,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to load IP info. Tap to retry.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, IpInfo info) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    final cc = info.country?.toUpperCase();
    final flag = cc == null ? null : _flagEmoji(cc);

    final parts = [
      if (cc != null) cc,
      info.region,
      info.city,
      info.org
    ].where((e) => e != null && e.isNotEmpty).join(' • ');

    return InkWell(
      onTap: _fetch,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag != null) ...[
              Text(
                flag,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontFamilyFallback: const [
                    'Noto Color Emoji',
                    'NotoColorEmoji',
                    'Segoe UI Emoji',
                    'Apple Color Emoji',
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ] else ...[
              Icon(Icons.public, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                parts.isEmpty ? info.ip : parts,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _flagEmoji(String countryCode) {
    if (countryCode.length != 2) return null;
    final a = countryCode.codeUnitAt(0);
    final b = countryCode.codeUnitAt(1);
    if (a < 0x41 || a > 0x5A) return null;
    if (b < 0x41 || b > 0x5A) return null;
    final first = a - 0x41 + 0x1F1E6;
    final second = b - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}
