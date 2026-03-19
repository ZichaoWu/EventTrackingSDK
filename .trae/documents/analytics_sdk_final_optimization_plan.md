# iOS 埋点 SDK 进一步优化计划

根据最新评价，解决剩余的架构问题。

## [x] 任务 1: EventQueue 持久化（致命问题修复）
- **优先级**: P0
- **状态**: ✅ 已完成
- **修改**: enqueue 时写入磁盘，flush 成功后清除，启动时恢复

## [x] 任务 2: 增强 Exposure key 设计
- **优先级**: P1
- **状态**: ✅ 已完成
- **修改**: 强制使用 ExposureTrackable.exposureId，indexPath 作为 fallback

## [x] 任务 3: UploadManager 并发控制
- **优先级**: P1
- **状态**: ✅ 已完成
- **修改**: 添加 isUploading 标志位，防止重复上传

## [x] 任务 4: 添加埋点拦截器（Interceptor）
- **优先级**: P2
- **状态**: ✅ 已完成
- **修改**: 创建 AnalyticsInterceptor 协议，自动添加 device_id, app_version 等

## [x] 任务 5: 添加 Debug 模式
- **优先级**: P2
- **状态**: ✅ 已完成
- **修改**: 在 AnalyticsConfig 中添加 isDebugMode 标志

## [x] 任务 6: 增强 Swizzle 安全性
- **优先级**: P2
- **状态**: ✅ 已完成
- **修改**: 添加白名单/黑名单机制，处理系统 VC

## 优化后的架构

```
业务层（VC / View）
        ↓
Analytics.track(...)
        ↓
Interceptor（添加 device_id, user_id, app_version）
        ↓
配置中心（开关/采样/Debug）
        ↓
Session 管理（自动续期）
        ↓
事件队列（内存 + 磁盘持久化）
        ↓
磁盘缓存（NSRecursiveLock）
        ↓
上传管理（并发控制 + 异步上传）
        ↓
服务器
```

## 编译结果

✅ BUILD SUCCEEDED
