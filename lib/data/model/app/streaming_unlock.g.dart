// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streaming_unlock.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StreamingUnlockStatus _$StreamingUnlockStatusFromJson(
  Map<String, dynamic> json,
) => _StreamingUnlockStatus(
  netflixUnlocked: json['netflixUnlocked'] as bool,
  netflixRegion: json['netflixRegion'] as String?,
  chatgptUnlocked: json['chatgptUnlocked'] as bool,
  chatgptRegion: json['chatgptRegion'] as String?,
  lastCheckTime: json['lastCheckTime'] == null
      ? null
      : DateTime.parse(json['lastCheckTime'] as String),
);

Map<String, dynamic> _$StreamingUnlockStatusToJson(
  _StreamingUnlockStatus instance,
) => <String, dynamic>{
  'netflixUnlocked': instance.netflixUnlocked,
  'netflixRegion': instance.netflixRegion,
  'chatgptUnlocked': instance.chatgptUnlocked,
  'chatgptRegion': instance.chatgptRegion,
  'lastCheckTime': instance.lastCheckTime?.toIso8601String(),
};

_StreamingUnlockCheckResult _$StreamingUnlockCheckResultFromJson(
  Map<String, dynamic> json,
) => _StreamingUnlockCheckResult(
  isUnlocked: json['isUnlocked'] as bool,
  region: json['region'] as String?,
  service: $enumDecode(_$StreamingServiceEnumMap, json['service']),
);

Map<String, dynamic> _$StreamingUnlockCheckResultToJson(
  _StreamingUnlockCheckResult instance,
) => <String, dynamic>{
  'isUnlocked': instance.isUnlocked,
  'region': instance.region,
  'service': _$StreamingServiceEnumMap[instance.service]!,
};

const _$StreamingServiceEnumMap = {
  StreamingService.netflix: 'netflix',
  StreamingService.chatgpt: 'chatgpt',
};
