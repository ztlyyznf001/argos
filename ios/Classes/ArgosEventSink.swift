import Flutter
import Foundation

final class ArgosEventSink {
    static let shared = ArgosEventSink()
    private init() {}

    private var sink: FlutterEventSink?
    private let lock = NSLock()

    func setSink(_ sink: FlutterEventSink?) {
        lock.lock()
        defer { lock.unlock() }
        self.sink = sink
    }

    func send(_ json: String) {
        lock.lock()
        let s = sink
        lock.unlock()
        DispatchQueue.main.async {
            s?(json)
        }
    }
}
