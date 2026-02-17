// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'streaming_unlock.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StreamingUnlockStatus {

 bool get netflixUnlocked; String? get netflixRegion; bool get chatgptUnlocked; String? get chatgptRegion; DateTime? get lastCheckTime;
/// Create a copy of StreamingUnlockStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StreamingUnlockStatusCopyWith<StreamingUnlockStatus> get copyWith => _$StreamingUnlockStatusCopyWithImpl<StreamingUnlockStatus>(this as StreamingUnlockStatus, _$identity);

  /// Serializes this StreamingUnlockStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StreamingUnlockStatus&&(identical(other.netflixUnlocked, netflixUnlocked) || other.netflixUnlocked == netflixUnlocked)&&(identical(other.netflixRegion, netflixRegion) || other.netflixRegion == netflixRegion)&&(identical(other.chatgptUnlocked, chatgptUnlocked) || other.chatgptUnlocked == chatgptUnlocked)&&(identical(other.chatgptRegion, chatgptRegion) || other.chatgptRegion == chatgptRegion)&&(identical(other.lastCheckTime, lastCheckTime) || other.lastCheckTime == lastCheckTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,netflixUnlocked,netflixRegion,chatgptUnlocked,chatgptRegion,lastCheckTime);

@override
String toString() {
  return 'StreamingUnlockStatus(netflixUnlocked: $netflixUnlocked, netflixRegion: $netflixRegion, chatgptUnlocked: $chatgptUnlocked, chatgptRegion: $chatgptRegion, lastCheckTime: $lastCheckTime)';
}


}

/// @nodoc
abstract mixin class $StreamingUnlockStatusCopyWith<$Res>  {
  factory $StreamingUnlockStatusCopyWith(StreamingUnlockStatus value, $Res Function(StreamingUnlockStatus) _then) = _$StreamingUnlockStatusCopyWithImpl;
@useResult
$Res call({
 bool netflixUnlocked, String? netflixRegion, bool chatgptUnlocked, String? chatgptRegion, DateTime? lastCheckTime
});




}
/// @nodoc
class _$StreamingUnlockStatusCopyWithImpl<$Res>
    implements $StreamingUnlockStatusCopyWith<$Res> {
  _$StreamingUnlockStatusCopyWithImpl(this._self, this._then);

  final StreamingUnlockStatus _self;
  final $Res Function(StreamingUnlockStatus) _then;

/// Create a copy of StreamingUnlockStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? netflixUnlocked = null,Object? netflixRegion = freezed,Object? chatgptUnlocked = null,Object? chatgptRegion = freezed,Object? lastCheckTime = freezed,}) {
  return _then(_self.copyWith(
netflixUnlocked: null == netflixUnlocked ? _self.netflixUnlocked : netflixUnlocked // ignore: cast_nullable_to_non_nullable
as bool,netflixRegion: freezed == netflixRegion ? _self.netflixRegion : netflixRegion // ignore: cast_nullable_to_non_nullable
as String?,chatgptUnlocked: null == chatgptUnlocked ? _self.chatgptUnlocked : chatgptUnlocked // ignore: cast_nullable_to_non_nullable
as bool,chatgptRegion: freezed == chatgptRegion ? _self.chatgptRegion : chatgptRegion // ignore: cast_nullable_to_non_nullable
as String?,lastCheckTime: freezed == lastCheckTime ? _self.lastCheckTime : lastCheckTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [StreamingUnlockStatus].
extension StreamingUnlockStatusPatterns on StreamingUnlockStatus {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StreamingUnlockStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StreamingUnlockStatus() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StreamingUnlockStatus value)  $default,){
final _that = this;
switch (_that) {
case _StreamingUnlockStatus():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StreamingUnlockStatus value)?  $default,){
final _that = this;
switch (_that) {
case _StreamingUnlockStatus() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool netflixUnlocked,  String? netflixRegion,  bool chatgptUnlocked,  String? chatgptRegion,  DateTime? lastCheckTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StreamingUnlockStatus() when $default != null:
return $default(_that.netflixUnlocked,_that.netflixRegion,_that.chatgptUnlocked,_that.chatgptRegion,_that.lastCheckTime);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool netflixUnlocked,  String? netflixRegion,  bool chatgptUnlocked,  String? chatgptRegion,  DateTime? lastCheckTime)  $default,) {final _that = this;
switch (_that) {
case _StreamingUnlockStatus():
return $default(_that.netflixUnlocked,_that.netflixRegion,_that.chatgptUnlocked,_that.chatgptRegion,_that.lastCheckTime);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool netflixUnlocked,  String? netflixRegion,  bool chatgptUnlocked,  String? chatgptRegion,  DateTime? lastCheckTime)?  $default,) {final _that = this;
switch (_that) {
case _StreamingUnlockStatus() when $default != null:
return $default(_that.netflixUnlocked,_that.netflixRegion,_that.chatgptUnlocked,_that.chatgptRegion,_that.lastCheckTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StreamingUnlockStatus implements StreamingUnlockStatus {
  const _StreamingUnlockStatus({required this.netflixUnlocked, this.netflixRegion, required this.chatgptUnlocked, this.chatgptRegion, this.lastCheckTime});
  factory _StreamingUnlockStatus.fromJson(Map<String, dynamic> json) => _$StreamingUnlockStatusFromJson(json);

@override final  bool netflixUnlocked;
@override final  String? netflixRegion;
@override final  bool chatgptUnlocked;
@override final  String? chatgptRegion;
@override final  DateTime? lastCheckTime;

/// Create a copy of StreamingUnlockStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StreamingUnlockStatusCopyWith<_StreamingUnlockStatus> get copyWith => __$StreamingUnlockStatusCopyWithImpl<_StreamingUnlockStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StreamingUnlockStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StreamingUnlockStatus&&(identical(other.netflixUnlocked, netflixUnlocked) || other.netflixUnlocked == netflixUnlocked)&&(identical(other.netflixRegion, netflixRegion) || other.netflixRegion == netflixRegion)&&(identical(other.chatgptUnlocked, chatgptUnlocked) || other.chatgptUnlocked == chatgptUnlocked)&&(identical(other.chatgptRegion, chatgptRegion) || other.chatgptRegion == chatgptRegion)&&(identical(other.lastCheckTime, lastCheckTime) || other.lastCheckTime == lastCheckTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,netflixUnlocked,netflixRegion,chatgptUnlocked,chatgptRegion,lastCheckTime);

@override
String toString() {
  return 'StreamingUnlockStatus(netflixUnlocked: $netflixUnlocked, netflixRegion: $netflixRegion, chatgptUnlocked: $chatgptUnlocked, chatgptRegion: $chatgptRegion, lastCheckTime: $lastCheckTime)';
}


}

/// @nodoc
abstract mixin class _$StreamingUnlockStatusCopyWith<$Res> implements $StreamingUnlockStatusCopyWith<$Res> {
  factory _$StreamingUnlockStatusCopyWith(_StreamingUnlockStatus value, $Res Function(_StreamingUnlockStatus) _then) = __$StreamingUnlockStatusCopyWithImpl;
@override @useResult
$Res call({
 bool netflixUnlocked, String? netflixRegion, bool chatgptUnlocked, String? chatgptRegion, DateTime? lastCheckTime
});




}
/// @nodoc
class __$StreamingUnlockStatusCopyWithImpl<$Res>
    implements _$StreamingUnlockStatusCopyWith<$Res> {
  __$StreamingUnlockStatusCopyWithImpl(this._self, this._then);

  final _StreamingUnlockStatus _self;
  final $Res Function(_StreamingUnlockStatus) _then;

/// Create a copy of StreamingUnlockStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? netflixUnlocked = null,Object? netflixRegion = freezed,Object? chatgptUnlocked = null,Object? chatgptRegion = freezed,Object? lastCheckTime = freezed,}) {
  return _then(_StreamingUnlockStatus(
netflixUnlocked: null == netflixUnlocked ? _self.netflixUnlocked : netflixUnlocked // ignore: cast_nullable_to_non_nullable
as bool,netflixRegion: freezed == netflixRegion ? _self.netflixRegion : netflixRegion // ignore: cast_nullable_to_non_nullable
as String?,chatgptUnlocked: null == chatgptUnlocked ? _self.chatgptUnlocked : chatgptUnlocked // ignore: cast_nullable_to_non_nullable
as bool,chatgptRegion: freezed == chatgptRegion ? _self.chatgptRegion : chatgptRegion // ignore: cast_nullable_to_non_nullable
as String?,lastCheckTime: freezed == lastCheckTime ? _self.lastCheckTime : lastCheckTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$StreamingUnlockCheckResult {

 bool get isUnlocked; String? get region; StreamingService get service;
/// Create a copy of StreamingUnlockCheckResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StreamingUnlockCheckResultCopyWith<StreamingUnlockCheckResult> get copyWith => _$StreamingUnlockCheckResultCopyWithImpl<StreamingUnlockCheckResult>(this as StreamingUnlockCheckResult, _$identity);

  /// Serializes this StreamingUnlockCheckResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StreamingUnlockCheckResult&&(identical(other.isUnlocked, isUnlocked) || other.isUnlocked == isUnlocked)&&(identical(other.region, region) || other.region == region)&&(identical(other.service, service) || other.service == service));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isUnlocked,region,service);

@override
String toString() {
  return 'StreamingUnlockCheckResult(isUnlocked: $isUnlocked, region: $region, service: $service)';
}


}

/// @nodoc
abstract mixin class $StreamingUnlockCheckResultCopyWith<$Res>  {
  factory $StreamingUnlockCheckResultCopyWith(StreamingUnlockCheckResult value, $Res Function(StreamingUnlockCheckResult) _then) = _$StreamingUnlockCheckResultCopyWithImpl;
@useResult
$Res call({
 bool isUnlocked, String? region, StreamingService service
});




}
/// @nodoc
class _$StreamingUnlockCheckResultCopyWithImpl<$Res>
    implements $StreamingUnlockCheckResultCopyWith<$Res> {
  _$StreamingUnlockCheckResultCopyWithImpl(this._self, this._then);

  final StreamingUnlockCheckResult _self;
  final $Res Function(StreamingUnlockCheckResult) _then;

/// Create a copy of StreamingUnlockCheckResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isUnlocked = null,Object? region = freezed,Object? service = null,}) {
  return _then(_self.copyWith(
isUnlocked: null == isUnlocked ? _self.isUnlocked : isUnlocked // ignore: cast_nullable_to_non_nullable
as bool,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as StreamingService,
  ));
}

}


/// Adds pattern-matching-related methods to [StreamingUnlockCheckResult].
extension StreamingUnlockCheckResultPatterns on StreamingUnlockCheckResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StreamingUnlockCheckResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StreamingUnlockCheckResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StreamingUnlockCheckResult value)  $default,){
final _that = this;
switch (_that) {
case _StreamingUnlockCheckResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StreamingUnlockCheckResult value)?  $default,){
final _that = this;
switch (_that) {
case _StreamingUnlockCheckResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isUnlocked,  String? region,  StreamingService service)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StreamingUnlockCheckResult() when $default != null:
return $default(_that.isUnlocked,_that.region,_that.service);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isUnlocked,  String? region,  StreamingService service)  $default,) {final _that = this;
switch (_that) {
case _StreamingUnlockCheckResult():
return $default(_that.isUnlocked,_that.region,_that.service);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isUnlocked,  String? region,  StreamingService service)?  $default,) {final _that = this;
switch (_that) {
case _StreamingUnlockCheckResult() when $default != null:
return $default(_that.isUnlocked,_that.region,_that.service);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StreamingUnlockCheckResult implements StreamingUnlockCheckResult {
  const _StreamingUnlockCheckResult({required this.isUnlocked, this.region, required this.service});
  factory _StreamingUnlockCheckResult.fromJson(Map<String, dynamic> json) => _$StreamingUnlockCheckResultFromJson(json);

@override final  bool isUnlocked;
@override final  String? region;
@override final  StreamingService service;

/// Create a copy of StreamingUnlockCheckResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StreamingUnlockCheckResultCopyWith<_StreamingUnlockCheckResult> get copyWith => __$StreamingUnlockCheckResultCopyWithImpl<_StreamingUnlockCheckResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StreamingUnlockCheckResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StreamingUnlockCheckResult&&(identical(other.isUnlocked, isUnlocked) || other.isUnlocked == isUnlocked)&&(identical(other.region, region) || other.region == region)&&(identical(other.service, service) || other.service == service));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isUnlocked,region,service);

@override
String toString() {
  return 'StreamingUnlockCheckResult(isUnlocked: $isUnlocked, region: $region, service: $service)';
}


}

/// @nodoc
abstract mixin class _$StreamingUnlockCheckResultCopyWith<$Res> implements $StreamingUnlockCheckResultCopyWith<$Res> {
  factory _$StreamingUnlockCheckResultCopyWith(_StreamingUnlockCheckResult value, $Res Function(_StreamingUnlockCheckResult) _then) = __$StreamingUnlockCheckResultCopyWithImpl;
@override @useResult
$Res call({
 bool isUnlocked, String? region, StreamingService service
});




}
/// @nodoc
class __$StreamingUnlockCheckResultCopyWithImpl<$Res>
    implements _$StreamingUnlockCheckResultCopyWith<$Res> {
  __$StreamingUnlockCheckResultCopyWithImpl(this._self, this._then);

  final _StreamingUnlockCheckResult _self;
  final $Res Function(_StreamingUnlockCheckResult) _then;

/// Create a copy of StreamingUnlockCheckResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isUnlocked = null,Object? region = freezed,Object? service = null,}) {
  return _then(_StreamingUnlockCheckResult(
isUnlocked: null == isUnlocked ? _self.isUnlocked : isUnlocked // ignore: cast_nullable_to_non_nullable
as bool,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as StreamingService,
  ));
}


}

// dart format on
