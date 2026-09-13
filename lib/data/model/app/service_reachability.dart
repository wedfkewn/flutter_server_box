enum ServiceKind { chatGpt, netflix, gemini }

enum ServiceReachabilityState { reachable, unreachable, unknown }

class ServiceReachabilityResult {
  const ServiceReachabilityResult({
    required this.service,
    required this.state,
    required this.checkedAt,
  });

  final ServiceKind service;
  final ServiceReachabilityState state;
  final DateTime checkedAt;

  bool get reachable => state == ServiceReachabilityState.reachable;

  Map<String, Object> toJson() => {
    'service': service.name,
    'state': state.name,
    'checkedAt': checkedAt.toIso8601String(),
  };

  factory ServiceReachabilityResult.fromJson(Map raw) {
    return ServiceReachabilityResult(
      service: ServiceKind.values.byName(raw['service'] as String),
      state: ServiceReachabilityState.values.byName(raw['state'] as String),
      checkedAt: DateTime.parse(raw['checkedAt'] as String),
    );
  }
}

class ServiceReachabilityFailure implements Exception {
  const ServiceReachabilityFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
