import Foundation
import CoreData

/// 上传结果枚举
public enum UploadResult {
    /// 上传成功
    case success
    /// 上传失败（包含错误信息）
    case failure(Error)
}

/// 上传管理器，负责将事件上传到服务器
public class UploadManager {

    /// 单例实例
    public static let shared = UploadManager()

    /// 最大重试次数
    private let maxRetryCount = 3
    
    /// 基础重试间隔（1秒）
    private let baseRetryInterval: TimeInterval = 1.0
    
    /// 上传队列，确保上传操作串行执行
    private let uploadQueue = DispatchQueue(label: "com.analytics.upload", qos: .utility)
    
    /// 失败事件队列
    private var failedEvents: [Event] = []
    
    /// 是否正在上传
    private var isUploading = false

    /// 服务器 URL
    private var serverURL: URL?

    /// 私有初始化，确保单例
    /// - 初始化时加载失败事件
    private init() {
        loadFailedEvents()
    }

    /// 设置服务器 URL
    /// - Parameter url: 服务器 URL
    public func setServerURL(_ url: URL) {
        self.serverURL = url
    }

    /// 设置服务器 URL（字符串形式）
    /// - Parameter urlString: 服务器 URL 字符串
    public func setServerURL(_ urlString: String) {
        self.serverURL = URL(string: urlString)
    }

    /// 加载失败事件
    /// - 从磁盘加载之前上传失败的事件
    private func loadFailedEvents() {
        let events = DiskStorage.shared.loadFailedEvents()
        failedEvents = events
        if !events.isEmpty {
            print("加载了 \(events.count) 个失败事件，准备重传")
        }
    }

    /// 上传事件
    /// - Parameters:
    ///   - events: 要上传的事件数组
    ///   - completion: 上传完成回调
    public func upload(_ events: [Event], completion: ((Bool) -> Void)? = nil) {
        uploadQueue.async { [weak self] in
            guard let self = self else { return }

            // 防止并发上传
            guard !self.isUploading else {
                print("正在上传中，跳过本次请求")
                completion?(false)
                return
            }

            self.isUploading = true
            defer {
                self.isUploading = false
            }

            self.performUpload(events, retryCount: 0, completion: completion)
        }
    }

    /// 执行上传
    /// - Parameters:
    ///   - events: 要上传的事件数组
    ///   - retryCount: 当前重试次数
    ///   - completion: 上传完成回调
    private func performUpload(_ events: [Event], retryCount: Int, completion: ((Bool) -> Void)?) {
        // 防御：没有事件则直接返回成功
        guard !events.isEmpty else {
            completion?(true)
            return
        }

        // 防御：没有设置服务器 URL 则打印模拟数据
        guard let serverURL = serverURL else {
            print("未设置服务器 URL，仅打印模拟数据：")
            print("上传事件数量：\(events.count)")
            completion?(true)
            return
        }

        // 生成批次 ID
        let batchId = UUID().uuidString

        do {
            let encoder = JSONEncoder()
            var data = try encoder.encode(events)

            // 压缩数据
            if let compressedData = compress(data: data) {
                data = compressedData
                print("数据已压缩: \(data.count) bytes")
            }

            // 构建请求
            var request = URLRequest(url: serverURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            request.setValue(batchId, forHTTPHeaderField: "X-Batch-Id")
            request.setValue(String(events.count), forHTTPHeaderField: "X-Batch-Count")
            request.httpBody = data
            request.timeoutInterval = 30

            print("批次ID: \(batchId), 事件数: \(events.count)")

            // 发送请求
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }

                if let error = error {
                    print("上传失败: \(error.localizedDescription)")
                    self.handleUploadFailure(events: events, retryCount: retryCount, error: error)
                    completion?(false)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        print("上传成功，状态码: \(httpResponse.statusCode)")
                        self.handleUploadSuccess(events: events)
                        completion?(true)
                    } else {
                        print("上传失败，状态码: \(httpResponse.statusCode)")
                        let error = NSError(domain: "UploadError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error"])
                        self.handleUploadFailure(events: events, retryCount: retryCount, error: error)
                        completion?(false)
                    }
                }
            }

            task.resume()

        } catch {
            print("上传失败: \(error.localizedDescription)")
            handleUploadFailure(events: events, retryCount: retryCount, error: error)
            completion?(false)
        }
    }

    /// 处理上传成功
    /// - Parameter events: 成功上传的事件
    private func handleUploadSuccess(events: [Event]) {
        let successIds = Set(events.map { $0.id })
        
        // 从失败队列中移除成功的事件
        failedEvents.removeAll { event in
            successIds.contains(event.id)
        }
        
        // 保存失败事件
        if !failedEvents.isEmpty {
            DiskStorage.shared.saveFailedEvents(failedEvents)
        } else {
            DiskStorage.shared.clearFailedEvents()
        }
    }

    /// 处理上传失败
    /// - Parameters:
    ///   - events: 上传失败的事件
    ///   - retryCount: 当前重试次数
    ///   - error: 错误信息
    private func handleUploadFailure(events: [Event], retryCount: Int, error: Error) {
        if retryCount < maxRetryCount {
            // 指数退避重试
            let retryInterval = baseRetryInterval * pow(2.0, Double(retryCount))
            print("将在 \(retryInterval) 秒后重试 (当前重试次数: \(retryCount + 1)/\(maxRetryCount))")

            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval) { [weak self] in
                self?.uploadQueue.async { [weak self] in
                    self?.performUpload(events, retryCount: retryCount + 1, completion: nil)
                }
            }
        } else {
            // 重试次数已达上限，保存到磁盘
            print("重试次数已达上限，将事件保存到磁盘")
            saveFailedEventsToDisk(events)
        }
    }

    /// 保存失败事件到磁盘
    /// - Parameter newEvents: 新的失败事件
    private func saveFailedEventsToDisk(_ newEvents: [Event]) {
        // 过滤掉已存在的事件
        let eventsToAdd = newEvents.filter { newEvent in
            !failedEvents.contains { $0.id == newEvent.id }
        }
        
        failedEvents.append(contentsOf: eventsToAdd)
        DiskStorage.shared.saveFailedEvents(failedEvents)
        print("失败事件已保存到磁盘，当前失败事件数: \(failedEvents.count)")
    }

    /// 重试失败事件
    /// - 重新上传之前失败的事件
    public func retryFailedEvents() {
        let events = DiskStorage.shared.loadFailedEvents()
        guard !events.isEmpty else {
            print("没有需要重传的事件")
            return
        }

        print("开始重传 \(events.count) 个失败事件")
        upload(events)
    }

    /// 压缩数据
    /// - Parameter data: 原始数据
    /// - Returns: 压缩后的数据
    private func compress(data: Data) -> Data? {
        guard let compressedData = try? (data as NSData).compressed(using: .zlib) as Data else {
            return nil
        }
        return compressedData
    }

    /// 获取失败事件数量
    /// - Returns: 失败事件数量
    public func getFailedEventsCount() -> Int {
        return failedEvents.count
    }

    /// 清除失败事件
    public func clearFailedEvents() {
        failedEvents.removeAll()
        DiskStorage.shared.clearFailedEvents()
    }
}
