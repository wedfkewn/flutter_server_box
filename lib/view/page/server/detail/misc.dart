part of 'view.dart';

extension on _ServerDetailPageState {
  void _showClosableDetailDialog({
    required String title,
    required Widget child,
  }) {
    context.showRoundDialog(
      title: title,
      child: child,
      actions: [
        TextButton(onPressed: () => context.popDialog(), child: Text(libL10n.close)),
      ],
    );
  }

  void _showGpuProcessesDialog({
    required String title,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    final displayCount = itemCount > 5 ? 5 : itemCount;
    final height = (displayCount > 0 ? displayCount : 1) * 47.0;
    context.showRoundDialog(
      title: title,
      child: SizedBox(
        width: double.maxFinite,
        height: height,
        child: itemCount == 0
            ? Center(child: Text(libL10n.empty))
            : ListView.builder(itemCount: itemCount, itemBuilder: itemBuilder),
      ),
      actions: Btnx.oks,
    );
  }

  void _onTapNvidiaGpuItem(NvidiaSmiItem item) {
    final processes = item.memory.processes;
    _showGpuProcessesDialog(
      title: item.name,
      itemCount: processes.length,
      itemBuilder: (_, idx) => _buildGpuProcessItem(processes[idx]),
    );
  }

  void _onTapAmdGpuItem(AmdSmiItem item) {
    final processes = item.memory.processes;
    _showGpuProcessesDialog(
      title: item.name,
      itemCount: processes.length,
      itemBuilder: (_, idx) => _buildAmdGpuProcessItem(processes[idx]),
    );
  }

  void _onTapGpuProcessItem(GpuSmiMemProcess process) {
    _showClosableDetailDialog(
      title: '${process.pid}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UIs.height13,
          Text('${libL10n.memory}: ${process.memory} MiB'),
          UIs.height13,
          Text('${libL10n.process}: ${process.name}'),
        ],
      ),
    );
  }

  void _onTapAmdGpuProcessItem(GpuSmiMemProcess process) {
    _showClosableDetailDialog(
      title: '${process.pid}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UIs.height13,
          Text('${libL10n.memory}: ${_formatAmdGpuProcessMemory(process.memory)}'),
          UIs.height13,
          Text('${libL10n.process}: ${process.name}'),
        ],
      ),
    );
  }

  void _onTapCustomItem(MapEntry<String, String> cmd) {
    _showClosableDetailDialog(
      title: cmd.key,
      child: SingleChildScrollView(
        child: Text(cmd.value, style: UIs.text13Grey),
      ),
    );
  }

  void _onTapSensorItem(SensorItem si) {
    context.showRoundDialog(
      title: si.device,
      child: SingleChildScrollView(
        child: SimpleMarkdown(
          data: si.toMarkdown,
          styleSheet: MarkdownStyleSheet(
            tableBorder: TableBorder.all(color: Colors.grey),
            tableHead: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  bool _getInitExpand(int len, [int? max]) {
    if (!_collapse) return true;
    if (_size.width > UIs.columnWidth) return true;
    return len > 0 && len <= (max ?? 3);
  }

  /// Trends read one buffer ([ServerStatus.history]) that both connection
  /// methods append to, so an SSH server and a monitor HTTP server render
  /// identically; monitor servers additionally get theirs prefilled from the
  /// agent's stored history (`seedHistoryFromMonitor`).
  ///
  /// Grouping follows monitor's own panel: series sharing a unit go on one
  /// axis so they stay comparable, rather than each getting its own
  /// auto-scaled strip.
  ///
  /// These two return a bare chart, not a card: each is embedded in the CPU or
  /// RAM card beneath the figure it plots. The percentage labels describe
  /// the real readings, while the axis adapts to make small changes visible.
  Widget? _buildCpuChart(ServerState si) => _percentChart(
    'CPU',
    const Color(0xFF3B82F6),
    si.status.history.cpu,
    si.status.history.time,
  );

  Widget? _buildMemChart(ServerState si) => _percentChart(
    'RAM',
    const Color(0xFF22C55E),
    si.status.history.mem,
    si.status.history.time,
  );

  Widget? _percentChart(String label, Color color, List<double?> values, List<int> times) {
    final spec = _ChartSpec(
      series: [_HistorySeries(label, color, values)],
      format: _formatPercent,
      times: times,
    );
    return spec.hasData ? _buildChart(spec) : null;
  }

  /// Throughput, appended to the Disk card below its mounts.
  ///
  /// Only the rate is plotted. Used capacity was charted alongside it at
  /// first, but a filesystem's fill level barely moves over the minutes this
  /// buffer covers, so the line was flat and told nobody anything the ring
  /// beside each mount doesn't.
  Widget? _buildDiskChart(ServerState si) {
    final h = si.status.history;
    final spec = _ChartSpec(
      series: [
        _HistorySeries(l10n.read, const Color(0xFF0EA5E9), h.diskRead),
        _HistorySeries(l10n.write, const Color(0xFFF97316), h.diskWrite),
      ],
      format: _formatSpeed,
      binaryScale: true,
      times: h.time,
    );
    return spec.hasData ? _buildChart(spec) : null;
  }

  /// Palette for per-sensor temperature lines. Fixed order so a sensor keeps
  /// its colour across rebuilds, and at least as long as [_kTempCategories]
  /// so two plotted lines never share one.
  static const _kTempColors = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
  ];

  /// What the chart plots, in order: the hottest sensor matching each group.
  ///
  /// A Mac reports two dozen sensors through one API — fourteen of them PMU
  /// dies within a degree of each other — and a Linux box with several thermal
  /// zones is no better. Plotting all of them produced a legend taller than
  /// the plot and a band of indistinguishable lines; plotting simply the
  /// hottest N filled the chart with near-duplicate dies and dropped the SSD
  /// and the battery entirely. One line per component is what a temperature
  /// chart is read for; everything else is a tap away in [_showAllTemps].
  ///
  /// Names come from three unrelated sources, so each group has to cover all
  /// three:
  /// - Linux: the `type` of each `/sys/class/thermal/thermal_zone*`, plus
  ///   hwmon driver names where those are read
  /// - macOS: `sysinfo` Component labels, which are SMC keys spelled out
  /// - Windows: `MSAcpi_ThermalZoneTemperature`'s `InstanceName`, e.g.
  ///   `ACPI\ThermalZone\TZ00_0`
  ///
  /// Matched as lowercase substrings; the first group to match claims the
  /// sensor, so a device is never plotted twice. Order is by how much the
  /// reading usually matters.
  static const _kTempCategories = <List<String>>[
    // CPU / SoC package
    [
      'x86_pkg_temp', 'coretemp', 'k10temp', 'zenpower', 'peci', // Linux x86
      'cpu_thermal', 'cpu-thermal', 'soc_thermal', 'soc-thermal', // Linux ARM
      'bcm2835_thermal', 'tcpu',
      'tdie', 'tcal', 'pmgr soc', 'soc mtr', // macOS
      'cpu', 'package', 'soc',
    ],
    // GPU
    ['amdgpu', 'nouveau', 'radeon', 'gpu', 'tgpu'],
    // Storage
    ['nvme', 'nand', 'ssd', 'drive', 'disk'],
    // Battery / power delivery
    ['gas gauge', 'battery', 'bat0', 'charger'],
    // Wireless
    ['iwlwifi', 'airport', 'wifi', 'wlan'],
    // Board, chipset, ambient. Windows' single ACPI zone lands here, which is
    // fine: a host with one sensor plots it whichever group claims it.
    ['acpitz', 'thermalzone', 'pch', 'tskin', 'tskn', 'ambient', 'thermal'],
  ];

  static double? _latest(List<double?> values) {
    for (var i = values.length - 1; i >= 0; i--) {
      if (values[i] != null) return values[i];
    }
    return null;
  }

  List<_HistorySeries> _tempSeries(ServerState si) {
    final h = si.status.history;
    if (h.tempsByDevice.isEmpty) {
      return [_HistorySeries(libL10n.temperature, _kTempColors.first, h.temp)];
    }

    // Hottest first, so "the hottest match in this group" falls out of a
    // single pass and any leftovers are already ranked
    final ranked = h.tempsByDevice.entries.toList()
      ..sort(
        (a, b) => (_latest(b.value) ?? -1).compareTo(_latest(a.value) ?? -1),
      );

    final picked = <MapEntry<String, List<double?>>>[];
    final taken = <String>{};
    for (final group in _kTempCategories) {
      for (final e in ranked) {
        if (taken.contains(e.key)) continue;
        final name = e.key.toLowerCase();
        if (!group.any(name.contains)) continue;
        picked.add(e);
        taken.add(e.key);
        break;
      }
    }

    // A platform naming its sensors in some way this doesn't anticipate still
    // gets a chart, just an unsorted one
    if (picked.isEmpty) picked.add(ranked.first);

    return [
      for (final (i, e) in picked.indexed)
        _HistorySeries(e.key, _kTempColors[i % _kTempColors.length], e.value),
    ];
  }

  Widget? _buildTempChart(ServerState si) {
    final spec = _ChartSpec(series: _tempSeries(si), format: _formatTemp,
      times: si.status.history.time);
    return spec.hasData ? _buildChart(spec) : null;
  }

  /// Every sensor and its current reading, for the ones the chart leaves out.
  void _showAllTemps(server_model.ServerStatus ss) {
    final plotted = _tempSeries(
      ref.read(serverProvider(widget.args.spi.id)),
    ).map((e) => e.label).toSet();

    final rows = ss.temps.devices
        .map((d) {
          final mark = plotted.contains(d) ? '●' : '';
          final v = ss.temps.get(d)?.toStringAsFixed(1) ?? '--';
          return '| $mark | $d | $v °C |';
        })
        .join('\n');

    context.showRoundDialog(
      title: libL10n.temperature,
      child: SingleChildScrollView(
        child: SimpleMarkdown(
          data: '| | ${libL10n.device} | ${libL10n.temperature} |\n'
              '|---|---|---|\n$rows',
          styleSheet: MarkdownStyleSheet(
            tableBorder: TableBorder.all(color: Colors.grey),
            tableHead: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.popDialog(), child: Text(libL10n.close)),
      ],
    );
  }

  /// Sits at the top of the Network card, above the interface list.
  Widget? _buildNetChart(ServerState si) {
    final h = si.status.history;
    final spec = _ChartSpec(
      series: [
        _HistorySeries('↓', const Color(0xFF8B5CF6), h.netRx),
        _HistorySeries('↑', const Color(0xFFEC4899), h.netTx),
      ],
      format: _formatSpeed,
      binaryScale: true,
      times: h.time,
    );
    return spec.hasData ? _buildChart(spec) : null;
  }

  /// Appended to the Battery card. It used to sit in the temperature card,
  /// which stopped making sense once that card carried the sensor list too.
  Widget? _buildBatteryChart(ServerState si) => _percentChart(
    libL10n.battery,
    const Color(0xFF14B8A6),
    si.status.history.battery,
    si.status.history.time,
  );

  /// One chart plus the legend line carrying each series' latest value —
  /// mirrors `monitor/frontend/src/components/LineChart.svelte`.
  Widget _buildChart(_ChartSpec spec) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final activeSeries = spec.series.where((s) => s.spots.isNotEmpty).toList();
    final bars = <LineChartBarData>[];
    for (final s in activeSeries) {
      final spots = s.spotsAt(spec.times);
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: .16,
          preventCurveOverShooting: true,
          preventCurveOvershootingThreshold: 0,
          barWidth: 2.5,
          isStrokeCapRound: true,
          isStrokeJoinRound: true,
          color: s.color,
          dotData: FlDotData(
            checkToShowDot: (spot, _) => spot == spots.last,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 3, color: s.color, strokeWidth: 2,
              strokeColor: theme.colorScheme.surface,
            ),
          ),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [s.color.withValues(alpha: dark ? .22 : .16),
              s.color.withValues(alpha: .01)],
          )),
        ),
      );
    }
    if (bars.isEmpty) return UIs.placeholder;

    final hasLegend = activeSeries.length > 1;
    return Padding(
      // The extra bottom allowance is only for the axis' own overflow: fl_chart
      // centres the lowest label on the bottom gridline, so roughly half of it
      // hangs outside the plot box. A legend below already absorbs that, and
      // adding the allowance there too left a visible gap under the card.
      //
      // The top keeps the topmost axis label off whatever heading is above it;
      // at 7 the two touched.
      padding: EdgeInsets.fromLTRB(8, 18, 8, hasLegend ? 0 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 166 + (MediaQuery.textScalerOf(context).scale(11) - 11).clamp(0, 22),
            child: AppEntrance(child: _buildHistoryLineChart(
              bars,
              context: context,
              series: activeSeries,
              times: spec.times,
              format: spec.format,
              binaryScale: spec.binaryScale,
            )),
          ),
          // Only worth drawing when there is something to tell apart. A lone
          // line needs no key: the card already names its subject, and the
          // value is a touch away in the tooltip.
          if (hasLegend) ...[
            UIs.height13,
            Wrap(
              spacing: 13,
              runSpacing: 3,
              children: [
                for (final s in activeSeries)
                  if (s.latest != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        UIs.width7,
                        Text(
                          '${s.label} ${spec.format(s.latest!)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One chart: the series drawn on its shared axis, and how to label that axis.
class _ChartSpec {
  final List<_HistorySeries> series;
  final String Function(double) format;
  final List<int> times;

  /// Whether the values are byte-based, so the axis should step in multiples
  /// of 1024 rather than of 10 — see [_niceAxis]
  final bool binaryScale;

  const _ChartSpec({
    required this.series,
    required this.format,
    required this.times,
    this.binaryScale = false,
  });

  bool get hasData => series.any((s) => s.spots.isNotEmpty);
}

/// One line. Reads straight off a [StatusHistory] ring buffer, whose gaps are
/// `null` for "not measured at that sample". Interior gaps break the line;
/// missing samples never become zero or an interpolated measurement.
class _HistorySeries {
  final String label;
  final Color color;
  final List<double?> values;

  const _HistorySeries(this.label, this.color, this.values);

  List<FlSpot> get spots => spotsAt(const []);

  List<FlSpot> spotsAt(List<int> times) {
    final first = values.indexWhere((v) => v != null && v.isFinite);
    final last = values.lastIndexWhere((v) => v != null && v.isFinite);
    if (first < 0) return const [];
    return [for (var i = first; i <= last; i++)
      if (values[i] != null && values[i]!.isFinite)
        FlSpot(times.length > i ? (times[i] - times.first) / 1000 : i.toDouble(), values[i]!)
      else FlSpot.nullSpot,
    ];
  }

  double? get latest {
    for (var i = values.length - 1; i >= 0; i--) {
      final v = values[i];
      if (v != null && v.isFinite) return v;
    }
    return null;
  }
}

/// Picks an axis whose ticks land on round numbers.
///
/// Deriving the interval from the data instead (`peak * 1.1 / 4`) produced
/// ticks like 48.4°C and 514.5 KB/s: hard to read, and wide enough that every
/// chart had to reserve a gutter for them.
///
/// [binary] selects the progression. Byte rates are formatted in powers of
/// 1024, so a decimal-round step of 500 000 renders as "488.3 KB/s"; stepping
/// in multiples of 1024 gives "512 KB/s".
({double bottom, double top, double interval}) _niceAxis({
  required double trough,
  required double peak,
  required bool binary,
}) {
  // Below this the labels repeat: the formatters carry one decimal for
  // percentages and °C, and whole bytes for rates
  final minInterval = binary ? 1.0 : 0.1;

  if (!peak.isFinite || !trough.isFinite) {
    return binary
        ? (bottom: 0.0, top: 1024.0, interval: 256.0)
        : (bottom: 0.0, top: 1.0, interval: 0.25);
  }

  const targetTicks = 4;
  var lo = trough;
  var hi = peak;

  // A flat line has no span to derive a step from, and taking one from the
  // value's own magnitude pinned it to an edge — a disk sitting at 65.4%
  // produced a 60..80 axis. Give it a span proportional to the value and
  // centre it instead.
  if (hi - lo <= 0) {
    final pad = math.max(hi.abs() * 0.05, minInterval * targetTicks / 2);
    lo -= pad;
    hi += pad;
  }

  final raw = (hi - lo) / targetTicks;

  double interval;
  if (binary) {
    var unit = 1.0;
    while (unit * 1024 <= raw) {
      unit *= 1024;
    }
    const steps = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024];
    final norm = raw / unit;
    interval = steps.firstWhere((s) => s >= norm, orElse: () => 1024) * unit;
  } else {
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    const steps = [1.0, 2.0, 2.5, 5.0, 10.0];
    final norm = raw / mag;
    interval = steps.firstWhere((s) => s >= norm, orElse: () => 10.0) * mag;
  }
  if (interval < minInterval) interval = minInterval;

  // Snap outwards to whole intervals, which is also where the margin around
  // the data comes from. Data that never went negative doesn't get a negative
  // axis: an idle interface reading "-2 B/s" is not a smaller number, it's an
  // impossible one.
  var bottom = (lo / interval).floor() * interval;
  if (trough >= 0 && bottom < 0) bottom = 0;
  var top = (hi / interval).ceil() * interval;
  if (top <= bottom) top = bottom + interval;
  return (bottom: bottom, top: top, interval: interval);
}

/// Width to reserve for the left axis, from the labels it will actually draw.
double _axisWidth(
  double bottom,
  double top,
  double interval,
  String Function(double) format,
) {
  var longest = 0;
  for (var v = bottom; v <= top + interval / 2; v += interval) {
    final len = format(v).length;
    if (len > longest) longest = len;
  }
  // ~7px per glyph at UIs.text12Grey, plus fl_chart's own 8px label gap
  return (longest * 7.0 + 10).clamp(32.0, 72.0);
}

/// Trailing `.0` dropped: with round ticks the axis reads 0/25/50/75/100, and
/// the decimal was only ever noise there
String _formatPercent(double v) =>
    '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}%';
String _formatTemp(double v) =>
    '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}°C';
String _formatSpeed(double bytesPerSec) => '${bytesPerSec.bytes2Str}/s';

String _formatAmdGpuProcessMemory(int rawMemory) {
  final valueInMiB = rawMemory / 1024;
  final formatted = valueInMiB.truncateToDouble() == valueInMiB
      ? valueInMiB.toStringAsFixed(0)
      : valueInMiB.toStringAsFixed(1);
  return '$formatted MiB';
}

extension _ViewUtils on String {
  bool get isSvgUrl {
    final uri = Uri.tryParse(this);
    final path = uri?.path.toLowerCase() ?? toLowerCase();
    return path.endsWith('.svg');
  }
}

enum _NetSortType {
  device,
  trans,
  recv;

  _NetSortType get next {
    switch (this) {
      case device:
        return trans;
      case _NetSortType.trans:
        return recv;
      case recv:
        return device;
    }
  }

  int Function(String, String) getSortFunc(NetSpeed ns) {
    switch (this) {
      case _NetSortType.device:
        return (b, a) => a.compareTo(b);
      // Interfaces with no reading yet sort as slowest rather than jumping
      // around as their first sample lands
      case _NetSortType.recv:
        return (b, a) => (ns.speedInBytes(ns.deviceIdx(a)) ?? -1).compareTo(
          ns.speedInBytes(ns.deviceIdx(b)) ?? -1,
        );
      case _NetSortType.trans:
        return (b, a) => (ns.speedOutBytes(ns.deviceIdx(a)) ?? -1).compareTo(
          ns.speedOutBytes(ns.deviceIdx(b)) ?? -1,
        );
    }
  }
}

/// Shared fl_chart styling for the detail page. X is elapsed seconds from the
/// first real sample, so pauses in polling remain visible on the time axis.
Widget _buildHistoryLineChart(
  List<LineChartBarData> bars, {
  required BuildContext context,
  required List<_HistorySeries> series,
  required List<int> times,
  required String Function(double) format,
  bool binaryScale = false,
}) {
  final measured = bars.expand((b) => b.spots).where((s) => !s.isNull()).toList();
  if (measured.isEmpty) return UIs.placeholder;

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final textScaler = MediaQuery.textScalerOf(context);
  final labelStyle = theme.textTheme.bodySmall?.copyWith(fontSize: 10);
  final peak = measured.map((e) => e.y).reduce(math.max);
  final trough = measured.map((e) => e.y).reduce(math.min);
  final axis = _niceAxis(trough: trough, peak: peak, binary: binaryScale);
  final span = times.length > 1 ? (times.last - times.first) / 1000 : 0.0;
  final maxX = span > 0 ? span : math.max(1.0, measured.last.x);

  String timeLabel(double x, {bool precise = false}) {
    if (times.isEmpty) return '';
    final at = DateTime.fromMillisecondsSinceEpoch(times.first + (x * 1000).round());
    String pad(int n) => n.toString().padLeft(2, '0');
    final hm = '${pad(at.hour)}:${pad(at.minute)}';
    return precise || span < 120 ? '$hm:${pad(at.second)}' : hm;
  }

  return LineChart(
    LineChartData(
      minX: 0,
      maxX: maxX,
      minY: axis.bottom,
      maxY: axis.top,
      clipData: const FlClipData.vertical(),
      lineBarsData: bars,
      lineTouchData: LineTouchData(
        touchSpotThreshold: 24,
        getTouchedSpotIndicator: (bar, indexes) => indexes.map((_) =>
          TouchedSpotIndicatorData(
            FlLine(color: scheme.onSurfaceVariant.withValues(alpha: .4),
              strokeWidth: 1, dashArray: [4, 4]),
            FlDotData(getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 4, color: bar.color ?? scheme.primary, strokeWidth: 2,
              strokeColor: scheme.surface,
            )),
          ),
        ).toList(),
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          tooltipBorderRadius: BorderRadius.circular(12),
          maxContentWidth: 240,
          fitInsideVertically: true,
          fitInsideHorizontally: true,
          getTooltipColor: (_) => scheme.inverseSurface,
          getTooltipItems: (touchedSpots) => touchedSpots.map((e) {
            final label = e.barIndex < series.length ? series[e.barIndex].label : '';
            return LineTooltipItem(
              '$label  ${format(e.y)}',
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: scheme.onInverseSurface),
              children: [if (times.isNotEmpty) TextSpan(
                text: '\n${timeLabel(e.x, precise: true)}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400,
                  color: scheme.onInverseSurface.withValues(alpha: .75)),
              )],
            );
          }).toList(),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: axis.interval,
        getDrawingHorizontalLine: (_) => FlLine(
          color: scheme.onSurfaceVariant.withValues(alpha: .12),
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: times.length > 1,
          interval: maxX / 2,
          reservedSize: textScaler.scale(10) + 14,
          getTitlesWidget: (val, meta) => SideTitleWidget(
            meta: meta, space: 8,
            fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
            child: Text(timeLabel(val), style: labelStyle, maxLines: 1, softWrap: false),
          ),
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          interval: axis.interval,
          reservedSize: _axisWidth(axis.bottom, axis.top, axis.interval, format)
              * math.max(1.0, textScaler.scale(10) / 12),
          getTitlesWidget: (val, meta) => SideTitleWidget(
            meta: meta, space: 8,
            fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
            child: Text(format(val), style: labelStyle, maxLines: 1, softWrap: false),
          ),
        )),
      ),
      borderData: FlBorderData(show: false),
    ),
    duration: MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero : const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
  );
}
