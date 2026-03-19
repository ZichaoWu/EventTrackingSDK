# iOS 埋点 SDK 深度优化计划

根据最新评价，解决架构层面的严重设计问题并提升到高级 SDK 水平。

## [x] 任务 1: 修复 UploadManager Semaphore 问题
- **优先级**: P0
- **状态**: ✅ 已完成
- **修改**: 移除 DispatchSemaphore，改用完全异步化

## [x] 任务 2: 修复 failedEvents 内存与磁盘不一致
- **优先级**: P0
- **状态**: ✅ 已完成
- **修改**: 只删除成功的事件，失败的事件重新写回磁盘

## [x] 任务 3: 添加 Session 自动续期机制
- **优先级**: P0
- **状态**: ✅ 已完成
- **修改**: 添加 checkAndRenewSessionIfNeeded 方法，超时自动创建新 session

## [x] 任务 4: 修复 Exposure key 设计问题
- **优先级**: P1
- **状态**: ✅ 已完成
- **修改**: 创建 ExposureTrackable protocol，支持 UITableViewDiffableDataSource

## [x] 任务 5: 修复 Timer 在主线程问题
- **优先级**: P1
- **状态**: ✅ 已完成
- **修改**: 将 Timer.scheduledTimer 改为 DispatchSourceTimer

## [x] 任务 6: 修复 AnyCodable 类型支持
- **优先级**: P1
- **状态**: ✅ 已完成
- **修改**: 添加 Int64、Float、Date、URL、Data 等类型支持

## [x] 任务 7: 添加网络自动埋点（高级）
- **优先级**: P2
- **状态**: ✅ 已完成
- **修改**: 创建 NetworkHook.swift，实现 URLSession 拦截

## [x] 任务 8: 添加崩溃捕获（高级）
- **优先级**: P2
- **状态**: ✅ 已完成
- **修改**: 创建 CrashReporter.swift，实现 signal 和 exception 捕获

## [ ] 任务 9: 多线程模型优化（可选）
- **优先级**: P2
- **状态**: ⏸️ 待定
- **说明**: 可选的后续优化，使用 Actor 替代 NSLock

## 优化后的架构

```
业务层（VC / View）
        ↓
Analytics.track(...)
        ↓
SDK 内部
   ├── 配置中心（开关/采样）
   ├── Session 管理（自动续期）
   ├── 自动页面曝光（Hook）
   ├── 列表曝光管理（ExposureTrackable protocol）
   ├── 事件队列（DispatchSourceTimer 后台 flush）
   ├── 本地缓存（NSRecursiveLock 线程安全）
   ├── 批量上报（gzip 压缩 + 异步上传）
   ├── 上传管理（无 semaphore + 指数退避重试）
   ├── 网络自动埋点（URLSession hook）
   └── 崩溃捕获（signal + exception）
```

## 编译结果

✅ BUILD SUCCEEDED
