import 'package:server_box/data/model/app/service_reachability.dart';
import 'package:server_box/data/model/server/system.dart';

abstract final class ServiceReachability {
  static const urls = {
    ServiceKind.chatGpt: 'https://chatgpt.com/',
    ServiceKind.netflix: 'https://www.netflix.com/',
    ServiceKind.gemini: 'https://gemini.google.com/',
  };

  static String command(SystemType system, Set<ServiceKind> services) {
    final selected = ServiceKind.values.where(services.contains);
    return switch (system) {
      SystemType.windows => selected.map(_powershellProbe).join('; '),
      SystemType.linux || SystemType.bsd => [
        r'''sb_probe() { n="$1"; u="$2"; c=""; if command -v curl >/dev/null 2>&1; then c=$(curl -A "ServerBox reachability check" -L -sS -o /dev/null --connect-timeout 5 --max-time 8 -w '%{http_code}' "$u" 2>/dev/null) || c=""; elif command -v wget >/dev/null 2>&1; then wget -q --spider --timeout=8 --max-redirect=5 "$u" >/dev/null 2>&1 && c=200; fi; case "$c" in 2??|3??) echo "$n=reachable";; *) echo "$n=unreachable";; esac; }''',
        for (final service in selected)
          "sb_probe '${service.name}' '${urls[service]}'",
      ].join('\n'),
    };
  }

  static String _powershellProbe(ServiceKind service) {
    final url = urls[service];
    return "\$ProgressPreference='SilentlyContinue'; try { \$r=Invoke-WebRequest -UseBasicParsing -MaximumRedirection 5 -TimeoutSec 8 -Uri '$url'; if ([int]\$r.StatusCode -ge 200 -and [int]\$r.StatusCode -lt 400) { '${service.name}=reachable' } else { '${service.name}=unreachable' } } catch { '${service.name}=unreachable' }";
  }

  static Map<ServiceKind, ServiceReachabilityResult> parse(
    String output, {
    DateTime? checkedAt,
  }) {
    final at = checkedAt ?? DateTime.now();
    final result = <ServiceKind, ServiceReachabilityResult>{};
    for (final line in output.split(RegExp(r'[\r\n]+'))) {
      final pieces = line.trim().split('=');
      if (pieces.length != 2) continue;
      ServiceKind? service;
      for (final candidate in ServiceKind.values) {
        if (candidate.name == pieces[0]) service = candidate;
      }
      if (service == null) continue;
      final state = switch (pieces[1]) {
        'reachable' => ServiceReachabilityState.reachable,
        'unreachable' => ServiceReachabilityState.unreachable,
        _ => ServiceReachabilityState.unknown,
      };
      result[service] = ServiceReachabilityResult(
        service: service,
        state: state,
        checkedAt: at,
      );
    }
    return result;
  }
}
