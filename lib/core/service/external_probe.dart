import 'dart:convert';
import 'dart:typed_data';

import 'package:server_box/data/model/app/external_probe.dart';
import 'package:server_box/data/model/server/system.dart';

/// Produces commands exclusively from validated data, quoting every value.
/// The app never probes public services from the phone's own network.
abstract final class ExternalProbe {
  static String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
  static String psQuote(String value) => "'${value.replaceAll("'", "''")}'";

  /// Explicitly select PowerShell even when Windows OpenSSH defaults to cmd.
  /// Only this short bootstrap goes on the command line; the validated probe
  /// script travels as a UTF-8/base64 line on stdin, preserving keywords without
  /// cmd's size cap. Read one complete line rather than waiting for channel EOF.
  static String get windowsEntry {
    const bootstrap = '[Console]::OutputEncoding=[Text.UTF8Encoding]::new(); '
      'Invoke-Expression ([Text.Encoding]::UTF8.GetString('
      '[Convert]::FromBase64String([Console]::ReadLine())))';
    final bytes = ByteData(bootstrap.length * 2);
    for (var i = 0; i < bootstrap.length; i++) {
      bytes.setUint16(i * 2, bootstrap.codeUnitAt(i), Endian.little);
    }
    return 'powershell.exe -NoProfile -NonInteractive -EncodedCommand '
      '${base64.encode(bytes.buffer.asUint8List())}';
  }

  static String windowsInput(List<ProbeTarget> targets) =>
    base64.encode(utf8.encode(command(SystemType.windows, targets)));

  static String command(SystemType system, List<ProbeTarget> targets) {
    if (targets.isEmpty || targets.length > 3 ||
        targets.any((e) => e.validationError != null)) {
      throw ArgumentError('Invalid probe batch');
    }
    if (system == SystemType.windows) return targets.map(_powershell).join(';\n');
    return '${targets.map((e) => '(\n${_unix(e)}\n) &').join('\n')}\nwait';
  }

  static String _unix(ProbeTarget target) {
    final uri = Uri.parse(target.address);
    final address = target.protocol == ProbeProtocol.tcp
      ? 'telnet://${uri.host.contains(':') ? '[${uri.host}]' : uri.host}:${uri.port}'
      : target.address;
    final needsBody = target.keyword.isNotEmpty && target.protocol == ProbeProtocol.http;
    return '''
if ! command -v curl >/dev/null 2>&1; then
  printf '%s|127|000|0||-1\\n' ${quote(target.id)}; exit 0
fi
body=/dev/null
${needsBody ? '''body=\$(mktemp) || { printf '%s|126|000|0||-1\\n' ${quote(target.id)}; exit 0; }
trap 'rm -f "\$body"' EXIT HUP INT TERM''' : ''}
o=\$(curl -sS ${target.followRedirects ? '-L --max-redirs 5' : ''} ${target.method == 'HEAD' && target.protocol == ProbeProtocol.http ? '--head' : ''} --connect-timeout 5 --max-time ${target.timeoutSeconds} ${needsBody ? '--max-filesize 65536' : ''} -A 'ServerBox external service check' -o "\$body" -w '%{http_code}|%{${target.protocol == ProbeProtocol.tcp ? 'time_connect' : 'time_total'}}|%{remote_ip}' -- ${quote(address)} 2>/dev/null); rc=\$?
k=-1
${needsBody ? 'if LC_ALL=C grep -F -q -- ${quote(target.keyword)} "\$body"; then k=1; else k=0; fi' : ''}
printf '%s|%s|%s|%s\\n' ${quote(target.id)} "\$rc" "\$o" "\$k"
''';
  }

  static String _powershell(ProbeTarget target) {
    final uri = Uri.parse(target.address);
    final header = '''
function sb_failure_code(\$sbError) {
  while (\$null -ne \$sbError) {
    if (\$sbError -is [Net.Sockets.SocketException] -and
        \$sbError.SocketErrorCode -in @([Net.Sockets.SocketError]::HostNotFound,[Net.Sockets.SocketError]::NoData,[Net.Sockets.SocketError]::TryAgain)) { return 6 }
    if (\$sbError -is [Security.Authentication.AuthenticationException]) { return 35 }
    if (\$sbError -is [OperationCanceledException]) { return 28 }
    \$sbError=\$sbError.InnerException
  }
  return 7
}
\$sbId=${psQuote(target.id)}; \$sbRc=0; \$sbStatus=0; \$sbIp=''; \$sbKeyword=-1; \$sbWatch=[Diagnostics.Stopwatch]::StartNew();''';
    if (target.protocol == ProbeProtocol.tcp) {
      return '''$header
\$sbTcp=[Net.Sockets.TcpClient]::new(); try {
  \$sbTask=\$sbTcp.ConnectAsync(${psQuote(uri.host)},${uri.port});
  if (!\$sbTask.Wait(${target.timeoutSeconds * 1000})) { \$sbRc=28 }
  elseif (\$sbTcp.Connected) { \$sbIp=\$sbTcp.Client.RemoteEndPoint.Address.ToString() }
  else { \$sbRc=7 }
} catch { \$sbRc=sb_failure_code \$_.Exception } finally { \$sbTcp.Dispose() }
\$sbWatch.Stop(); Write-Output (\$sbId+'|'+\$sbRc+'|0|'+(\$sbWatch.Elapsed.TotalSeconds.ToString('F3',[Globalization.CultureInfo]::InvariantCulture))+'|'+\$sbIp+'|-1');''';
    }
    return '''$header
Add-Type -AssemblyName System.Net.Http
\$sbHandler=[Net.Http.HttpClientHandler]::new(); \$sbHandler.AllowAutoRedirect=\$${target.followRedirects ? 'true' : 'false'}; \$sbHandler.MaxAutomaticRedirections=5;
\$sbHttp=[Net.Http.HttpClient]::new(\$sbHandler); \$sbHttp.Timeout=[TimeSpan]::FromSeconds(${target.timeoutSeconds});
\$sbCancel=[Threading.CancellationTokenSource]::new(${target.timeoutSeconds * 1000});
\$sbRequest=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new(${psQuote(target.method)}),${psQuote(target.address)});
\$sbResponse=\$null; try {
  \$sbRequest.Headers.UserAgent.ParseAdd('ServerBox');
  \$sbResponse=\$sbHttp.SendAsync(\$sbRequest,[Net.Http.HttpCompletionOption]::ResponseHeadersRead,\$sbCancel.Token).GetAwaiter().GetResult();
  \$sbStatus=[int]\$sbResponse.StatusCode;
  ${target.keyword.isNotEmpty ? '''\$sbStream=\$sbResponse.Content.ReadAsStreamAsync().GetAwaiter().GetResult();
  \$sbMemory=[IO.MemoryStream]::new(); \$sbBuffer=New-Object byte[] 4096;
  try {
    while ((\$sbCount=\$sbStream.ReadAsync(\$sbBuffer,0,\$sbBuffer.Length,\$sbCancel.Token).GetAwaiter().GetResult()) -gt 0) {
      if (\$sbMemory.Length+\$sbCount -gt 65536) { \$sbRc=63; break }
      \$sbMemory.Write(\$sbBuffer,0,\$sbCount)
    }
    \$sbKeyword=[int]([Text.Encoding]::UTF8.GetString(\$sbMemory.ToArray()).Contains(${psQuote(target.keyword)}))
  } finally { \$sbStream.Dispose(); \$sbMemory.Dispose() }''' : ''}
} catch {
  if (\$sbCancel.IsCancellationRequested) { \$sbRc=28 } else { \$sbRc=sb_failure_code \$_.Exception }
} finally {
  if (\$null -ne \$sbResponse) { \$sbResponse.Dispose() }
  \$sbRequest.Dispose(); \$sbCancel.Dispose(); \$sbHttp.Dispose(); \$sbHandler.Dispose()
}
\$sbWatch.Stop(); Write-Output (\$sbId+'|'+\$sbRc+'|'+\$sbStatus+'|'+(\$sbWatch.Elapsed.TotalSeconds.ToString('F3',[Globalization.CultureInfo]::InvariantCulture))+'||'+\$sbKeyword);''';
  }

  static ProbeResult classify(ProbeTarget target, {required int exitCode,
    int? status, int? elapsedMs, String? remoteIp, int keywordMatch = -1,
    DateTime? checkedAt, String transport = 'SSH'}) {
    var state = ProbeState.unknown;
    var reason = switch (exitCode) {
      6 => 'dns', 7 => 'connection', 28 => 'timeout',
      35 || 51 || 60 => 'tls', 47 => 'redirects', 63 => 'responseTooLarge',
      127 => 'missingTool', 126 => 'toolError', _ => 'network',
    };
    if (target.protocol == ProbeProtocol.tcp &&
        ((exitCode == 0 && remoteIp?.isNotEmpty == true) ||
         (exitCode == 28 && (elapsedMs ?? 0) > 0 && remoteIp?.isNotEmpty == true))) {
      state = ProbeState.reachable;
      reason = 'tcpConnected';
    } else if (exitCode == 0 && target.protocol == ProbeProtocol.http &&
        status != null && status >= 100 && status <= 599) {
      if (status >= target.statusMin && status <= target.statusMax) {
        if (target.keyword.isNotEmpty && keywordMatch == -1) {
          reason = 'invalidResponse';
        } else {
          state = target.keyword.isEmpty || keywordMatch == 1
            ? ProbeState.reachable : ProbeState.rejected;
          reason = state == ProbeState.reachable ? 'httpResponse' : 'keywordMismatch';
        }
      } else {
        state = ProbeState.rejected;
        reason = switch (status) {
          401 => 'authentication', 403 => 'accessDenied', 429 => 'rateLimited',
          >= 500 => 'serviceError', >= 300 && < 400 => 'redirect',
          _ => 'unexpectedStatus',
        };
      }
    }
    return ProbeResult(id: target.id, state: state, reason: reason,
      checkedAt: checkedAt ?? DateTime.now(), httpStatus: status == 0 ? null : status,
      elapsedMs: elapsedMs, remoteIp: remoteIp?.isEmpty == true ? null : remoteIp,
      transport: transport);
  }

  static Map<String, ProbeResult> parse(String output, List<ProbeTarget> requested) {
    final byId = {for (final target in requested) target.id: target};
    final results = <String, ProbeResult>{};
    for (final line in output.split(RegExp(r'[\r\n]+'))) {
      final parts = line.trim().split('|');
      if (parts.length != 6 || !byId.containsKey(parts.first)) continue;
      final exit = int.tryParse(parts[1]);
      final elapsed = double.tryParse(parts[3]);
      if (exit == null || elapsed == null || !elapsed.isFinite || elapsed < 0) continue;
      results[parts.first] = classify(byId[parts.first]!, exitCode: exit,
        status: int.tryParse(parts[2]), elapsedMs: byId[parts.first]!.protocol == ProbeProtocol.tcp
          ? (elapsed * 1000).ceil() : (elapsed * 1000).round(),
        remoteIp: parts[4], keywordMatch: int.tryParse(parts[5]) ?? -1);
    }
    return results;
  }
}
