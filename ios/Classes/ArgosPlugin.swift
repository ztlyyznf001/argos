import Flutter
import UIKit

public class ArgosPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private static let methodChannelName = "dev.panoptes.argos/native_capture_method"
    private static let eventChannelName = "dev.panoptes.argos/native_capture"

    // Retain the plugin instance and event channel so they are not deallocated
    // after register(with:) returns. FlutterEventChannel is not retained by the
    // registrar, unlike FlutterMethodChannel via addMethodCallDelegate.
    private static var shared: ArgosPlugin?
    private static var eventChannel: FlutterEventChannel?

    private var registered = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ArgosPlugin()
        shared = instance

        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let channel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        channel.setStreamHandler(instance)
        eventChannel = channel
    }

    // MARK: - FlutterPlugin

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "enable":
            enableCapture()
            result(nil)
        case "disable":
            disableCapture()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func enableCapture() {
        guard !registered else { return }
        registered = true
        URLProtocol.registerClass(ArgosURLProtocol.self)
    }

    private func disableCapture() {
        guard registered else { return }
        registered = false
        URLProtocol.unregisterClass(ArgosURLProtocol.self)
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        ArgosEventSink.shared.setSink(events)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        ArgosEventSink.shared.setSink(nil)
        return nil
    }
}
