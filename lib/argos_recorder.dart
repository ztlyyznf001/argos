// 待开发
class ArgosFpsRecorder {
  ArgosFpsRecorder._internal();

  static late final ArgosFpsRecorder _instance = ArgosFpsRecorder._internal();

  static ArgosFpsRecorder get instance => _instance;

  ArgosFpsRecorder init() {
    return this;
  }
}
