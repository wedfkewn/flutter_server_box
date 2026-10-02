import 'package:flutter/material.dart';
import 'package:server_box/data/model/app/external_probe.dart';

bool probeChinese(BuildContext context) => Localizations.localeOf(context).languageCode == 'zh';
String probeText(BuildContext context, String zh, String en) => probeChinese(context) ? zh : en;

String probeCategoryLabel(BuildContext context, ProbeCategory category) {
  final zh = probeChinese(context);
  return switch (category) {
    ProbeCategory.ai => zh ? 'AI 服务' : 'AI',
    ProbeCategory.media => zh ? '视频与音乐' : 'Media',
    ProbeCategory.social => zh ? '社交与通信' : 'Social',
    ProbeCategory.developer => zh ? '开发与下载' : 'Developer',
    ProbeCategory.general => zh ? '搜索与常用' : 'General',
    ProbeCategory.custom => zh ? '自定义' : 'Custom',
  };
}

String probeReasonLabel(BuildContext context, String reason) {
  final pair = switch (reason) {
    'httpResponse' => ('网站响应', 'Website responded'),
    'tcpConnected' => ('端口可连接', 'Port connected'),
    'authentication' => ('需要认证', 'Authentication required'),
    'accessDenied' => ('请求被拒绝，限制原因待确认', 'Request denied; restriction unconfirmed'),
    'rateLimited' => ('请求限流，请稍后重试', 'Rate limited; retry later'),
    'serviceError' => ('服务端异常', 'Service error'),
    'unexpectedStatus' => ('响应状态不符合预期', 'Unexpected HTTP status'),
    'keywordMismatch' => ('响应未包含预期关键词', 'Expected keyword not found'),
    'responseTooLarge' => ('响应超出关键词检测上限', 'Response exceeds keyword check limit'),
    'dns' => ('DNS 解析失败', 'DNS resolution failed'),
    'connection' => ('连接失败', 'Connection failed'),
    'tls' => ('TLS 验证或握手失败', 'TLS verification or handshake failed'),
    'timeout' => ('请求超时', 'Request timed out'),
    'redirects' => ('重定向次数过多', 'Too many redirects'),
    'redirect' => ('收到重定向响应', 'Redirect response'),
    'missingTool' => ('服务器未安装 curl', 'curl is not installed on the server'),
    'toolError' => ('检测工具不可用', 'Probe tool unavailable'),
    'transportError' => ('服务器连接或检测请求失败', 'Server connection or probe request failed'),
    'invalidResponse' => ('未收到有效检测结果', 'No valid probe result'),
    'legacyResult' => ('旧版检测结果，建议重新检测查看原因', 'Legacy result; check again for diagnostics'),
    'agentUpgrade' => ('Monitor 版本过旧，请升级', 'Update the Monitor agent to use this feature'),
    'permission' => ('自定义检测需要 Monitor 完整访问权限', 'Custom checks require Monitor full access'),
    'busy' => ('检测队列繁忙，请稍后重试', 'Probe queue busy; retry later'),
    _ => ('网络检测失败，原因未确认', 'Network check failed; cause unconfirmed'),
  };
  return probeChinese(context) ? pair.$1 : pair.$2;
}

String probeStateLabel(BuildContext context, ProbeResult? result, {bool tcp = false}) {
  if (result == null) return probeText(context, '未检测', 'Not checked');
  return switch (result.state) {
    ProbeState.reachable => probeText(context, tcp ? '端口可达' : '网站响应', tcp ? 'Port reachable' : 'Website responded'),
    ProbeState.rejected => switch (result.reason) {
      'authentication' => probeText(context, '需要认证', 'Authentication required'),
      'accessDenied' => probeText(context, '请求被拒绝', 'Request denied'),
      'rateLimited' => probeText(context, '请求限流', 'Rate limited'),
      'serviceError' => probeText(context, '服务异常', 'Service error'),
      'keywordMismatch' => probeText(context, '关键词不符', 'Keyword mismatch'),
      _ => probeText(context, '响应异常', 'Unexpected response'),
    },
    ProbeState.unknown => probeText(context, '待确认', 'Inconclusive'),
  };
}

Color probeColor(BuildContext context, ProbeResult? result) =>
  result != null && !result.isFresh(DateTime.now())
  ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .65)
  : switch (result?.state) {
  ProbeState.reachable => Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff91cf96) : const Color(0xff276b31),
  ProbeState.rejected => Theme.of(context).colorScheme.error,
  ProbeState.unknown || null => Theme.of(context).colorScheme.onSurfaceVariant,
};
