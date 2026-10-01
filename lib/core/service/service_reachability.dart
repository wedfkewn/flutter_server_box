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
        // A transport failure is not an HTTP rejection. Keep unknown separate
        // so a missing tool, DNS failure or timeout cannot label a service
        // blocked. wget returns nonzero for HTTP errors too, so read its final
        // response status rather than treating every unsuccessful exit alike.
        r'''sb_probe() {
  n="$1"; u="$2"; c=""
  if command -v curl >/dev/null 2>&1; then
    c=$(curl -A "ServerBox reachability check" -L -sS -o /dev/null --connect-timeout 5 --max-time 8 -w '%{http_code}' "$u" 2>/dev/null) || c=""
  elif command -v wget >/dev/null 2>&1; then
    o=$(wget -S --spider --timeout=8 --max-redirect=5 "$u" 2>&1); r=$?
    c=$(printf '%s\n' "$o" | {
      c=""
      while read -r protocol status rest; do
        case "$protocol" in HTTP/*) c="$status";; esac
      done
      printf '%s' "$c"
    })
    if [ "$r" -ne 0 ]; then
      case "$c" in [23][0-9][0-9]) c="";; esac
    fi
  fi
  case "$c" in
    [23][0-9][0-9]) echo "$n=reachable";;
    [145][0-9][0-9]) echo "$n=unreachable";;
    *) echo "$n=unknown";;
  esac
}''',
        for (final service in selected)
          "sb_probe '${service.name}' '${urls[service]}'",
      ].join('\n'),
    };
  }

  static String _powershellProbe(ServiceKind service) {
    final url = urls[service];
    // Invoke-WebRequest throws for HTTP 4xx/5xx as well as DNS/TLS/timeouts.
    // Only an exception carrying an actual response can tell us the service
    // rejected the request; no response means the check is inconclusive.
    return "\$ProgressPreference='SilentlyContinue'; \$sb_status=\$null; try { \$r=Invoke-WebRequest -UseBasicParsing -MaximumRedirection 5 -TimeoutSec 8 -ErrorAction Stop -Uri '$url'; \$sb_status=[int]\$r.StatusCode } catch { if (\$null -ne \$_.Exception.Response) { \$sb_status=[int]\$_.Exception.Response.StatusCode } }; if (\$null -eq \$sb_status -or \$sb_status -lt 100 -or \$sb_status -gt 599) { '${service.name}=unknown' } elseif (\$sb_status -ge 200 -and \$sb_status -lt 400) { '${service.name}=reachable' } else { '${service.name}=unreachable' }";
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
