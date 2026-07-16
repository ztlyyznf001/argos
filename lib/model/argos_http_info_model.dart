import 'dart:io';

import 'package:argos_inspector/config/argos_config.dart';
import 'package:argos_inspector/model/argos_model.dart';

const int _kMaxBodyBytes = 100 * 1024; // 100 KB

Map<String, String> headersToMap(HttpHeaders? headers) {
  if (headers == null) return {};
  final map = <String, String>{};
  headers.forEach((name, values) {
    map[name] = values.join(', ');
  });
  return map;
}

String truncateRequestBody(String body) {
  if (body.length > _kMaxBodyBytes) {
    return '${body.substring(0, _kMaxBodyBytes)}[TRUNCATED]';
  }
  return body;
}

class ArgosHttpInfo extends ArgosBaseModel {
  ArgosHttpInfo(this.uri, this.method)
      : startTimestamp = DateTime.now().millisecondsSinceEpoch;

  final Uri? uri;

  final String method;

  final int startTimestamp;

  String? error;
  bool recorded = false;
  HttpRequest request = HttpRequest();
  HttpResponse response = HttpResponse();

  Map<String, dynamic> toJson() {
    final requestBody = truncateRequestBody(request.parameters.join());
    final responseBody = response.result ?? '';
    return {
      'id': startTimestamp.toString(),
      'uri': uri?.toString() ?? '',
      'method': method,
      'startTimestamp': startTimestamp,
      'endTimestamp': response.endTimestamp,
      'requestHeaders': headersToMap(request.header),
      'requestBody': requestBody,
      'responseCode': response.code,
      'responseBody': responseBody,
      'responseHeaders': headersToMap(response.header),
      'responseSize': response.size,
      'error': error,
    };
  }

  @override
  String getValue() {
    if (error != null) {
      return 'Error:$error';
    }
    return 'Uri:$uri\nMethod:$method\nParameters:${request.parameters}\nResponse:$response';
  }

  @override
  // ignore: overridden_fields
  ArgosCapability? type = ArgosCapability.network;
}

class HttpRequest {
  List<String> parameters = <String>[];
  HttpHeaders? header;

  void add(String parameter) {
    parameters.add(parameter);
  }
}

class HttpResponse {
  String? _result;

  String? get result => _result;
  int _code = 0;

  int get code => _code;

  HttpHeaders? _header;

  HttpHeaders? get header => _header;
  int endTimestamp = 0;
  int size = 0;

  void update(int code, String result, HttpHeaders header, int size) {
    _code = code;
    _result = result;
    _header = header;
    this.size = size;
    endTimestamp = DateTime.now().millisecondsSinceEpoch;
  }

  void updateError() {
    endTimestamp = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  String toString() {
    return _code > 0 ? 'code $_code,result $_result' : '';
  }
}

/// Serializable snapshot of a captured HTTP request/response, used for
/// persistent storage and UI display.
class ArgosPacketRecord {
  final String id;
  final String uri;
  final String method;
  final int startTimestamp;
  final int endTimestamp;
  final Map<String, String> requestHeaders;
  final String requestBody;
  final int responseCode;
  final String responseBody;
  final Map<String, String> responseHeaders;
  final int responseSize;
  final String? error;
  final String routeName;

  /// Event kind: `network` (HTTP packet), `crash`, `jank`, or `resource`.
  /// Used by the Inspector UI to render differentiated list items.
  final String kind;

  ArgosPacketRecord({
    required this.id,
    required this.uri,
    required this.method,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.requestHeaders,
    required this.requestBody,
    required this.responseCode,
    required this.responseBody,
    required this.responseHeaders,
    required this.responseSize,
    this.error,
    this.routeName = '',
    this.kind = 'network',
  });

  factory ArgosPacketRecord.fromHttpInfo(ArgosHttpInfo info) {
    final json = info.toJson();
    return ArgosPacketRecord.fromJson(json);
  }

  factory ArgosPacketRecord.fromJson(Map<String, dynamic> json) {
    return ArgosPacketRecord(
      id: json['id'] as String? ?? '',
      uri: json['uri'] as String? ?? '',
      method: json['method'] as String? ?? '',
      startTimestamp: json['startTimestamp'] as int? ?? 0,
      endTimestamp: json['endTimestamp'] as int? ?? 0,
      requestHeaders: _castStringMap(json['requestHeaders']),
      requestBody: json['requestBody'] as String? ?? '',
      responseCode: json['responseCode'] as int? ?? 0,
      responseBody: json['responseBody'] as String? ?? '',
      responseHeaders: _castStringMap(json['responseHeaders']),
      responseSize: json['responseSize'] as int? ?? 0,
      error: json['error'] as String?,
      routeName: json['routeName'] as String? ?? '',
      kind: json['kind'] as String? ?? 'network',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uri': uri,
      'method': method,
      'startTimestamp': startTimestamp,
      'endTimestamp': endTimestamp,
      'requestHeaders': requestHeaders,
      'requestBody': requestBody,
      'responseCode': responseCode,
      'responseBody': responseBody,
      'responseHeaders': responseHeaders,
      'responseSize': responseSize,
      'error': error,
      'routeName': routeName,
      'kind': kind,
    };
  }

  int get durationMs => endTimestamp > 0 ? endTimestamp - startTimestamp : 0;

  static Map<String, String> _castStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
}
