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
}
