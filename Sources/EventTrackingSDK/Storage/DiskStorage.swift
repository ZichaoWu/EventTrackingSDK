import Foundation

// ============================================================
// MARK: - 磁盘存储管理器
// ============================================================

/// 磁盘存储管理器，负责事件的持久化
///
/// - 为什么选择 JSONL 格式？
///   传统方式：把所有事件存到一个 JSON 文件
///   问题：每次追加都要读取整个文件 → O(n) 复杂度，数据量大时很慢
///
///   JSONL 方式：每行一个 JSON 对象
///   优点：追加时只需要在文件末尾添加一行 → O(1) 复杂度
///
///   示例：
///   {"name":"click","params":{...}}
///   {"name":"page_show","params":{...}}
///   {"name":"expose","params":{...}}
///
/// - 线程安全：
///   使用串行 DispatchQueue 保证所有磁盘操作是线程安全的
public class DiskStorage {

    public static let shared = DiskStorage()

    // 文件名：使用 JSONL 格式（JSON Lines，每行一个 JSON）
    private let fileName = "analytics_events.jsonl"
    private let failedEventsFileName = "analytics_failed_events.jsonl"
    
    // 串行队列：保证所有磁盘操作线程安全
    // 就像只有一个窗口的银行，所有人排队办理业务
    private let queue = DispatchQueue(label: "com.analytics.diskstorage", qos: .utility)

    // 文件句柄（已废弃，改用每次打开新句柄 + seekToEnd()）
    // 保留这个变量是为了兼容性，实际上不再使用
    private var fileHandle: FileHandle?
    private var failedFileHandle: FileHandle?

    private init() {
        setupFileHandles()
    }

    // MARK: - 文件路径

    /// 获取事件存储文件的 URL
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }

    /// 获取失败事件存储文件的 URL
    private var failedEventsFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(failedEventsFileName)
    }

    // MARK: - 初始化

    /// 初始化文件句柄
    /// 确保文件存在，并定位到文件末尾
    private func setupFileHandles() {
        // 确保主事件文件存在
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }

        // 确保失败事件文件存在
        if !FileManager.default.fileExists(atPath: failedEventsFileURL.path) {
            FileManager.default.createFile(atPath: failedEventsFileURL.path, contents: nil, attributes: nil)
        }

        // 尝试打开文件句柄（已废弃方式，仅保留兼容性）
        fileHandle = try? FileHandle(forUpdating: fileURL)
        failedFileHandle = try? FileHandle(forUpdating: failedEventsFileURL)

        // 定位到文件末尾
        if let handle = fileHandle {
            do {
                try handle.seekToEnd()
            } catch {
                // 如果定位失败，尝试重新打开
                fileHandle = try? FileHandle(forUpdating: fileURL)
            }
        }

        if let handle = failedFileHandle {
            do {
                try handle.seekToEnd()
            } catch {
                failedFileHandle = try? FileHandle(forUpdating: failedEventsFileURL)
            }
        }
    }

    // MARK: - 公共 API

    /// 保存事件（覆盖式）
    /// - Parameter events: 要保存的事件数组
    public func saveEvents(_ events: [Event]) {
        // 异步执行，避免阻塞主线程
        queue.async { [weak self] in
            self?.saveEventsInternal(events)
        }
    }

    /// 加载所有事件
    /// - Returns: 事件数组
    public func loadEvents() -> [Event] {
        return loadEventsFromFile(fileURL)
    }

    /// 清除所有事件
    public func clearEvents() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 关闭旧句柄
            self.fileHandle = nil
            
            // 删除文件并重建
            try? FileManager.default.removeItem(at: self.fileURL)
            FileManager.default.createFile(atPath: self.fileURL.path, contents: nil, attributes: nil)
            
            // 重新打开句柄
            self.fileHandle = try? FileHandle(forUpdating: self.fileURL)
        }
    }

    /// 追加单个事件（最常用的写入方式）
    /// - Parameter event: 要追加的事件
    public func appendEvent(_ event: Event) {
        // 异步执行，避免阻塞主线程
        queue.async { [weak self] in
            self?.appendEventInternal(event)
        }
    }

    /// 批量追加事件
    /// - Parameter events: 要追加的事件数组
    public func appendEvents(_ events: [Event]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let encoder = JSONEncoder()
                var allData = Data()
                
                // 编码每个事件为一行 JSON
                for event in events {
                    let data = try encoder.encode(event)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        // 每行以换行符结束
                        allData.append((jsonString + "\n").data(using: .utf8)!)
                    }
                }

                // 使用 seekToEnd() + 写入，避免多线程问题
                guard let handle = try? FileHandle(forWritingTo: self.fileURL) else {
                    // 如果打开失败，直接用原子写入
                    try allData.write(to: self.fileURL, options: .atomic)
                    return
                }

                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: allData)
            } catch {
                print("批量追加事件失败：\(error)")
            }
        }
    }

    // MARK: - 失败事件管理

    /// 保存失败事件
    public func saveFailedEvents(_ events: [Event]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let encoder = JSONEncoder()
                var allData = Data()
                for event in events {
                    let data = try encoder.encode(event)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        allData.append((jsonString + "\n").data(using: .utf8)!)
                    }
                }
                try allData.write(to: self.failedEventsFileURL, options: .atomic)
            } catch {
                print("保存失败事件失败：\(error)")
            }
        }
    }

    /// 加载失败事件
    public func loadFailedEvents() -> [Event] {
        return loadEventsFromFile(failedEventsFileURL)
    }

    /// 清除失败事件
    public func clearFailedEvents() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.failedFileHandle = nil
            try? FileManager.default.removeItem(at: self.failedEventsFileURL)
            FileManager.default.createFile(atPath: self.failedEventsFileURL.path, contents: nil, attributes: nil)
            self.failedFileHandle = try? FileHandle(forUpdating: self.failedEventsFileURL)
        }
    }

    /// 追加失败事件
    public func appendFailedEvent(_ event: Event) {
        queue.async { [weak self] in
            self?.appendFailedEventInternal(event)
        }
    }

    /// 批量追加失败事件
    public func appendFailedEvents(_ events: [Event]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let encoder = JSONEncoder()
                var allData = Data()
                for event in events {
                    let data = try encoder.encode(event)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        allData.append((jsonString + "\n").data(using: .utf8)!)
                    }
                }

                guard let handle = try? FileHandle(forWritingTo: self.failedEventsFileURL) else {
                    try allData.write(to: self.failedEventsFileURL, options: .atomic)
                    return
                }

                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: allData)
            } catch {
                print("批量追加失败事件失败：\(error)")
            }
        }
    }

    // MARK: - 私有方法

    /// 内部保存方法（同步）
    private func saveEventsInternal(_ events: [Event]) {
        do {
            let encoder = JSONEncoder()
            var allData = Data()
            
            for event in events {
                let data = try encoder.encode(event)
                if let jsonString = String(data: data, encoding: .utf8) {
                    allData.append((jsonString + "\n").data(using: .utf8)!)
                }
            }
            
            // 原子写入，避免写入一半时崩溃导致文件损坏
            try allData.write(to: fileURL, options: .atomic)
        } catch {
            print("保存事件失败：\(error)")
        }
    }

    /// 从文件加载事件
    /// - Parameter url: 文件 URL
    /// - Returns: 事件数组
    private func loadEventsFromFile(_ url: URL) -> [Event] {
        do {
            // 读取整个文件内容
            let content = try String(contentsOf: url, encoding: .utf8)
            
            // 按换行符分割
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            let decoder = JSONDecoder()
            var events: [Event] = []
            
            // 逐行解析
            for line in lines {
                if let data = line.data(using: .utf8),
                   let event = try? decoder.decode(Event.self, from: data) {
                    events.append(event)
                }
            }
            return events
        } catch {
            return []
        }
    }

    /// 内部追加事件方法（同步）
    /// - 使用 FileHandle(forWritingTo:) + seekToEnd() 实现追加写
    /// - 每次都打开新句柄，避免多线程共享句柄导致的问题
    private func appendEventInternal(_ event: Event) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(event)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                let lineData = (jsonString + "\n").data(using: .utf8)!

                // 关键：每次都打开新句柄 + seekToEnd()
                // 这样即使多线程同时调用，也不会有问题
                guard let handle = try? FileHandle(forWritingTo: fileURL) else {
                    // 如果打开失败，用原子写入作为后备
                    try lineData.write(to: fileURL, options: .atomic)
                    return
                }

                defer { try? handle.close() }
                
                // 定位到文件末尾
                try handle.seekToEnd()
                
                // 写入数据
                try handle.write(contentsOf: lineData)
            }
        } catch {
            print("追加事件失败：\(error)")
        }
    }

    /// 追加失败事件（内部方法）
    private func appendFailedEventInternal(_ event: Event) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(event)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                let lineData = (jsonString + "\n").data(using: .utf8)!

                guard let handle = try? FileHandle(forWritingTo: failedEventsFileURL) else {
                    try lineData.write(to: failedEventsFileURL, options: .atomic)
                    return
                }

                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: lineData)
            }
        } catch {
            print("追加失败事件失败：\(error)")
        }
    }
}
