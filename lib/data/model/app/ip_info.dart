import 'package:freezed_annotation/freezed_annotation.dart';

part 'ip_info.freezed.dart';
part 'ip_info.g.dart';

@freezed
abstract class IpInfo with _$IpInfo {
  const factory IpInfo({
    required String ip,
    String? hostname,
    String? city,
    String? region,
    String? country,
    String? loc,
    String? org,
    String? postal,
    String? timezone,
  }) = _IpInfo;

  factory IpInfo.fromJson(Map<String, dynamic> json) => _$IpInfoFromJson(json);
}
