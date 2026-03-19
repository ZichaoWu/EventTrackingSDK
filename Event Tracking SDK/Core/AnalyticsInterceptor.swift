import Foundation
import UIKit

// ============================================================
// MARK: - 拦截器协议
// ============================================================

/// 拦截器协议，用于在事件发送前对其进行修改或过滤
///
/// - AOP（面向切面编程）思想：
///   想象你在寄信前，总有人要先检查一下信件内容
///   这个"检查"就是拦截器，它可以：
///   1. 给信件贴邮票（添加设备信息）
///   2. 决定是否寄出（返回 false 阻止发送）
///   3. 修改信件内容（修改 event 参数）
public protocol AnalyticsInterceptor: AnyObject {
    
    /// 拦截并处理事件
    /// - Parameter event: 要处理的事件（可以修改）
    /// - Returns: true = 继续传递，false = 终止事件（不发送）
    func intercept(event: inout Event) -> Bool
}

// ============================================================
// MARK: - 默认拦截器
// ============================================================

/// 默认拦截器，自动为每个事件添加设备信息
///
/// 它就像一个"贴邮票"的服务，每封信件都会自动贴上：
/// - device_id: 设备唯一标识
/// - app_version: App 版本号
/// - os_version: iOS 系统版本
/// - device_model: 设备型号
/// - locale: 地区设置
public class DefaultInterceptor: AnalyticsInterceptor {

    public static let shared = DefaultInterceptor()

    private init() {}

    public func intercept(event: inout Event) -> Bool {
        // 复制原有的参数字典
        var params = event.params

        // 注入设备信息（就像给信件贴邮票）
        params["device_id"] = AnyCodable(getDeviceId())        // 设备唯一标识
        params["app_version"] = AnyCodable(getAppVersion())    // App 版本
        params["os_version"] = AnyCodable(getOSVersion())      // iOS 版本
        params["device_model"] = AnyCodable(getDeviceModel())  // 设备型号
        params["locale"] = AnyCodable(getLocale())             // 地区设置

        // 重新创建 Event，保留原值，只更新 params
        event = Event(
            id: event.id,
            name: event.name,
            params: params,
            timestamp: event.timestamp,
            eventId: event.eventId,
            eventType: event.eventType,
            page: event.page,
            element: event.element,
            userId: event.userId,
            sessionId: event.sessionId
        )

        // 返回 true 表示事件继续传递（没有被拦截）
        return true
    }

    /// 获取设备唯一标识
    /// 如果获取不到，返回 "unknown"
    private func getDeviceId() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    /// 获取 App 版本号
    /// 读取 Info.plist 中的 CFBundleShortVersionString
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    /// 获取 iOS 系统版本
    private func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }

    /// 获取设备型号
    /// 通过 uname 系统调用获取，如 "iPhone14,2"
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    /// 获取当前地区标识
    /// 如 "zh_CN"、"en_US" 等
    private func getLocale() -> String {
        return Locale.current.identifier
    }
}

// ============================================================
// MARK: - 拦截器链
// ============================================================

/// 拦截器链，管理多个拦截器
///
/// 想象一个"安检通道"：
/// 1. 第一个人检查包裹（拦截器1）
/// 2. 第二个人检查危险品（拦截器2）
/// 3. 第三个人称重（拦截器3）
/// ...
/// 每个拦截器都有机会修改或阻止事件
///
/// - 特点：
///   - 可以添加多个拦截器
///   - 按添加顺序执行
///   - 任何一个返回 false 都会终止事件
public class InterceptorChain {

    /// 单例，全局唯一
    public static let shared = InterceptorChain()

    /// 拦截器列表
    private var interceptors: [AnalyticsInterceptor] = []

    /// 私有初始化，确保单例
    private init() {
        // 默认添加设备信息拦截器
        addInterceptor(DefaultInterceptor.shared)
    }

    /// 添加拦截器
    /// - Parameter interceptor: 要添加的拦截器
    public func addInterceptor(_ interceptor: AnalyticsInterceptor) {
        interceptors.append(interceptor)
    }

    /// 移除拦截器
    /// - Parameter interceptor: 要移除的拦截器（按类型移除）
    public func removeInterceptor(_ interceptor: AnalyticsInterceptor) {
        interceptors.removeAll { type(of: $0) === type(of: interceptor) }
    }

    /// 清空所有拦截器
    /// 注意：这会清空默认的设备信息拦截器
    public func clearInterceptors() {
        interceptors.removeAll()
    }

    /// 处理事件（inout 方式）
    /// - Parameter event: 要处理的事件
    /// - Returns: true = 继续传递，false = 被某个拦截器终止
    public func process(event: inout Event) -> Bool {
        for interceptor in interceptors {
            // 如果任何一个拦截器返回 false，终止传递
            if !interceptor.intercept(event: &event) {
                return false
            }
        }
        return true
    }

    /// 处理事件（复制方式，更安全）
    /// - Parameter event: 要处理的事件
    /// - Returns: 处理后的事件，如果被拦截则返回 nil
    public func processEvent(_ event: Event) -> Event? {
        var processedEvent = event
        for interceptor in interceptors {
            if !interceptor.intercept(event: &processedEvent) {
                // 事件被拦截，返回 nil
                return nil
            }
        }
        return processedEvent
    }
}
