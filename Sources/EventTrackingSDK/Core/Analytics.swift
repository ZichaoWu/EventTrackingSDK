import Foundation
import UIKit

/// 埋点 SDK 主类，提供所有埋点方法
public class Analytics {

    /// 单例实例
    public static let shared = Analytics()

    /// 事件队列，负责事件的收集和上传
    private let queue = EventQueue.shared
    
    /// 配置管理器，负责管理 SDK 配置
    private let config = AnalyticsConfig.shared
    
    /// 会话管理器，负责管理用户会话
    private let sessionManager = SessionManager.shared

    /// 私有初始化，确保单例
    private init() {}

    /// 通用埋点方法
    /// - Parameters:
    ///   - name: 事件名称
    ///   - params: 事件参数（可选）
    /// - 流程：
    ///   1. 检查是否需要采样
    ///   2. 检查并更新会话
    ///   3. 创建事件对象
    ///   4. 经过拦截器处理
    ///   5. 打印调试日志（如果开启）
    ///   6. 加入事件队列
    public func track(_ name: String, params: [String: Any] = [:]) {
        // 1. 检查采样率，如果不需要采样则直接返回
        guard config.shouldSampleEvent(name) else { return }

        // 2. 检查并更新会话
        sessionManager.checkAndRenewSessionIfNeeded { [weak self] newSessionId in
            guard let self = self else { return }
            
            // 3. 创建事件对象
            var event = Event(
                id: UUID().uuidString,
                name: name,
                params: params.mapValues { AnyCodable($0) },
                timestamp: Date().timeIntervalSince1970,
                eventId: UUID().uuidString,
                eventType: name,
                page: params["page"] as? String ?? "",
                element: params["element"] as? String ?? "",
                userId: "",
                sessionId: newSessionId ?? self.sessionManager.getSessionId()
            )

            // 4. 经过拦截器处理，可能被拦截（返回 nil）
            guard let processedEvent = InterceptorChain.shared.processEvent(event) else {
                return
            }
            event = processedEvent

            // 5. 打印调试日志
            if self.config.isDebug() {
                print("[Analytics] event: \(event.name), params: \(event.params)")
            }

            // 6. 加入事件队列
            self.queue.enqueue(event)
        }
    }

    /// 页面显示埋点
    /// - Parameters:
    ///   - page: 页面名称
    ///   - params: 事件参数（可选）
    public func trackPageShow(_ page: String, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["page"] = page
        track("page_show", params: eventParams)
    }

    /// 页面隐藏埋点
    /// - Parameters:
    ///   - page: 页面名称
    ///   - params: 事件参数（可选）
    public func trackPageHide(_ page: String, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["page"] = page
        track("page_hide", params: eventParams)
    }

    /// 页面停留时长埋点
    /// - Parameters:
    ///   - page: 页面名称
    ///   - duration: 停留时长（秒）
    ///   - params: 事件参数（可选）
    public func trackPageDuration(_ page: String, duration: TimeInterval, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["page"] = page
        eventParams["duration"] = duration
        track("page_duration", params: eventParams)
    }

    /// 点击事件埋点
    /// - Parameters:
    ///   - element: 元素名称
    ///   - params: 事件参数（可选）
    public func trackClick(_ element: String, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["element"] = element
        track("click", params: eventParams)
    }

    /// 滑动事件埋点
    /// - Parameters:
    ///   - direction: 滑动方向（如 "left", "right", "up", "down"）
    ///   - params: 事件参数（可选）
    public func trackSwipe(_ direction: String, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["direction"] = direction
        track("swipe", params: eventParams)
    }

    /// 长按事件埋点
    /// - Parameters:
    ///   - element: 元素名称
    ///   - duration: 长按时长（秒）
    ///   - params: 事件参数（可选）
    public func trackLongPress(_ element: String, duration: TimeInterval, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["element"] = element
        eventParams["duration"] = duration
        track("long_press", params: eventParams)
    }

    /// 网络请求开始埋点
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: 请求方法（如 "GET", "POST"）
    ///   - params: 事件参数（可选）
    public func trackNetworkStart(_ url: String, method: String, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["url"] = url
        eventParams["method"] = method
        track("network_start", params: eventParams)
    }

    /// 网络请求结束埋点
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: 请求方法
    ///   - statusCode: HTTP 状态码
    ///   - duration: 请求时长（秒）
    ///   - params: 事件参数（可选）
    public func trackNetworkEnd(_ url: String, method: String, statusCode: Int, duration: TimeInterval, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["url"] = url
        eventParams["method"] = method
        eventParams["status_code"] = statusCode
        eventParams["duration"] = duration
        track("network_end", params: eventParams)
    }

    /// 网络请求错误埋点
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: 请求方法
    ///   - error: 错误信息
    ///   - params: 事件参数（可选）
    public func trackNetworkError(_ url: String, method: String, error: String, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["url"] = url
        eventParams["method"] = method
        eventParams["error"] = error
        track("network_error", params: eventParams)
    }

    /// App 启动埋点
    /// - Parameter params: 事件参数（可选）
    public func trackAppLaunch(params: [String: Any] = [:]) {
        track("app_launch", params: params)
    }

    /// App 退出埋点
    /// - Parameter params: 事件参数（可选）
    public func trackAppExit(params: [String: Any] = [:]) {
        track("app_exit", params: params)
    }

    /// App 进入后台埋点
    /// - Parameter params: 事件参数（可选）
    public func trackAppEnterBackground(params: [String: Any] = [:]) {
        track("app_enter_background", params: params)
    }

    /// App 进入前台埋点
    /// - Parameter params: 事件参数（可选）
    public func trackAppEnterForeground(params: [String: Any] = [:]) {
        track("app_enter_foreground", params: params)
    }

    /// App 启动时长埋点
    /// - Parameters:
    ///   - duration: 启动时长（秒）
    ///   - params: 事件参数（可选）
    public func trackAppStartDuration(_ duration: TimeInterval, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["duration"] = duration
        track("app_start_duration", params: eventParams)
    }

    /// 内存使用埋点
    /// - Parameters:
    ///   - usage: 内存使用量（MB）
    ///   - params: 事件参数（可选）
    public func trackMemoryUsage(_ usage: Int, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["usage"] = usage
        track("memory_usage", params: eventParams)
    }

    /// CPU 使用埋点
    /// - Parameters:
    ///   - usage: CPU 使用率（0-100）
    ///   - params: 事件参数（可选）
    public func trackCPUUsage(_ usage: Double, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["usage"] = usage
        track("cpu_usage", params: eventParams)
    }

    /// 崩溃埋点
    /// - Parameters:
    ///   - error: 错误信息
    ///   - stackTrace: 堆栈信息
    ///   - params: 事件参数（可选）
    public func trackCrash(_ error: String, stackTrace: String, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["error"] = error
        eventParams["stack_trace"] = stackTrace
        track("crash", params: eventParams)
    }

    /// 异常埋点
    /// - Parameters:
    ///   - error: 错误信息
    ///   - params: 事件参数（可选）
    public func trackException(_ error: String, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["error"] = error
        track("exception", params: eventParams)
    }

    /// 错误埋点
    /// - Parameters:
    ///   - error: 错误信息
    ///   - params: 事件参数（可选）
    public func trackError(_ error: String, params: [String: Any] = [:]) {
        var eventParams = params
        eventParams["error"] = error
        track("error", params: eventParams)
    }

    /// 强制上传所有待发事件
    /// - 通常在应用进入后台或退出时调用
    public func flush() {
        queue.flush()
    }
}
