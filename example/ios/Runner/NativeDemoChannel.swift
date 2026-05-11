import Flutter
import Foundation

enum NativeDemoChannel {
    static let channelName = "argos_example/native_demo"

    static func register(with registrar: FlutterPluginRegistrar?) {
        guard let registrar = registrar else { return }
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "sendIosRequest":
                sendIosRequest()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func sendIosRequest() {
        guard let url = URL(string: "https://httpbin.org/get?platform=ios&source=native") else {
            return
        }
        let configuration = URLSessionConfiguration.default
        let existingClasses = configuration.protocolClasses ?? []
        if let argosProtocol = NSClassFromString("ArgosURLProtocol") as? URLProtocol.Type {
            configuration.protocolClasses = [argosProtocol] + existingClasses
        }
        let session = URLSession(configuration: configuration)
        let task = session.dataTask(with: url) { _, _, _ in
            session.finishTasksAndInvalidate()
        }
        task.resume()
    }
}
