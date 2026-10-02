import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/program_logo.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/res/brand_assets.dart';
import 'package:server_box/data/store/migrations/m023_brand_logos.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('executable paths, versions and aliases match without searching arguments', () {
    for (final name in ['python', 'python3.12', '/usr/bin/python3.11 -m http.server']) {
      expect(resolveProgramLogo(name), bundledProgramLogos['python']);
    }
    expect(resolveProgramLogo('"C:\\Program Files\\Python\\python.exe" app.py'), bundledProgramLogos['python']);
    expect(resolveProgramLogo('nginx: worker process'), bundledProgramLogos['nginx']);
    expect(resolveProgramLogo('mysqld'), bundledProgramLogos['mysql']);
    expect(resolveProgramLogo('redis-server'), bundledProgramLogos['redis']);
    expect(resolveProgramLogo('sh /tmp/nginx'), isNull);
    expect(resolveProgramLogo('my-nginx-backup'), isNull);
    expect(resolveProgramLogo(''), isNull);
  });

  test('units distinguish services from mount/device identities', () {
    expect(resolveProgramLogo('postgresql@15-main.service', service: true, type: ServiceUnitType.service), bundledProgramLogos['postgresql']);
    expect(resolveProgramLogo('docker.socket', service: true, type: ServiceUnitType.socket), bundledProgramLogos['docker']);
    expect(resolveProgramLogo('nginx', service: true, type: ServiceUnitType.mount), isNull);
    expect(resolveProgramLogo('php8.3-fpm.service', service: true, type: ServiceUnitType.service), bundledProgramLogos['php']);
  });

  test('custom exact rules win and invalid icon ids fall back', () {
    expect(resolveProgramLogo('my-api.service', service: true, type: ServiceUnitType.service,
      overrides: {'my-api': 'python'}), bundledProgramLogos['python']);
    expect(resolveProgramLogo('/usr/bin/nginx', overrides: {'nginx': 'https://example.com/logo.png'}), 'https://example.com/logo.png');
    expect(resolveProgramLogo('nginx', overrides: {'nginx': 'removed-icon'}), bundledProgramLogos['nginx']);
  });

  test('common distros have original artwork and unknown ones retain fallback', () {
    for (final distro in [Dist.ubuntu, Dist.debian, Dist.fedora, Dist.arch, Dist.opensuse, Dist.alpine, Dist.rocky, Dist.mint]) {
      expect(File(distro.markAsset!).existsSync(), isTrue);
    }
    expect(Dist.coreelec.markAsset, isNull);
  });

  test('every vendored SVG has provenance, exact bytes and drawable geometry', () async {
    final manifest = jsonDecode(File('assets/brands/manifest.json').readAsStringSync()) as List;
    final used = {...bundledProgramLogos.values, ...bundledDistroLogos.values};
    expect(manifest.map((e) => e['asset']).toSet(), used);
    for (final raw in manifest) {
      final path = raw['asset'] as String;
      expect(sha256.convert(File(path).readAsBytesSync()).toString(), raw['sha256'], reason: path);
      expect(raw['source'], contains(raw['commit']));
      final svg = await rootBundle.loadString(path);
      final picture = parseWithoutOptimizers(svg, key: path);
      expect(picture.paths, isNotEmpty, reason: path);
      expect(picture.paints, isNotEmpty, reason: path);
    }
  });

  group('v23 migration and settings serialization', () {
    late SettingStore store;
    setUp(() async { await openTestDb(); store = SettingStore('logo_test')..init(); });
    tearDown(closeTestDb);

    test('enables once while preserving authentic prior-release configuration', () async {
      final fixture = jsonDecode(File('test/fixtures/brand_logos_v23/settings.json').readAsStringSync()) as Map;
      for (final entry in fixture.entries) { store.set(entry.key as String, entry.value); }
      final before = store.get<Object>('serverMarkUrl');
      await BrandLogosMigration(store: store).apply();
      expect(store.showDistMark.fetch(), isTrue);
      expect(store.showProgramLogos.fetch(), isTrue);
      expect(store.get<Object>('serverMarkUrl'), before);
      expect(store.distNameMap.fetch(), {'arch': 'archlinux'});
      store.showDistMark.put(false);
      store.showProgramLogos.put(false);
      await BrandLogosMigration(store: store).apply();
      expect(store.showDistMark.fetch(), isFalse);
      expect(store.showProgramLogos.fetch(), isFalse);
    });

    test('global maps survive JSON storage without colliding', () {
      store.processLogoMap.put({'my-api': 'python'});
      store.serviceLogoMap.put({'my-api': 'nginx'});
      final restored = SettingStore('logo_test')..init();
      expect(restored.processLogoMap.fetch(), {'my-api': 'python'});
      expect(restored.serviceLogoMap.fetch(), {'my-api': 'nginx'});
      expect(jsonDecode(jsonEncode(store.get<Object>('processLogoMap'))), {'my-api': 'python'});
    });
  });
}
