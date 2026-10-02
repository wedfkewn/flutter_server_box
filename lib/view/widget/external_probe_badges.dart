import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/app/external_probe.dart';
import 'package:server_box/data/provider/external_probe.dart';
import 'package:server_box/view/page/external_probes.dart';
import 'package:server_box/view/widget/probe_labels.dart';

class ExternalProbeBadges extends ConsumerWidget {
  const ExternalProbeBadges({super.key, required this.serverId});
  final String serverId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(externalProbeProvider(serverId));
    return ListenableBuilder(listenable: controller, builder: (context, _) {
      final favorites = controller.config.favorites;
      final readings = [for (final target in controller.config.enabled)
        ?controller.results[target.id]];
      final healthy = readings.where((e) => e.state == ProbeState.reachable).length;
      final rejected = readings.where((e) => e.state == ProbeState.rejected).length;
      final unknown = readings.where((e) => e.state == ProbeState.unknown).length;
      final last = readings.isEmpty ? null : readings.map((e) => e.checkedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b).toLocal();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(probeText(context, '外网服务', 'External services'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => ExternalProbesPage.show(context, serverId),
            child: Text(probeText(context, '查看全部 ›', 'View all ›'), style: const TextStyle(fontSize: 11))),
        ]),
        if (favorites.isEmpty) TextButton.icon(
          onPressed: () => ExternalProbesPage.show(context, serverId),
          icon: const Icon(Icons.add, size: 16),
          label: Text(probeText(context, '选择首页置顶项目', 'Choose homepage favorites')))
        else Wrap(spacing: 6, runSpacing: 6, children: [
          for (final target in favorites) ActionChip(
            avatar: controller.checking.contains(target.id)
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(controller.results[target.id]?.state == ProbeState.reachable
                ? Icons.check_circle_outline : Icons.public, size: 14,
                color: probeColor(context, controller.results[target.id])),
            label: Text('${target.name} · ${controller.checking.contains(target.id) ? probeText(context, '检测中', 'Checking') : probeStateLabel(context, controller.results[target.id], tcp: target.protocol == ProbeProtocol.tcp)}',
              style: TextStyle(fontSize: 11, color: probeColor(context, controller.results[target.id]))),
            onPressed: () => ExternalProbesPage.show(context, serverId)),
        ]),
        const SizedBox(height: 6),
        Text(readings.isEmpty
          ? probeText(context, '尚未检测 · 点击查看全部开始', 'Not checked · Open View all to start')
          : probeText(context, '上次结果：${readings.length} 项 · $healthy 正常 · $rejected 异常 · $unknown 待确认',
            'Previous results: ${readings.length} · $healthy responded · $rejected unexpected · $unknown inconclusive'),
          style: Theme.of(context).textTheme.bodySmall),
        if (last != null) Text('${probeText(context, '最近检测', 'Last check')}: ${last.toString().split('.').first}',
          style: Theme.of(context).textTheme.bodySmall),
      ]);
    });
  }
}
