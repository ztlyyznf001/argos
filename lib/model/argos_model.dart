import 'package:argos/config/argos_config.dart';

class ArgosBaseModel {
  ArgosCapability? type;

  final int recordTime = DateTime.now().microsecondsSinceEpoch;

  String getValue() {
    return '';
  }
}
