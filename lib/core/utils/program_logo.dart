import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/res/brand_assets.dart';

/// Exact executable/unit identity, never a search through command arguments.
String programLogoKey(String name, {bool service = false}) {
  var value = name.trim().toLowerCase();
  if (service) {
    value = value.replaceFirst(RegExp(r'\.(service|socket)$'), '');
    return value.split('@').first;
  }
  if (value.startsWith('"') || value.startsWith("'")) {
    final end = value.indexOf(value[0], 1);
    if (end > 0) value = value.substring(1, end);
  } else {
    value = value.split(RegExp(r'\s+')).first;
  }
  return value.replaceAll('\\', '/').split('/').last.replaceFirst(RegExp(r'\.exe$'), '').replaceFirst(RegExp(r':$'), '');
}

String? resolveProgramLogo(String name, {
  bool service = false,
  ServiceUnitType? type,
  Map<String, String> overrides = const {},
}) {
  final key = programLogoKey(name, service: service);
  final custom = overrides[key];
  if (custom != null) {
    if (custom.startsWith('https://')) return custom;
    final asset = bundledProgramLogos[custom];
    if (asset != null) return asset;
  }
  if (service && type != ServiceUnitType.service && type != ServiceUnitType.socket) return null;
  var canonical = _aliases[key] ?? key;
  if (RegExp(r'^python(?:\d+(?:\.\d+)*)?$').hasMatch(key)) canonical = 'python';
  if (RegExp(r'^php(?:-fpm)?(?:\d+(?:\.\d+)*)?(?:-fpm)?$').hasMatch(key)) canonical = 'php';
  if (RegExp(r'^postgresql(?:-\d+(?:\.\d+)*)?$').hasMatch(key)) canonical = 'postgresql';
  return bundledProgramLogos[canonical];
}

const _aliases = <String, String>{
  'httpd': 'apache', 'apache2': 'apache', 'node': 'nodejs',
  'mysqld': 'mysql', 'mariadbd': 'mariadb', 'postgres': 'postgresql',
  'redis-server': 'redis', 'redis-sentinel': 'redis', 'mongod': 'mongodb',
  'mongos': 'mongodb', 'dockerd': 'docker', 'rabbitmq-server': 'rabbitmq',
  'grafana-server': 'grafana', 'php-fpm': 'php',
};
