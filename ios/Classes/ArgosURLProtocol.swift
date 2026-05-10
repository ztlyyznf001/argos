import Foundation

private let kCapturedHeader = "X-Argos-Captured"

@objc(ArgosURLProtocol)
final class ArgosURLProtocol: URLProtocol, URLSessionDataDelegate {
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var startTimestamp: Int64 = 0
    private var responseData = Data()
    private var urlResponse: HTTPURLResponse?

    // MARK: - Registration

    override class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: kCapturedHeader, in: request) == nil else {
            return false
        }
        let scheme = request.url?.scheme?.lowercased() ?? ""
        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    // MARK: - Loading

    override func startLoading() {
        startTimestamp = Int64(Date().timeIntervalSince1970 * 1000)
        responseData = Data()

        let mutable = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: kCapturedHeader, in: mutable)

        let config = URLSessionConfiguration.ephemeral
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        dataTask = session?.dataTask(with: mutable as URLRequest)
        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        urlResponse = response as? HTTPURLResponse
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        responseData.append(data)
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let endTimestamp = Int64(Date().timeIntervalSince1970 * 1000)

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            sendEvent(endTimestamp: endTimestamp, error: error.localizedDescription)
        } else {
            client?.urlProtocolDidFinishLoading(self)
            sendEvent(endTimestamp: endTimestamp, error: nil)
        }
    }

    // MARK: - Event

    private func sendEvent(endTimestamp: Int64, error: String?) {
        let req = request
        let httpResponse = urlResponse

        var requestHeaders: [String: String] = [:]
        req.allHTTPHeaderFields?.forEach { requestHeaders[$0.key] = $0.value }

        var responseHeaders: [String: String] = [:]
        httpResponse?.allHeaderFields.forEach {
            if let k = $0.key as? String, let v = $0.value as? String {
                responseHeaders[k] = v
            }
        }

        let contentType = responseHeaders["Content-Type"] ?? responseHeaders["content-type"] ?? ""
        let isText = isTextContentType(contentType)
        let responseBody = isText ? (String(data: responseData, encoding: .utf8) ?? "") : ""
        let responseSize = responseData.count

        let id = String(startTimestamp)
        let uri = req.url?.absoluteString ?? ""
        let method = req.httpMethod ?? "GET"

        var requestBody = ""
        if let bodyData = req.httpBody, let bodyStr = String(data: bodyData, encoding: .utf8) {
            requestBody = bodyStr
        }

        let dict: [String: Any] = [
            "id": id,
            "uri": uri,
            "method": method,
            "startTimestamp": startTimestamp,
            "endTimestamp": endTimestamp,
            "requestHeaders": requestHeaders,
            "requestBody": requestBody,
            "responseCode": httpResponse?.statusCode ?? 0,
            "responseBody": responseBody,
            "responseHeaders": responseHeaders,
            "responseSize": responseSize,
            "error": error as Any,
            "routeName": "",
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else { return }

        ArgosEventSink.shared.send(json)
    }

    private func isTextContentType(_ contentType: String) -> Bool {
        let lower = contentType.lowercased()
        return lower.contains("text") || lower.contains("json") || lower.contains("xml")
    }
}
