part of 'tab.dart';

class ServerCardModern extends StatelessWidget {
  final ServerState srv;
  final Spi spi;

  const ServerCardModern({
    super.key,
    required this.srv,
    required this.spi,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        _buildTags(context),
        const SizedBox(height: 12),
        IpLocationQuery(ip: spi.ip),
        const SizedBox(height: 12),
        _buildStats(context),
        const SizedBox(height: 12),
        _buildNetwork(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final sysIcon = switch (srv.status.system) {
      SystemType.linux => MingCute.linux_line,
      SystemType.bsd => LineAwesome.freebsd,
      SystemType.windows => MingCute.windows_line,
    };

    return Row(
      children: [
        Icon(sysIcon, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            spi.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _buildLatencyTag(context),
      ],
    );
  }

  Widget _buildLatencyTag(BuildContext context) {
    if (srv.conn != ServerConn.finished) {
      return Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 50),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          srv.conn.name.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
    }

    // Using TCP connections count as a proxy for activity since latency is not directly available
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 50),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link, size: 12, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            '${srv.status.tcp.active}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildTags(BuildContext context) {
    final os = srv.status.more[StatusCmdType.sys] ?? 'Unknown OS';
    final arch = srv.status.more[StatusCmdType.arch] ?? 'Unknown Arch';
    final kernel = srv.status.more[StatusCmdType.kernel] ?? 'Unknown Kernel';
    final uptime = srv.status.more[StatusCmdType.uptime] ?? 'Unknown Uptime';

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _buildTagItem(context, os, Icons.computer),
        _buildTagItem(context, arch, Icons.memory),
        _buildTagItem(context, kernel, Icons.settings_system_daydream),
        _buildTagItem(
          context,
          '${context.l10n.uptime}: $uptime',
          Icons.timer,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildTagItem(BuildContext context, String text, IconData icon, {Color? color}) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 50),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: effectiveColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: effectiveColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: effectiveColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final memUsed = (srv.status.mem.total - srv.status.mem.avail) * 1024;
    final memTotal = srv.status.mem.total * 1024;
    final memDetail = '${memUsed.bytes2Str}/${memTotal.bytes2Str}';

    final diskUsed = srv.status.diskUsage?.used ?? BigInt.zero;
    final diskTotal = srv.status.diskUsage?.size ?? BigInt.one;
    final diskDetail = '${diskUsed.bytes2Str}/${diskTotal.bytes2Str}';

    return Column(
      children: [
        _buildProgress(
            context, 'CPU', srv.status.cpu.usedPercent() / 100, Colors.blue),
        const SizedBox(height: 8),
        _buildProgress(context, 'Mem', srv.status.mem.usedPercent,
            Colors.purple,
            detail: memDetail),
        const SizedBox(height: 8),
        _buildProgress(context, context.l10n.disk,
            (srv.status.diskUsage?.usedPercent ?? 0) / 100, Colors.orange,
            detail: diskDetail),
      ],
    );
  }

  Widget _buildProgress(BuildContext context, String label, double value,
      Color color,
      {String? detail}) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: color.withOpacity(0.1),
            color: color,
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: Text(
            detail ?? '${(value * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildNetwork(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildNetItem(
            context,
            'Upload',
            srv.status.netSpeed.speedOut(),
            srv.status.netSpeed.sizeOut(),
            Icons.arrow_upward,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNetItem(
            context,
            'Download',
            srv.status.netSpeed.speedIn(),
            srv.status.netSpeed.sizeIn(),
            Icons.arrow_downward,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildNetItem(BuildContext context, String label, String speed,
      String total, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: speed,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    TextSpan(
                      text: ' ($total)',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Theme.of(context).hintColor, fontSize: 10),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
