import Foundation

/// 会话管理器，负责管理用户会话
public class SessionManager {

    /// 单例实例
    public static let shared = SessionManager()

    /// 会话 ID
    private var sessionId: String
    
    /// 会话开始时间
    private var sessionStartTime: Date
    
    /// 上次活动时间
    private var lastActiveTime: Date
    
    /// 线程锁，保护会话信息的并发访问
    private let lock = NSLock()
    
    /// 会话超时时间（30分钟）
    private let sessionTimeout: TimeInterval = 30 * 60

    /// 会话 ID 的 UserDefaults key
    private let sessionIdKey = "analytics_session_id"
    
    /// 会话开始时间的 UserDefaults key
    private let sessionStartTimeKey = "analytics_session_start_time"

    /// 私有初始化，确保单例
    /// - 初始化时创建新的会话
    private init() {
        // 生成新的会话 ID
        sessionId = UUID().uuidString
        // 设置会话开始时间
        sessionStartTime = Date()
        // 初始化上次活动时间
        lastActiveTime = sessionStartTime
        // 保存会话信息
        saveSessionInfo()
    }

    /// 获取会话 ID
    /// - Returns: 会话 ID
    public func getSessionId() -> String {
        lock.lock()
        let id = sessionId
        lock.unlock()
        return id
    }

    /// 获取会话开始时间
    /// - Returns: 会话开始时间
    public func getSessionStartTime() -> Date {
        lock.lock()
        let time = sessionStartTime
        lock.unlock()
        return time
    }

    /// 获取会话持续时长
    /// - Returns: 会话持续时长（秒）
    public func getSessionDuration() -> TimeInterval {
        lock.lock()
        let duration = Date().timeIntervalSince(sessionStartTime)
        lock.unlock()
        return duration
    }

    /// 更新上次活动时间
    /// - 通常在每次埋点时调用
    public func updateLastActiveTime() {
        lock.lock()
        lastActiveTime = Date()
        lock.unlock()
    }

    /// 获取上次活动时间
    /// - Returns: 上次活动时间
    public func getLastActiveTime() -> Date {
        lock.lock()
        let time = lastActiveTime
        lock.unlock()
        return time
    }

    /// 检查会话是否活跃
    /// - Returns: 是否活跃
    public func isSessionActive() -> Bool {
        lock.lock()
        let inactiveDuration = Date().timeIntervalSince(lastActiveTime)
        lock.unlock()
        return inactiveDuration < sessionTimeout
    }

    /// 检查并更新会话
    /// - Parameter completion: 回调，返回新的会话 ID（如果有）
    /// - 逻辑：
    ///   1. 检查上次活动时间
    ///   2. 如果超过超时时间，创建新会话
    ///   3. 否则，更新活动时间
    public func checkAndRenewSessionIfNeeded(completion: @escaping (String?) -> Void) {
        lock.lock()
        let inactiveDuration = Date().timeIntervalSince(lastActiveTime)
        let currentSessionId = sessionId
        lock.unlock()

        if inactiveDuration >= sessionTimeout {
            // 会话已过期，创建新会话
            lock.lock()
            sessionId = UUID().uuidString
            sessionStartTime = Date()
            lastActiveTime = Date()
            let newSessionId = sessionId
            lock.unlock()

            saveSessionInfo()
            print("Session 已过期，创建新 session: \(newSessionId)")
            completion(newSessionId)
        } else {
            // 会话仍然活跃，更新活动时间
            lock.lock()
            lastActiveTime = Date()
            lock.unlock()
            completion(currentSessionId)
        }
    }

    /// 保存会话信息到 UserDefaults
    private func saveSessionInfo() {
        lock.lock()
        let id = sessionId
        let startTime = sessionStartTime
        lock.unlock()

        UserDefaults.standard.set(id, forKey: sessionIdKey)
        UserDefaults.standard.set(startTime.timeIntervalSince1970, forKey: sessionStartTimeKey)
    }

    /// 从 UserDefaults 恢复会话
    /// - Returns: 会话信息（会话 ID 和开始时间）
    public func restoreSession() -> (sessionId: String, startTime: Date)? {
        guard let savedSessionId = UserDefaults.standard.string(forKey: sessionIdKey),
              let savedStartTimeInterval = UserDefaults.standard.double(forKey: sessionStartTimeKey) as Double?,
              savedStartTimeInterval > 0 else {
            return nil
        }

        let startTime = Date(timeIntervalSince1970: savedStartTimeInterval)
        return (savedSessionId, startTime)
    }

    /// 清除会话信息
    /// - 通常在用户退出登录时调用
    public func clearSession() {
        lock.lock()
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        lastActiveTime = Date()
        lock.unlock()

        UserDefaults.standard.removeObject(forKey: sessionIdKey)
        UserDefaults.standard.removeObject(forKey: sessionStartTimeKey)
    }
}
