/// Controls whether Argos starts a diagnostic session during initialization.
enum ArgosSessionMode {
  automatic,
  manual,
}

/// How automatic mode decides the boundary of a diagnostic session.
enum ArgosAutomaticSessionStrategy {
  /// Preserve one session for the lifetime of the initialized process.
  process,

  /// Roll sessions at configured lifecycle, duration, or context boundaries.
  adaptive,
}

/// Host-defined context used only by adaptive automatic sessions.
///
/// [fingerprint] is compared in memory and is never persisted automatically.
/// Only the explicitly supplied [attributes] are copied into a session.
class ArgosSessionContext {
  ArgosSessionContext({
    required this.fingerprint,
    Map<String, String> attributes = const <String, String>{},
  })  : assert(fingerprint.isNotEmpty),
        attributes = Map<String, String>.unmodifiable(attributes);

  final String fingerprint;
  final Map<String, String> attributes;
}

/// Immutable boundary policy for sessions created by automatic mode.
class ArgosAutomaticSessionPolicy {
  const ArgosAutomaticSessionPolicy.process()
      : strategy = ArgosAutomaticSessionStrategy.process,
        backgroundTimeout = null,
        maxDuration = null,
        contextProvider = null;

  ArgosAutomaticSessionPolicy.adaptive({
    this.backgroundTimeout = const Duration(minutes: 2),
    this.maxDuration = const Duration(minutes: 30),
    this.contextProvider,
  })  : assert(
          backgroundTimeout == null || backgroundTimeout > Duration.zero,
        ),
        assert(maxDuration == null || maxDuration > Duration.zero),
        strategy = ArgosAutomaticSessionStrategy.adaptive;

  final ArgosAutomaticSessionStrategy strategy;
  final Duration? backgroundTimeout;
  final Duration? maxDuration;
  final ArgosSessionContext Function()? contextProvider;
}

/// Runtime-only state of the single active diagnostic session.
enum ArgosSessionState {
  idle,
  recording,
  paused,
}

/// Why a persisted diagnostic session ended.
enum ArgosSessionEndReason {
  completed,
  interrupted,
  backgroundTimeout,
  maxDuration,
  contextChanged,
}

/// Immutable identity assigned to an event accepted by the session controller.
class ArgosEventMetadata {
  const ArgosEventMetadata({
    required this.id,
    required this.sessionId,
    required this.sequence,
  });

  final String id;
  final String sessionId;
  final int sequence;

  factory ArgosEventMetadata.fromJson(Map<String, dynamic> json) {
    return ArgosEventMetadata(
      id: json['id']?.toString() ?? '',
      sessionId: json['sessionId']?.toString() ?? '',
      sequence: _intValue(json['sequence']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sessionId': sessionId,
        'sequence': sequence,
      };
}

/// A bounded recording session containing related diagnostic events.
class ArgosDiagnosticSession {
  const ArgosDiagnosticSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.lastEventAt,
    this.label,
    this.note,
    this.attributes = const <String, String>{},
    this.endReason,
    this.truncated = false,
  });

  final String id;
  final int startedAt;
  final int? endedAt;
  final int? lastEventAt;
  final String? label;
  final String? note;
  final Map<String, String> attributes;
  final ArgosSessionEndReason? endReason;
  final bool truncated;

  bool get isEnded => endedAt != null;

  factory ArgosDiagnosticSession.fromJson(Map<String, dynamic> json) {
    return ArgosDiagnosticSession(
      id: json['id']?.toString() ?? '',
      startedAt: _intValue(json['startedAt']),
      endedAt: _nullableIntValue(json['endedAt']),
      lastEventAt: _nullableIntValue(json['lastEventAt']),
      label: json['label']?.toString(),
      note: json['note']?.toString(),
      attributes: _stringMap(json['attributes']),
      endReason: _endReason(json['endReason']),
      truncated: json['truncated'] == true,
    );
  }

  ArgosDiagnosticSession copyWith({
    int? endedAt,
    bool clearEndedAt = false,
    int? lastEventAt,
    bool clearLastEventAt = false,
    String? label,
    bool clearLabel = false,
    String? note,
    bool clearNote = false,
    Map<String, String>? attributes,
    ArgosSessionEndReason? endReason,
    bool clearEndReason = false,
    bool? truncated,
  }) {
    return ArgosDiagnosticSession(
      id: id,
      startedAt: startedAt,
      endedAt: clearEndedAt ? null : endedAt ?? this.endedAt,
      lastEventAt: clearLastEventAt ? null : lastEventAt ?? this.lastEventAt,
      label: clearLabel ? null : label ?? this.label,
      note: clearNote ? null : note ?? this.note,
      attributes: Map<String, String>.unmodifiable(
        attributes ?? this.attributes,
      ),
      endReason: clearEndReason ? null : endReason ?? this.endReason,
      truncated: truncated ?? this.truncated,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'lastEventAt': lastEventAt,
        'label': label,
        'note': note,
        'attributes': attributes,
        'endReason': endReason?.name,
        'truncated': truncated,
      };
}

ArgosSessionEndReason? _endReason(dynamic value) {
  switch (value?.toString()) {
    case 'completed':
      return ArgosSessionEndReason.completed;
    case 'interrupted':
      return ArgosSessionEndReason.interrupted;
    case 'backgroundTimeout':
      return ArgosSessionEndReason.backgroundTimeout;
    case 'maxDuration':
      return ArgosSessionEndReason.maxDuration;
    case 'contextChanged':
      return ArgosSessionEndReason.contextChanged;
  }
  return null;
}

int _intValue(dynamic value) => _nullableIntValue(value) ?? 0;

int? _nullableIntValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

Map<String, String> _stringMap(dynamic value) {
  if (value is! Map) return const <String, String>{};
  return Map<String, String>.unmodifiable(
    value.map((key, item) => MapEntry(key.toString(), item.toString())),
  );
}
