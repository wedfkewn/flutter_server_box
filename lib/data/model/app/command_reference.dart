/// Authored offline documentation, never an executable snippet or a shell job.
typedef CommandText = (String zh, String en);

extension CommandTextLocale on CommandText {
  String localized(bool chinese) => chinese ? $1 : $2;
}

enum CommandCategory {
  files(('文件与文本', 'Files and text')),
  system(('系统与进程', 'System and processes')),
  network(('网络与连接', 'Network and connections')),
  services(('服务与日志', 'Services and logs')),
  docker(('Docker', 'Docker')),
  git(('Git', 'Git'));
  const CommandCategory(this.label);
  final CommandText label;
}

class CommandOption {
  const CommandOption(this.flag, this.description);
  final String flag;
  final CommandText description;
}

class CommandExample {
  const CommandExample(this.code, this.description);
  final String code;
  final CommandText description;
}

class CommandReference {
  const CommandReference(this.name, this.category, this.summary, this.syntax,
    this.requirements, this.source, this.options, this.examples);
  final String name, syntax, source;
  final CommandCategory category;
  final CommandText summary, requirements;
  final List<CommandOption> options;
  final List<CommandExample> examples;
  bool matches(String query) {
    final terms = [name, summary.$1, summary.$2, category.label.$1, category.label.$2,
      for (final option in options) '${option.flag} ${option.description.$1} ${option.description.$2}',
      for (final example in examples) '${example.description.$1} ${example.description.$2}'];
    return terms.join(' ').toLowerCase().contains(query.trim().toLowerCase());
  }
}
