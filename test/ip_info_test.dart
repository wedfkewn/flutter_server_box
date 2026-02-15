import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/provider/ip_info.dart';

void main() {
  test('ipInfoProvider fetches data correctly', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Test 1: US IP (Google DNS)
    final us = await container.read(ipInfoProvider('8.8.8.8').future);
    expect(us?.country, 'US');

    // Test 2: CN IP (AliDNS)
    final cn = await container.read(ipInfoProvider('223.5.5.5').future);
    expect(cn?.country, 'CN');
  });
}
