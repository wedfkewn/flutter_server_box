/// Build-time source identity; an empty value means a local/unverified build.
abstract final class SourceProvenance {
  static const commit = String.fromEnvironment('SOURCE_COMMIT');
  static const repository = String.fromEnvironment('SOURCE_REPOSITORY');
  static const modifiedDate = String.fromEnvironment('SOURCE_MODIFIED_DATE');
  static const upstream = 'https://github.com/lollipopkit/flutter_server_box';
  static const fork = 'https://github.com/wedfkewn/flutter_server_box';

  static String? get exactSource =>
      RegExp(r'^[0-9a-f]{40}$').hasMatch(commit) &&
          RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository)
      ? 'https://github.com/$repository/tree/$commit'
      : null;

  static const networkReferences = [
    OpenSourceReference(
      name: 'lmc999/RegionRestrictionCheck',
      license: 'AGPL-3.0',
      purpose: 'Streaming and regional reachability check rules',
      url:
          'https://github.com/lmc999/RegionRestrictionCheck/tree/b6d4a6f9a87fc6eae6d3e62d0092ececcec8e844',
    ),
    OpenSourceReference(
      name: 'xykt/IPQuality',
      license: 'AGPL-3.0',
      purpose: 'IP quality and service availability report structure',
      url:
          'https://github.com/xykt/IPQuality/tree/ad222ab16778be2a13a174cd1acbd69fb4cac6b7',
    ),
    OpenSourceReference(
      name: 'bitscoper/bitscoper_cyberkit',
      license: 'GPL-3.0',
      purpose: 'Flutter network-tool organization for DNS and diagnostics',
      url:
          'https://github.com/bitscoper/bitscoper_cyberkit/tree/6310ffb85c97aac0b0e332c435cba9ee2d93d680',
    ),
  ];
}

final class OpenSourceReference {
  const OpenSourceReference({
    required this.name,
    required this.license,
    required this.purpose,
    required this.url,
  });

  final String name;
  final String license;
  final String purpose;
  final String url;
}
