enum DnsRecordType {
  a(1, 'A'),
  aaaa(28, 'AAAA'),
  cname(5, 'CNAME'),
  mx(15, 'MX'),
  ns(2, 'NS'),
  txt(16, 'TXT');

  const DnsRecordType(this.code, this.label);

  final int code;
  final String label;

  static DnsRecordType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

final class DnsRecord {
  const DnsRecord({
    required this.name,
    required this.type,
    required this.value,
    required this.ttl,
  });

  final String name;
  final DnsRecordType type;
  final String value;
  final int ttl;
}

final class DnsLookupResult {
  const DnsLookupResult({
    required this.domain,
    required this.records,
    this.failedTypes = const [],
  });

  final String domain;
  final List<DnsRecord> records;
  final List<DnsRecordType> failedTypes;
}
