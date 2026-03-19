import Foundation

/// 配置管理器，负责管理 SDK 的各种配置
public class AnalyticsConfig {

    /// 单例实例
    public static let shared = AnalyticsConfig()

    /// 线程锁，保护配置的并发访问
    private let lock = NSLock()

    /// 是否启用埋点
    private var trackingEnabled: Bool = true
    
    /// 全局采样率（0.0-1.0）
    private var samplingRate: Double = 1.0
    
    /// 是否开启调试模式
    private var isDebugMode: Bool = false
    
    /// 事件级配置
    private var eventConfigs: [String: EventConfig] = [:]

    /// 私有初始化，确保单例
    /// - 初始化时从 UserDefaults 加载配置
    private init() {
        loadConfig()
    }

    /// 事件配置结构体
    public struct EventConfig: Codable {
        
        /// 是否启用该事件
        public let enabled: Bool
        
        /// 该事件的采样率
        public let samplingRate: Double

        /// 初始化事件配置
        /// - Parameters:
        ///   - enabled: 是否启用（默认 true）
        ///   - samplingRate: 采样率（默认 1.0）
        public init(enabled: Bool = true, samplingRate: Double = 1.0) {
            self.enabled = enabled
            self.samplingRate = samplingRate
        }
    }

    /// 设置是否启用埋点
    /// - Parameter enabled: 是否启用
    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        trackingEnabled = enabled
        saveConfig()
        lock.unlock()
    }

    /// 获取是否启用埋点
    /// - Returns: 是否启用
    public func isTrackingEnabled() -> Bool {
        lock.lock()
        let enabled = trackingEnabled
        lock.unlock()
        return enabled
    }

    /// 设置是否开启调试模式
    /// - Parameter enabled: 是否开启
    public func setDebugMode(_ enabled: Bool) {
        lock.lock()
        isDebugMode = enabled
        lock.unlock()
    }

    /// 获取是否开启调试模式
    /// - Returns: 是否开启
    public func isDebug() -> Bool {
        lock.lock()
        let debug = isDebugMode
        lock.unlock()
        return debug
    }

    /// 设置全局采样率
    /// - Parameter rate: 采样率（0.0-1.0）
    public func setSamplingRate(_ rate: Double) {
        lock.lock()
        // 确保采样率在 0.0-1.0 之间
        samplingRate = max(0.0, min(1.0, rate))
        saveConfig()
        lock.unlock()
    }

    /// 获取全局采样率
    /// - Returns: 采样率
    public func getSamplingRate() -> Double {
        lock.lock()
        let rate = samplingRate
        lock.unlock()
        return rate
    }

    /// 判断是否应该采样（基于全局采样率）
    /// - Returns: 是否应该采样
    public func shouldSample() -> Bool {
        lock.lock()
        let rate = samplingRate
        lock.unlock()

        if rate >= 1.0 {
            return true
        }

        if rate <= 0.0 {
            return false
        }

        // 随机生成 0-1 之间的数，小于采样率则采样
        let random = Double.random(in: 0...1)
        return random < rate
    }

    /// 判断某个事件是否启用
    /// - Parameter eventName: 事件名称
    /// - Returns: 是否启用
    public func isEventEnabled(_ eventName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if !trackingEnabled {
            return false
        }

        if let config = eventConfigs[eventName] {
            return config.enabled
        }

        return true
    }

    /// 获取某个事件的采样率
    /// - Parameter eventName: 事件名称
    /// - Returns: 采样率
    public func getEventSamplingRate(_ eventName: String) -> Double {
        lock.lock()
        defer { lock.unlock() }

        if let config = eventConfigs[eventName] {
            return config.samplingRate
        }

        return samplingRate
    }

    /// 判断某个事件是否应该采样
    /// - Parameter eventName: 事件名称
    /// - Returns: 是否应该采样
    public func shouldSampleEvent(_ eventName: String) -> Bool {
        lock.lock()
        let isGlobalEnabled = trackingEnabled
        let globalRate = samplingRate
        let eventConfig = eventConfigs[eventName]
        lock.unlock()

        if !isGlobalEnabled {
            return false
        }

        let rate: Double
        let enabled: Bool

        if let config = eventConfig {
            rate = config.samplingRate
            enabled = config.enabled
        } else {
            rate = globalRate
            enabled = true
        }

        if !enabled {
            return false
        }

        if rate >= 1.0 {
            return true
        }

        if rate <= 0.0 {
            return false
        }

        let random = Double.random(in: 0...1)
        return random < rate
    }

    /// 设置某个事件的配置
    /// - Parameters:
    ///   - eventName: 事件名称
    ///   - config: 事件配置
    public func setEventConfig(_ eventName: String, config: EventConfig) {
        lock.lock()
        eventConfigs[eventName] = config
        saveConfig()
        lock.unlock()
    }

    /// 移除某个事件的配置
    /// - Parameter eventName: 事件名称
    public func removeEventConfig(_ eventName: String) {
        lock.lock()
        eventConfigs.removeValue(forKey: eventName)
        saveConfig()
        lock.unlock()
    }

    /// 清空所有事件配置
    public func clearEventConfigs() {
        lock.lock()
        eventConfigs.removeAll()
        saveConfig()
        lock.unlock()
    }

    /// 保存配置到 UserDefaults
    private func saveConfig() {
        var config: [String: Any] = [
            "trackingEnabled": trackingEnabled,
            "samplingRate": samplingRate
        ]

        var eventConfigsDict: [String: [String: Any]] = [:]
        for (key, value) in eventConfigs {
            eventConfigsDict[key] = [
                "enabled": value.enabled,
                "samplingRate": value.samplingRate
            ]
        }
        config["eventConfigs"] = eventConfigsDict

        UserDefaults.standard.set(config, forKey: "analytics_config")
    }

    /// 从 UserDefaults 加载配置
    private func loadConfig() {
        guard let config = UserDefaults.standard.dictionary(forKey: "analytics_config") else {
            return
        }

        if let enabled = config["trackingEnabled"] as? Bool {
            trackingEnabled = enabled
        }

        if let rate = config["samplingRate"] as? Double {
            samplingRate = rate
        }

        if let eventConfigsDict = config["eventConfigs"] as? [String: [String: Any]] {
            for (key, value) in eventConfigsDict {
                let enabled = value["enabled"] as? Bool ?? true
                let rate = value["samplingRate"] as? Double ?? 1.0
                eventConfigs[key] = EventConfig(enabled: enabled, samplingRate: rate)
            }
        }
    }

    /// 从服务端更新配置
    /// - Parameter configData: 配置数据（JSON 格式）
    public func updateConfigFromServer(_ configData: Data) {
        lock.lock()
        defer { lock.unlock() }

        guard let json = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] else {
            return
        }

        if let enabled = json["isEnabled"] as? Bool {
            trackingEnabled = enabled
        }

        if let rate = json["samplingRate"] as? Double {
            samplingRate = rate
        }

        if let events = json["events"] as? [String: [String: Any]] {
            for (key, value) in events {
                let enabled = value["enabled"] as? Bool ?? true
                let rate = value["samplingRate"] as? Double ?? 1.0
                eventConfigs[key] = EventConfig(enabled: enabled, samplingRate: rate)
            }
        }

        saveConfig()
    }

    /// 获取配置的 JSON 字符串
    /// - Returns: JSON 字符串
    public func getConfigJSON() -> String? {
        lock.lock()
        let config: [String: Any] = [
            "trackingEnabled": trackingEnabled,
            "samplingRate": samplingRate,
            "eventConfigs": eventConfigs.mapValues { ["enabled": $0.enabled, "samplingRate": $0.samplingRate] }
        ]
        lock.unlock()

        guard let data = try? JSONSerialization.data(withJSONObject: config),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }
}
