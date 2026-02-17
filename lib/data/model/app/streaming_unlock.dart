import 'package:freezed_annotation/freezed_annotation.dart';

part 'streaming_unlock.freezed.dart';
part 'streaming_unlock.g.dart';

enum StreamingService { netflix, chatgpt }

@freezed
abstract class StreamingUnlockStatus with _$StreamingUnlockStatus {
  const factory StreamingUnlockStatus({
    required bool netflixUnlocked,
    String? netflixRegion,
    required bool chatgptUnlocked,
    String? chatgptRegion,
    DateTime? lastCheckTime,
  }) = _StreamingUnlockStatus;

  factory StreamingUnlockStatus.fromJson(Map<String, dynamic> json) =>
      _$StreamingUnlockStatusFromJson(json);
}

@freezed
abstract class StreamingUnlockCheckResult with _$StreamingUnlockCheckResult {
  const factory StreamingUnlockCheckResult({
    required bool isUnlocked,
    String? region,
    required StreamingService service,
  }) = _StreamingUnlockCheckResult;

  factory StreamingUnlockCheckResult.fromJson(Map<String, dynamic> json) =>
      _$StreamingUnlockCheckResultFromJson(json);
}
