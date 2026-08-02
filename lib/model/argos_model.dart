import 'package:argos_inspector/config/argos_config.dart';
import 'package:argos_inspector/model/argos_diagnostic_session.dart';

class ArgosBaseModel {
  ArgosCapability? type;

  /// Session identity assigned only after the event passes dispatch gating.
  ArgosEventMetadata? eventMetadata;

  final int recordTime = DateTime.now().microsecondsSinceEpoch;

  String getValue() {
    return '';
  }
}
