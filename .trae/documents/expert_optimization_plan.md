# 埋点 SDK 专家级优化计划

## 概述
基于架构评审反馈，对现有 SDK 进行6项专家级优化，使其达到字节/阿里 P7+ 水平。

---

## 优化任务清单

### Task 1: ExposureManager - 强制 ExposureTrackable 协议
**问题**: 当前 fallback key (`section_row`) 不稳定，数据变动会重复曝光

**优化方案**:
- 修改 `generateKey` 方法，移除 fallback 逻辑
- 强制要求实现 `ExposureTrackable` 协议
- 添加编译时检查，未实现协议则编译报错

**文件**: `ExposureManager.swift`

**修改点**:
```swift
// 删除 fallback 逻辑，只保留 exposureId
private func generateKey(for indexPath: IndexPath, in tableView: UITableView) -> String {
    guard let model = getModel(for: indexPath, in: tableView) as? ExposureTrackable else {
        fatalError("必须实现 ExposureTrackable 协议")
    }
    return model.exposureId
}
```

---

### Task 2: UIViewController+Track.swift - 精确过滤主工程 VC
**问题**: `hasPrefix("UI")` 会误伤自定义模块

**优化方案**:
- 使用 `Bundle(for: type(of: self)) == Bundle.main` 判断
- 只跟踪主工程 VC，避免 SDK 自身 VC 被跟踪

**文件**: `UIViewController+Track.swift`

**修改点**:
```swift
private func isMainAppViewController() -> Bool {
    guard let bundle = Bundle(for: type(of: self)) as Bundle? else {
        return false
    }
    return bundle == Bundle.main
}
```

---

### Task 3: DiskStorage - 优化 FileHandle 使用
**问题**: `FileHandle(forUpdating:)` 多线程 reopen 风险

**优化方案**:
- 每次写入使用 `FileHandle(forWritingTo:)` + `seekToEnd()`
- 或保持单线程写，永不重建 handle
- 添加文件锁保护

**文件**: `DiskStorage.swift`

**修改点**:
```swift
private func appendEventInternal(_ event: Event) {
    guard let handle = try? FileHandle(forWritingTo: fileURL) else {
        // fallback to direct write
        writeEventDirectly(event)
        return
    }
    defer { try? handle.close() }

    do {
        try handle.seekToEnd()
        // write data...
    }
}
```

---

### Task 4: EventQueue - 添加 flush buffer 防止竞态
**问题**: flush 时 enqueue 的新事件可能顺序错乱

**优化方案**:
- 添加 `flushingEvents` buffer
- 使用生产者-消费者模型分离读写

**文件**: `EventQueue.swift`

**修改点**:
```swift
private var events: [Event] = []
private var flushingEvents: [Event] = []

public func flush() {
    queue.async { [weak self] in
        guard let self = self else { return }
        guard !self.events.isEmpty else { return }

        // 交换 buffer
        let eventsToFlush = self.events
        self.events.removeAll()

        // 上传时，新事件可以继续进入 events
        UploadManager.shared.upload(eventsToFlush) { success in
            // 处理结果...
        }
    }
}
```

---

### Task 5: UploadManager - 添加批次 ID
**问题**: 服务端无法去重和追踪日志

**优化方案**:
- 为每次上传生成唯一 `batchId`
- 添加到请求 Header
- 用于服务端去重和日志追踪

**文件**: `UploadManager.swift`

**修改点**:
```swift
public struct UploadBatch {
    let batchId: String
    let events: [Event]
    let timestamp: TimeInterval
}

private func performUpload(_ events: [Event], ...) {
    let batchId = UUID().uuidString
    request.setValue(batchId, forHTTPHeaderField: "X-Batch-Id")
    // ...
}
```

---

### Task 6: InterceptorChain - 支持事件拦截/终止
**问题**: 当前只能修改事件，无法终止

**优化方案**:
- 修改协议返回 Bool
- 支持拦截（终止事件）和修改

**文件**: `AnalyticsInterceptor.swift`

**修改点**:
```swift
public protocol AnalyticsInterceptor: AnyObject {
    func intercept(event: inout Event) -> Bool // 返回 false 可终止事件
}

public class InterceptorChain {
    public func processEvent(_ event: Event) -> Event? {
        var processedEvent = event
        for interceptor in interceptors {
            if !interceptor.intercept(event: &processedEvent) {
                return nil // 事件被拦截
            }
        }
        return processedEvent
    }
}
```

---

## 实施顺序

1. Task 1 (ExposureManager) - 优先级最高
2. Task 2 (UIViewController) - 防止误跟踪
3. Task 3 (DiskStorage) - 性能与安全
4. Task 4 (EventQueue) - 数据顺序保证
5. Task 5 (UploadManager) - 可观测性
6. Task 6 (Interceptor) - 扩展性

---

## 验收标准

- [ ] 所有优化项编译通过
- [ ] 无新增警告
- [ ] 单元测试覆盖新增逻辑
- [ ] 专家级优化点全部落地
