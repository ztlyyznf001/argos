import 'package:argos/config/argos_config.dart';
import 'package:argos/model/argos_model.dart';

class ArgosFpsInfo extends ArgosBaseModel {
  ArgosFpsInfo(this.fpsValue)
      : startTimestamp = DateTime.now().millisecondsSinceEpoch;

  final double? fpsValue;

  final int startTimestamp;

  @override
  String getValue() {
    return 'fps : $fpsValue';
  }

  @override
  // ignore: overridden_fields
  ArgosCapability? type = ArgosCapability.fps;
}
