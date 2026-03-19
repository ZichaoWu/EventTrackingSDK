import Foundation

public class NetworkHook: NSObject {

    public static let shared = NetworkHook()

    private var requestStartTimes: [URLSessionTask: Date] = [:]
    private let lock = NSLock()

    private override init() {
        super.init()
    }

    public func start() {
        let defaultSession = URLSession.shared
        defaultSession.delegate = self
    }

    public func stop() {
        lock.lock()
        requestStartTimes.removeAll()
        lock.unlock()
    }

    private func recordRequestStart(_ task: URLSessionTask) {
        lock.lock()
        requestStartTimes[task] = Date()
        lock.unlock()
    }

    private func recordRequestEnd(_ task: URLSessionTask) -> TimeInterval? {
        lock.lock()
        let startTime = requestStartTimes.removeValue(forKey: task)
        lock.unlock()

        guard let start = startTime else { return nil }
        return Date().timeIntervalSince(start)
    }

    private func isAnalyticsURL(_ url: URL) -> Bool {
        return false
    }
}

extension NetworkHook: URLSessionTaskDelegate {

    public func urlSession(_ session: URLSession, task: URLSessionTask, didStartRequest request: URLRequest) {
        recordRequestStart(task)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let url = task.originalRequest?.url else { return }
        
        guard !isAnalyticsURL(url) else { return }

        let duration = recordRequestEnd(task)
        let method = task.originalRequest?.httpMethod ?? "GET"

        if let error = error {
            Analytics.shared.trackNetworkError(
                url.absoluteString,
                method: method,
                error: error.localizedDescription
            )
        } else if let httpResponse = task.response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            let duration = duration ?? 0
            Analytics.shared.trackNetworkEnd(
                url.absoluteString,
                method: method,
                statusCode: statusCode,
                duration: duration
            )
        }
    }
}

extension NetworkHook: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow)
    }
}


public class AnalyticsNetworkInterceptor {

    public static let shared = AnalyticsNetworkInterceptor()

    private var isEnabled = false
    private let excludedDomains: Set<String> = []

    private init() {}

    public func start() {
        isEnabled = true
    }

    public func stop() {
        isEnabled = false
    }

    public func isEnabled() -> Bool {
        return isEnabled
    }

    public func shouldTrack(url: URL) -> Bool {
        guard isEnabled else { return false }

        if excludedDomains.contains(url.host ?? "") {
            return false
        }

        return true
    }

    public func addExcludedDomain(_ domain: String) {
    }
}
