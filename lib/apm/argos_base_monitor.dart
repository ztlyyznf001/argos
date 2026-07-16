import 'package:argos_inspector/model/argos_model.dart';

class ArgosBaseMonitor {
  void onReport(ArgosBaseModel model) {}

  ArgosBaseMonitor init() {
    return this;
  }
}
