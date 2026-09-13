import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/dns_lookup.dart';
import 'package:server_box/core/service/ip_lookup.dart';
import 'package:server_box/data/model/app/dns_lookup.dart';
import 'package:server_box/data/model/app/ip_lookup.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/ip_lookup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingStore setting;

  setUp(() async {
    SqliteDb.openInMemory();
    setting = SettingStore('ip_lookup_page_setting_test');
    getIt.registerSingleton<SettingStore>(setting);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  testWidgets(
    'asks once for consent then shows dual-stack results in Chinese',
    (tester) async {
      final service = _FakeIpLookupService();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: IpLookupPage(service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('IP 查询隐私说明'), findsOneWidget);
      expect(service.discoveryCalls, 0);

      await tester.tap(find.text('同意并继续'));
      await tester.pumpAndSettle();

      expect(setting.ipLookupConsent.fetch(), isTrue);
      expect(service.discoveryCalls, 1);
      expect(find.text('8.8.8.8'), findsWidgets);
      expect(find.text('2001:4860:4860::8888'), findsWidgets);
      expect(find.text('Google LLC'), findsWidgets);
    },
  );

  testWidgets('rejecting consent leaves without making a request', (
    tester,
  ) async {
    final service = _FakeIpLookupService();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          LibLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => IpLookupPage(service: service),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('IP 查询隐私说明'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(service.discoveryCalls, 0);
    expect(setting.ipLookupConsent.fetch(), isFalse);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('DNS lookup asks separately and shows records with copy', (
    tester,
  ) async {
    setting.ipLookupConsent.put(true);
    final dnsService = _FakeDnsLookupService();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          LibLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: IpLookupPage(
          service: _FakeIpLookupService(),
          dnsService: dnsService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.tap(find.text('DNS 解析'));
    await tester.pumpAndSettle();
    expect(find.text('DNS 查询隐私说明'), findsOneWidget);
    expect(dnsService.calls, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(dnsService.calls, 0);
    expect(setting.dnsLookupConsent.fetch(), isFalse);

    await tester.tap(find.text('DNS 解析'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意并继续'));
    await tester.pumpAndSettle();
    expect(dnsService.calls, 1);
    expect(setting.dnsLookupConsent.fetch(), isTrue);
    await tester.scrollUntilVisible(
      find.text('DNS 解析结果 · example.com'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.text('DNS 解析结果 · example.com'), findsOneWidget);
    expect(find.text('1.1.1.1'), findsOneWidget);
    expect(find.text('TTL 300s'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
  });

  testWidgets('DNS rejects invalid input without requesting consent', (
    tester,
  ) async {
    setting.ipLookupConsent.put(true);
    final dnsService = _FakeDnsLookupService();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          LibLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: IpLookupPage(
          service: _FakeIpLookupService(),
          dnsService: dnsService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'router.local');
    await tester.tap(find.text('DNS 解析'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('有效的公网域名'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.textContaining('有效的公网域名'), findsOneWidget);
    expect(dnsService.calls, 0);
    expect(setting.dnsLookupConsent.fetch(), isFalse);
  });
}

class _FakeDnsLookupService extends DnsLookupService {
  int calls = 0;

  @override
  Future<DnsLookupResult> lookup(String raw, {cancelToken}) async {
    calls++;
    return const DnsLookupResult(
      domain: 'example.com',
      records: [
        DnsRecord(
          name: 'example.com',
          type: DnsRecordType.a,
          value: '1.1.1.1',
          ttl: 300,
        ),
      ],
    );
  }
}

class _FakeIpLookupService extends IpLookupService {
  int discoveryCalls = 0;

  @override
  Future<PublicIpPair> discoverPublicIps({cancelToken}) async {
    discoveryCalls++;
    return PublicIpPair(
      ipv4: PublicIpResult(address: InternetAddress('8.8.8.8')),
      ipv6: PublicIpResult(address: InternetAddress('2001:4860:4860::8888')),
    );
  }

  @override
  Future<IpLookupResult> lookup(
    InternetAddress address, {
    required String languageCode,
    cancelToken,
  }) async => IpLookupResult(
    ip: address.address,
    type: address.type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4',
    country: '美国',
    countryCode: 'US',
    organization: 'Google LLC',
    asn: 15169,
  );
}
