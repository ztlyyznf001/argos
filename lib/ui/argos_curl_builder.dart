import 'dart:convert';

import 'package:argos/model/argos_http_info_model.dart';

class ArgosCurlBuilder {
  /// Converts a [ArgosPacketRecord] into an equivalent cURL command string.
  ///
  /// Format:
  ///   curl 'URL' \
  ///   [-X METHOD] \
  ///   -H 'Key: Value' \
  ///   [--compressed] \
  ///   [--data-raw 'body'] \
  ///   [--proxy proxy]
  static String build(ArgosPacketRecord record, {String? proxy}) {
    final buf = StringBuffer();
    buf.write("curl '${record.uri}'");

    // -X METHOD (omit for GET since curl defaults to GET)
    if (record.method.toUpperCase() != 'GET') {
      buf.write(' \\\n-X ${record.method}');
    }

    // Request headers
    record.requestHeaders.forEach((key, value) {
      final escaped = value.replaceAll("'", "'\\''");
      buf.write(" \\\n-H '$key: $escaped'");
    });

    // --compressed when Accept-Encoding includes gzip
    final hasGzip = record.requestHeaders.entries.any((e) =>
        e.key.toLowerCase() == 'accept-encoding' &&
        e.value.toLowerCase().contains('gzip'));
    if (hasGzip) {
      buf.write(' \\\n--compressed');
    }

    // Request body
    if (record.requestBody.isNotEmpty) {
      final body = _formatBody(record);
      final escaped = body.replaceAll("'", "'\\''");
      buf.write(" \\\n--data-raw '$escaped'");
    }

    // --proxy (optional, at the end)
    if (proxy != null && proxy.isNotEmpty) {
      buf.write(' \\\n--proxy $proxy');
    }

    return buf.toString();
  }

  static String _formatBody(ArgosPacketRecord record) {
    final contentType = record.requestHeaders.entries
        .firstWhere(
          (e) => e.key.toLowerCase() == 'content-type',
          orElse: () => const MapEntry('', ''),
        )
        .value
        .toLowerCase();

    if (contentType.contains('json')) {
      try {
        final decoded = json.decode(record.requestBody);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        // fall through to raw body
      }
    }
    return record.requestBody;
  }
}
