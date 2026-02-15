// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ip_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IpInfo {

 String get ip; String? get hostname; String? get city; String? get region; String? get country; String? get loc; String? get org; String? get postal; String? get timezone;
/// Create a copy of IpInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IpInfoCopyWith<IpInfo> get copyWith => _$IpInfoCopyWithImpl<IpInfo>(this as IpInfo, _$identity);

  /// Serializes this IpInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IpInfo&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.hostname, hostname) || other.hostname == hostname)&&(identical(other.city, city) || other.city == city)&&(identical(other.region, region) || other.region == region)&&(identical(other.country, country) || other.country == country)&&(identical(other.loc, loc) || other.loc == loc)&&(identical(other.org, org) || other.org == org)&&(identical(other.postal, postal) || other.postal == postal)&&(identical(other.timezone, timezone) || other.timezone == timezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ip,hostname,city,region,country,loc,org,postal,timezone);

@override
String toString() {
  return 'IpInfo(ip: $ip, hostname: $hostname, city: $city, region: $region, country: $country, loc: $loc, org: $org, postal: $postal, timezone: $timezone)';
}


}

/// @nodoc
abstract mixin class $IpInfoCopyWith<$Res>  {
  factory $IpInfoCopyWith(IpInfo value, $Res Function(IpInfo) _then) = _$IpInfoCopyWithImpl;
@useResult
$Res call({
 String ip, String? hostname, String? city, String? region, String? country, String? loc, String? org, String? postal, String? timezone
});




}
/// @nodoc
class _$IpInfoCopyWithImpl<$Res>
    implements $IpInfoCopyWith<$Res> {
  _$IpInfoCopyWithImpl(this._self, this._then);

  final IpInfo _self;
  final $Res Function(IpInfo) _then;

/// Create a copy of IpInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ip = null,Object? hostname = freezed,Object? city = freezed,Object? region = freezed,Object? country = freezed,Object? loc = freezed,Object? org = freezed,Object? postal = freezed,Object? timezone = freezed,}) {
  return _then(_self.copyWith(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,hostname: freezed == hostname ? _self.hostname : hostname // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,loc: freezed == loc ? _self.loc : loc // ignore: cast_nullable_to_non_nullable
as String?,org: freezed == org ? _self.org : org // ignore: cast_nullable_to_non_nullable
as String?,postal: freezed == postal ? _self.postal : postal // ignore: cast_nullable_to_non_nullable
as String?,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [IpInfo].
extension IpInfoPatterns on IpInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IpInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IpInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IpInfo value)  $default,){
final _that = this;
switch (_that) {
case _IpInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IpInfo value)?  $default,){
final _that = this;
switch (_that) {
case _IpInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ip,  String? hostname,  String? city,  String? region,  String? country,  String? loc,  String? org,  String? postal,  String? timezone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IpInfo() when $default != null:
return $default(_that.ip,_that.hostname,_that.city,_that.region,_that.country,_that.loc,_that.org,_that.postal,_that.timezone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ip,  String? hostname,  String? city,  String? region,  String? country,  String? loc,  String? org,  String? postal,  String? timezone)  $default,) {final _that = this;
switch (_that) {
case _IpInfo():
return $default(_that.ip,_that.hostname,_that.city,_that.region,_that.country,_that.loc,_that.org,_that.postal,_that.timezone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ip,  String? hostname,  String? city,  String? region,  String? country,  String? loc,  String? org,  String? postal,  String? timezone)?  $default,) {final _that = this;
switch (_that) {
case _IpInfo() when $default != null:
return $default(_that.ip,_that.hostname,_that.city,_that.region,_that.country,_that.loc,_that.org,_that.postal,_that.timezone);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IpInfo implements IpInfo {
  const _IpInfo({required this.ip, this.hostname, this.city, this.region, this.country, this.loc, this.org, this.postal, this.timezone});
  factory _IpInfo.fromJson(Map<String, dynamic> json) => _$IpInfoFromJson(json);

@override final  String ip;
@override final  String? hostname;
@override final  String? city;
@override final  String? region;
@override final  String? country;
@override final  String? loc;
@override final  String? org;
@override final  String? postal;
@override final  String? timezone;

/// Create a copy of IpInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IpInfoCopyWith<_IpInfo> get copyWith => __$IpInfoCopyWithImpl<_IpInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IpInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _IpInfo&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.hostname, hostname) || other.hostname == hostname)&&(identical(other.city, city) || other.city == city)&&(identical(other.region, region) || other.region == region)&&(identical(other.country, country) || other.country == country)&&(identical(other.loc, loc) || other.loc == loc)&&(identical(other.org, org) || other.org == org)&&(identical(other.postal, postal) || other.postal == postal)&&(identical(other.timezone, timezone) || other.timezone == timezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ip,hostname,city,region,country,loc,org,postal,timezone);

@override
String toString() {
  return 'IpInfo(ip: $ip, hostname: $hostname, city: $city, region: $region, country: $country, loc: $loc, org: $org, postal: $postal, timezone: $timezone)';
}


}

/// @nodoc
abstract mixin class _$IpInfoCopyWith<$Res> implements $IpInfoCopyWith<$Res> {
  factory _$IpInfoCopyWith(_IpInfo value, $Res Function(_IpInfo) _then) = __$IpInfoCopyWithImpl;
@override @useResult
$Res call({
 String ip, String? hostname, String? city, String? region, String? country, String? loc, String? org, String? postal, String? timezone
});




}
/// @nodoc
class __$IpInfoCopyWithImpl<$Res>
    implements _$IpInfoCopyWith<$Res> {
  __$IpInfoCopyWithImpl(this._self, this._then);

  final _IpInfo _self;
  final $Res Function(_IpInfo) _then;

/// Create a copy of IpInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ip = null,Object? hostname = freezed,Object? city = freezed,Object? region = freezed,Object? country = freezed,Object? loc = freezed,Object? org = freezed,Object? postal = freezed,Object? timezone = freezed,}) {
  return _then(_IpInfo(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,hostname: freezed == hostname ? _self.hostname : hostname // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,loc: freezed == loc ? _self.loc : loc // ignore: cast_nullable_to_non_nullable
as String?,org: freezed == org ? _self.org : org // ignore: cast_nullable_to_non_nullable
as String?,postal: freezed == postal ? _self.postal : postal // ignore: cast_nullable_to_non_nullable
as String?,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
