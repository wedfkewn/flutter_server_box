import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/service_reachability.dart';
import 'package:server_box/data/model/app/service_reachability.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/store/service_reachability_cache.dart';
import 'package:server_box/data/store/tables.dart';

void main() {
  group('probe command and output', () {
    test('uses only fixed URLs for selected Unix services', () {
      final command = ServiceReachability.command(SystemType.linux, {
        ServiceKind.chatGpt,
        ServiceKind.gemini,
      });
      expect(command, contains('https://chatgpt.com/'));
      expect(command, contains('https://gemini.google.com/'));
      expect(command, isNot(contains('netflix.com')));
      expect(command, contains('--max-time 8'));
    });

    test('builds a PowerShell probe and parses tolerant output', () {
      final command = ServiceReachability.command(SystemType.windows, {
        ServiceKind.netflix,
      });
      expect(command, contains('Invoke-WebRequest'));
      expect(command, contains('https://www.netflix.com/'));

      final result = ServiceReachability.parse(
        'noise\nchatGpt=reachable\r\nnetflix=unreachable\n',
        checkedAt: DateTime(2026),
      );
      expect(result[ServiceKind.chatGpt]?.reachable, isTrue);
      expect(result[ServiceKind.netflix]?.reachable, isFalse);
      expect(result, isNot(contains(ServiceKind.gemini)));
    });
  });

  group('derived cache', () {
    late ServiceReachabilityCacheStore store;

    setUp(() async {
      SqliteDb.openInMemory();
      await createTables(SqliteDb.instance);
      store = ServiceReachabilityCacheStore('service_reachability_test');
      await store.init();
    });

    tearDown(() async {
      await closeTables();
      await SqliteDb.close();
    });

    test('keeps success for 24 hours and failure for one hour', () {
      final at = DateTime(2026, 9, 12);
      store.put(
        'one',
        'host',
        ServiceReachabilityResult(
          service: ServiceKind.chatGpt,
          state: ServiceReachabilityState.reachable,
          checkedAt: at,
        ),
      );
      store.put(
        'one',
        'host',
        ServiceReachabilityResult(
          service: ServiceKind.netflix,
          state: ServiceReachabilityState.unreachable,
          checkedAt: at,
        ),
      );
      expect(
        store.fresh(
          'one',
          'host',
          ServiceKind.chatGpt,
          now: at.add(const Duration(hours: 23)),
        ),
        isNotNull,
      );
      expect(
        store.fresh(
          'one',
          'host',
          ServiceKind.netflix,
          now: at.add(const Duration(hours: 1)),
        ),
        isNull,
      );
    });

    test('separates targets and forgets a server', () {
      final result = ServiceReachabilityResult(
        service: ServiceKind.gemini,
        state: ServiceReachabilityState.reachable,
        checkedAt: DateTime.now(),
      );
      store.put('one', 'old-host', result);
      store.put('one', 'new-host', result);
      store.forgetServer('one');
      expect(store.fresh('one', 'old-host', ServiceKind.gemini), isNull);
      expect(store.fresh('one', 'new-host', ServiceKind.gemini), isNull);
    });
  });
}
