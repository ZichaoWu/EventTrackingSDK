import Foundation

// ============================================================
// MARK: - 事件队列
// ============================================================

/// 事件队列，管理事件的收集、存储和批量上传
///
/// - 工作流程：
///   1. track() 被调用 → 事件进入队列 (enqueue)
///   2. 达到 20 条 → 自动触发上传 (flush)
///   3. 每 10 秒 → 定时触发上传
///   4. 应用进入后台 → 强制上传
///
/// - 核心特性：
///   1. 串行队列：避免多线程竞态条件
///   2. 批量上传：减少网络请求次数
///   3. 自动持久化：崩溃不丢数据
///   4. 失败重试：上传失败会保存到磁盘，下次继续上传
public class EventQueue {

    /// 单例
    public static let shared = EventQueue()

    // MARK: - 属性

    /// 内存中的事件队列
    /// 就像一个"待发件箱"，新事件先到这里
    private var events: [Event] = []

    /// 正在上传的事件（用于区分正在处理的事件）
    /// 避免 flush 期间新事件丢失
    private var flushingEvents: [Event] = []

    /// 串行队列：保证所有操作线程安全
    /// 关键点：只用一个队列，避免了加锁的复杂性
    /// 想象：只有一个收银员的超市，所有人排队结账
    private let queue = DispatchQueue(label: "com.analytics.eventqueue", qos: .utility)

    /// 定时器：用于自动上传
    private var flushTimer: DispatchSourceTimer?

    /// 定时器专属队列
    /// 定时器需要在独立队列运行，避免被其他任务阻塞
    private let flushQueue = DispatchQueue(label: "com.analytics.timer", qos: .utility)

    /// 上传间隔：10 秒
    /// 每 10 秒检查一次是否有待上传事件
    private let flushInterval: TimeInterval = 10.0

    /// UserDefaults key（已废弃，保留兼容性）
    private let pendingEventsKey = "analytics_pending_events"

    // MARK: - 初始化

    private init() {
        // 启动定时上传
        startFlushTimer()
        
        // 从磁盘恢复之前未上传的事件
        restoreEventsFromDisk()
    }

    deinit {
        // 销毁时停止定时器
        stopFlushTimer()
    }

    // MARK: - 定时器管理

    /// 启动定时上传定时器
    /// 使用 DispatchSourceTimer 实现，比 Timer 更轻量
    private func startFlushTimer() {
        flushQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 创建定时器
            self.flushTimer = DispatchSource.makeTimerSource(queue: self.flushQueue)
            
            // 设置：首次延迟 10 秒，之后每 10 秒执行一次
            self.flushTimer?.schedule(deadline: .now() + self.flushInterval, repeating: self.flushInterval)
            
            // 设置回调
            self.flushTimer?.setEventHandler { [weak self] in
                self?.flush()
            }
            
            // 启动定时器
            self.flushTimer?.resume()
        }
    }

    /// 停止定时器
    private func stopFlushTimer() {
        flushTimer?.cancel()
        flushTimer = nil
    }

    // MARK: - 事件管理

    /// 从磁盘恢复事件
    /// 应用启动时调用，将之前未上传的事件加载到内存
    private func restoreEventsFromDisk() {
        let cachedEvents = DiskStorage.shared.loadEvents()
        guard !cachedEvents.isEmpty else { return }

        // 异步添加到队列
        queue.async { [weak self] in
            self?.events.append(contentsOf: cachedEvents)
            print("从磁盘恢复了 \(cachedEvents.count) 个事件")
        }
    }

    /// 添加事件到队列
    /// - Parameter event: 要添加的事件
    public func enqueue(_ event: Event) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 添加到内存队列
            self.events.append(event)
            
            // 检查是否达到批量上传阈值
            let shouldFlush = self.events.count >= 20

            // 同时持久化到磁盘（防止崩溃丢失）
            DiskStorage.shared.appendEvent(event)

            // 达到阈值则触发上传
            if shouldFlush {
                self.flush()
            }
        }
    }

    /// 强制上传所有待发事件
    /// 在以下情况调用：
    /// 1. 达到批量阈值（20条）
    /// 2. 定时器触发
    /// 3. 应用进入后台
    public func flush() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 防御：确保有事件才上传
            guard !self.events.isEmpty else { return }

            // 取出要上传的事件
            let eventsToFlush = self.events
            
            // 清空队列（关键：此时新事件可以继续进入 events）
            self.events.removeAll()

            // 记录要上传的事件 ID，用于后续清理磁盘
            let eventIds = Set(eventsToFlush.map { $0.id })

            // 调用上传管理器
            UploadManager.shared.upload(eventsToFlush) { success in
                if success {
                    // 上传成功：删除磁盘中对应事件
                    self.clearPersistedEvents(keepingIds: [], eventIds: eventIds)
                } else {
                    // 上传失败：保存回磁盘，等待下次重试
                    self.restoreEventsToDisk(events: eventsToFlush)
                }
            }
        }
    }

    // MARK: - 磁盘操作

    /// 清除已上传的事件（从磁盘）
    /// - Parameters:
    ///   - keepingIds: 要保留的事件 ID（暂未使用）
    ///   - eventIds: 要删除的事件 ID
    private func clearPersistedEvents(keepingIds: Set<String>, eventIds: Set<String>) {
        // 读取磁盘所有事件
        let allPersisted = DiskStorage.shared.loadEvents()
        
        // 过滤掉已上传的
        let filtered = allPersisted.filter { !eventIds.contains($0.id) }

        if filtered.isEmpty {
            // 如果全部上传成功，清空文件
            DiskStorage.shared.clearEvents()
        } else {
            // 否则保存剩余事件
            DiskStorage.shared.saveEvents(filtered)
        }
    }

    /// 将失败的事件保存回磁盘
    private func restoreEventsToDisk(events: [Event]) {
        // 读取现有事件
        let existingEvents = DiskStorage.shared.loadEvents()
        var allEvents = existingEvents

        // 合并事件（避免重复）
        for event in events {
            if !allEvents.contains(where: { $0.id == event.id }) {
                allEvents.append(event)
            }
        }

        // 保存到磁盘
        DiskStorage.shared.saveEvents(allEvents)
    }

    // MARK: - 公共 API

    /// 获取当前队列中的事件数量
    public func getEventsCount() -> Int {
        var count = 0
        // 使用 sync 同步获取（只在需要同步值时使用）
        queue.sync {
            count = self.events.count
        }
        return count
    }

    /// 暂停定时上传
    /// 适用于特殊场景，如播放视频时暂停上传节省电量
    public func pauseTimer() {
        stopFlushTimer()
    }

    /// 恢复定时上传
    public func resumeTimer() {
        startFlushTimer()
    }
}
