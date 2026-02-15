// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ip_info.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(IpInfoNotifier)
const ipInfoProvider = IpInfoNotifierFamily._();

final class IpInfoNotifierProvider
    extends $AsyncNotifierProvider<IpInfoNotifier, IpInfo?> {
  const IpInfoNotifierProvider._({
    required IpInfoNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ipInfoProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ipInfoNotifierHash();

  @override
  String toString() {
    return r'ipInfoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  IpInfoNotifier create() => IpInfoNotifier();

  @override
  bool operator ==(Object other) {
    return other is IpInfoNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ipInfoNotifierHash() => r'a91e36358891bb16886f6622cd78283ac0846f2b';

final class IpInfoNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          IpInfoNotifier,
          AsyncValue<IpInfo?>,
          IpInfo?,
          FutureOr<IpInfo?>,
          String
        > {
  const IpInfoNotifierFamily._()
    : super(
        retry: null,
        name: r'ipInfoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  IpInfoNotifierProvider call(String ip) =>
      IpInfoNotifierProvider._(argument: ip, from: this);

  @override
  String toString() => r'ipInfoProvider';
}

abstract class _$IpInfoNotifier extends $AsyncNotifier<IpInfo?> {
  late final _$args = ref.$arg as String;
  String get ip => _$args;

  FutureOr<IpInfo?> build(String ip);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<IpInfo?>, IpInfo?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<IpInfo?>, IpInfo?>,
              AsyncValue<IpInfo?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
