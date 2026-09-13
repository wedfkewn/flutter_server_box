import 'dart:io';

enum IpLookupFailureKind {
  invalidInput,
  privateAddress,
  dns,
  network,
  timeout,
  rateLimited,
  service,
}

final class IpLookupFailure implements Exception {
  const IpLookupFailure(this.kind, [this.detail]);

  final IpLookupFailureKind kind;
  final String? detail;

  @override
  String toString() => detail == null ? kind.name : '${kind.name}: $detail';
}

final class PublicIpResult {
  const PublicIpResult({this.address, this.failure});

  final InternetAddress? address;
  final IpLookupFailure? failure;
  bool get isAvailable => address != null;
}

final class PublicIpPair {
  const PublicIpPair({required this.ipv4, required this.ipv6});

  final PublicIpResult ipv4;
  final PublicIpResult ipv6;
}

final class IpLookupResult {
  const IpLookupResult({
    required this.ip,
    required this.type,
    this.country,
    this.countryCode,
    this.region,
    this.city,
    this.latitude,
    this.longitude,
    this.isp,
    this.organization,
    this.asn,
    this.networkDomain,
    this.timezone,
    this.utcOffset,
    this.flagEmoji,
    this.fetchedAt,
  });

  final String ip;
  final String type;
  final String? country;
  final String? countryCode;
  final String? region;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? isp;
  final String? organization;
  final int? asn;
  final String? networkDomain;
  final String? timezone;
  final String? utcOffset;
  final String? flagEmoji;
  final DateTime? fetchedAt;

  String? get asnLabel => asn == null ? null : 'AS$asn';

  Map<String, Object?> toJson() => {
    'ip': ip,
    'type': type,
    'country': country,
    'countryCode': countryCode,
    'region': region,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'isp': isp,
    'organization': organization,
    'asn': asn,
    'networkDomain': networkDomain,
    'timezone': timezone,
    'utcOffset': utcOffset,
    'flagEmoji': flagEmoji,
    'fetchedAt': fetchedAt?.millisecondsSinceEpoch,
  };

  factory IpLookupResult.fromJson(Map<Object?, Object?> json) => IpLookupResult(
    ip: json['ip'] as String,
    type: json['type'] as String,
    country: json['country'] as String?,
    countryCode: json['countryCode'] as String?,
    region: json['region'] as String?,
    city: json['city'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    isp: json['isp'] as String?,
    organization: json['organization'] as String?,
    asn: (json['asn'] as num?)?.toInt(),
    networkDomain: json['networkDomain'] as String?,
    timezone: json['timezone'] as String?,
    utcOffset: json['utcOffset'] as String?,
    flagEmoji: json['flagEmoji'] as String?,
    fetchedAt: switch (json['fetchedAt']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
  );
}
