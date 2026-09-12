import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/ip_lookup.dart';
import 'package:server_box/data/store/ip_lookup_cache.dart';
import 'package:server_box/data/store/tables.dart';

void main() {
  late IpLookupCacheStore store;

  setUp(() async {
    SqliteDb.openInMemory();
    await createTables(SqliteDb.instance);
    store = IpLookupCacheStore('ip_lookup_cache_test');
    await store.init();
  });

  tearDown(() async {
    await closeTables();
    await SqliteDb.close();
  });

  test('returns fresh result and expires it after seven days', () {
    final fetched = DateTime(2026, 9, 1, 12);
    final result = IpLookupResult(
      ip: '8.8.8.8',
      type: 'IPv4',
      organization: 'Google LLC',
      asn: 15169,
      fetchedAt: fetched,
    );

    expect(store.putResult('server-1', result), isTrue);
    expect(
      store
          .fresh(
            'server-1',
            '8.8.8.8',
            now: fetched.add(const Duration(days: 6)),
          )
          ?.organization,
      'Google LLC',
    );
    expect(
      store.fresh(
        'server-1',
        '8.8.8.8',
        now: fetched.add(const Duration(days: 7)),
      ),
      isNull,
    );
  });

  test('forgets only the selected server entries', () {
    final now = DateTime.now();
    store.putResult(
      'server-1',
      IpLookupResult(ip: '8.8.8.8', type: 'IPv4', fetchedAt: now),
    );
    store.putResult(
      'server-2',
      IpLookupResult(ip: '1.1.1.1', type: 'IPv4', fetchedAt: now),
    );

    store.forgetServer('server-1');

    expect(store.fresh('server-1', '8.8.8.8'), isNull);
    expect(store.fresh('server-2', '1.1.1.1'), isNotNull);
  });

  test('an address change invalidates the old address only', () {
    final now = DateTime.now();
    store.putResult(
      'server-1',
      IpLookupResult(ip: '8.8.8.8', type: 'IPv4', fetchedAt: now),
    );
    store.putResult(
      'server-1',
      IpLookupResult(ip: '1.1.1.1', type: 'IPv4', fetchedAt: now),
    );

    store.forgetServerExcept('server-1', '1.1.1.1');

    expect(store.fresh('server-1', '8.8.8.8'), isNull);
    expect(store.fresh('server-1', '1.1.1.1'), isNotNull);
  });
}
