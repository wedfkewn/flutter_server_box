// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ip_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IpInfo _$IpInfoFromJson(Map<String, dynamic> json) => _IpInfo(
  ip: json['ip'] as String,
  hostname: json['hostname'] as String?,
  city: json['city'] as String?,
  region: json['region'] as String?,
  country: json['country'] as String?,
  loc: json['loc'] as String?,
  org: json['org'] as String?,
  postal: json['postal'] as String?,
  timezone: json['timezone'] as String?,
);

Map<String, dynamic> _$IpInfoToJson(_IpInfo instance) => <String, dynamic>{
  'ip': instance.ip,
  'hostname': instance.hostname,
  'city': instance.city,
  'region': instance.region,
  'country': instance.country,
  'loc': instance.loc,
  'org': instance.org,
  'postal': instance.postal,
  'timezone': instance.timezone,
};
