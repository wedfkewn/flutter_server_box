import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// The requested one-time opt-in; subsequent launches preserve the switches.
class BrandLogosMigration implements SchemaMigration {
  const BrandLogosMigration({SettingStore? store}) : _store = store;
  final SettingStore? _store;
  @override
  int get from => 23;
  @override
  Future<void> apply() async {
    final store = _store ?? SettingStore.instance;
    if (store.get<bool>('brandLogosEnabledV1') == true) return;
    for (final key in ['showDistMark', 'showProgramLogos', 'brandLogosEnabledV1']) {
      if (!store.set(key, true, updateLastUpdateTsOnSet: false)) {
        throw StateError('m023: writing $key failed');
      }
    }
  }
}
