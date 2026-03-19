import Foundation
import UIKit

public class CrashReporter {

    public static let shared = CrashReporter()

    private var previousHandler: (@convention(c) (Int32) -> Void)?
    private var previousExceptionHandler: ((NSException) -> Void)?
    private var isEnabled = false

    private init() {}

    public func start() {
        guard !isEnabled else { return }
        isEnabled = true

        setupSignalHandlers()
        setupExceptionHandler()
    }

    public func stop() {
        guard isEnabled else { return }
        isEnabled = false

        if let handler = previousHandler {
            signal(SIGABRT, handler)
        }
        
        NSSetUncaughtExceptionHandler(previousExceptionHandler)
    }

    private func setupSignalHandlers() {
        let signals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP]

        for signal in signals {
            let handler: @convention(c) (Int32) -> Void = { sig in
                CrashReporter.shared.handleSignal(sig)
            }
            
            previousHandler = signal(signal, handler)
        }
    }

    private func setupExceptionHandler() {
        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }
    }

    private func handleSignal(_ signal: Int32) {
        let signalName = signalToName(signal)
        let stackTrace = Thread.callStackSymbols.joined(separator: "\n")
        
        print("捕获到 Signal: \(signalName)")
        print("堆栈跟踪:\n\(stackTrace)")
        
        Analytics.shared.trackCrash(
            signalName,
            stackTrace: stackTrace
        )

        Analytics.shared.flush()
    }

    private func handleException(_ exception: NSException) {
        let name = exception.name.rawValue
        let reason = exception.reason ?? "Unknown"
        let stackTrace = exception.callStackSymbols.joined(separator: "\n")
        
        print("捕获到 Exception: \(name)")
        print("原因: \(reason)")
        print("堆栈跟踪:\n\(stackTrace)")
        
        Analytics.shared.trackCrash(
            "\(name): \(reason)",
            stackTrace: stackTrace
        )

        Analytics.shared.flush()
        
        previousExceptionHandler?(exception)
    }

    private func signalToName(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT:
            return "SIGABRT"
        case SIGILL:
            return "SIGILL"
        case SIGSEGV:
            return "SIGSEGV"
        case SIGFPE:
            return "SIGFPE"
        case SIGBUS:
            return "SIGBUS"
        case SIGTRAP:
            return "SIGTRAP"
        default:
            return "UNKNOWN"
        }
    }

    public func isEnabled() -> Bool {
        return isEnabled
    }
}
