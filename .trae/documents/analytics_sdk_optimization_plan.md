# iOS 埋点 SDK 优化计划

根据 chatGPT.md 中的评价，本计划将解决所有关键问题并添加大厂级功能。

## [x] 任务 1: 修复 DiskStorage 死锁风险
- **优先级**: P0
- **依赖**: 无
- **描述**:
  - 将 NSLock 改为 NSRecursiveLock
  - 拆分内部方法避免嵌套 lock
  - 添加失败事件存储功能
- **成功标准**:
  - 嵌套调用方法时不会发生死锁
- **测试要求**:
  - `programmatic` TR-1.1: 验证连续调用 appendEvent 不会死锁
- **状态**: ✅ 已完成

## [x] 任务 2: 修复 EventQueue 丢数据风险
- **优先级**: P0
- **依赖**: 任务 1
- **描述**:
  - 添加定时 flush（10 秒间隔）
  - 添加内存满 flush（当前已有 20 个触发）
  - 确保应用进入后台时 flush
- **成功标准**:
  - 定时任务正确触发 flush
  - 多种触发机制协同工作
- **测试要求**:
  - `programmatic` TR-2.1: 验证定时 flush 触发
  - `programmatic` TR-2.2: 验证进入后台时 flush
- **状态**: ✅ 已完成

## [x] 任务 3: 添加上传失败重试机制
- **优先级**: P0
- **依赖**: 任务 2
- **描述**:
  - 上传失败时将事件写入 DiskStorage
  - 下次启动时重传失败的事件
  - 实现指数退避重试策略（1s → 2s → 4s）
- **成功标准**:
  - 网络失败时事件不丢失
  - 重试机制正常工作
- **测试要求**:
  - `programmatic` TR-3.1: 模拟网络失败，验证事件写入磁盘
  - `programmatic` TR-3.2: 验证重试逻辑
- **状态**: ✅ 已完成

## [x] 任务 4: 升级 UploadManager
- **优先级**: P1
- **依赖**: 任务 3
- **描述**:
  - 实现真实的网络请求（URLSession）
  - 添加 gzip 压缩
  - 添加上报策略（批量大小限制）
- **成功标准**:
  - 支持真实网络上传
  - 数据经过压缩
- **测试要求**:
  - `programmatic` TR-4.1: 验证网络请求发送
  - `programmatic` TR-4.2: 验证压缩功能
- **状态**: ✅ 已完成

## [x] 任务 5: 优化 ExposureManager 性能
- **优先级**: P1
- **依赖**: 无
- **描述**:
  - 添加节流（throttle 100ms）机制
  - 合并重复的 handleScroll 方法
- **成功标准**:
  - 高频 scroll 调用不会影响性能
  - API 更加简洁
- **测试要求**:
  - `programmatic` TR-5.1: 验证节流机制生效
- **状态**: ✅ 已完成

## [x] 任务 6: 修复曝光 key 设计问题
- **优先级**: P1
- **依赖**: 任务 5
- **描述**:
  - 修改 key 生成策略，支持业务唯一 ID
  - 支持 UITableViewDiffableDataSource
- **成功标准**:
  - 数据刷新后不重复曝光
- **测试要求**:
  - `programmatic` TR-6.1: 验证列表刷新后不重复曝光
- **状态**: ✅ 已完成

## [x] 任务 7: 增强埋点模型设计
- **优先级**: P2
- **依赖**: 无
- **描述**:
  - 扩展 Event 模型，添加更多字段：
    - eventId: 事件 ID
    - eventType: 事件类型
    - page: 页面名称
    - element: 元素名称
    - userId: 用户 ID
    - sessionId: 会话 ID
- **成功标准**:
  - 事件包含完整的上下文信息
- **测试要求**:
  - `programmatic` TR-7.1: 验证事件模型字段完整
- **状态**: ✅ 已完成

## [x] 任务 8: 添加 Session 机制
- **优先级**: P2
- **依赖**: 任务 7
- **描述**:
  - 创建 Session 管理类
  - 生成和维护 session_id
  - 记录启动时间和停留时长
- **成功标准**:
  - 每个会话有唯一的 session_id
- **测试要求**:
  - `programmatic` TR-8.1: 验证 session_id 唯一性
- **状态**: ✅ 已完成

## [x] 任务 9: 添加埋点开关和采样
- **优先级**: P2
- **依赖**: 任务 8
- **描述**:
  - 添加全局埋点开关（enable/disable）
  - 添加采样控制（只上报 10% 等）
  - 支持运行时动态配置
- **成功标准**:
  - 可以通过配置控制埋点是否生效
- **测试要求**:
  - `programmatic` TR-9.1: 验证开关关闭后不记录事件
  - `programmatic` TR-9.2: 验证采样机制
- **状态**: ✅ 已完成

## [x] 任务 10: 添加埋点配置中心
- **优先级**: P3
- **依赖**: 任务 9
- **描述**:
  - 从服务端拉取埋点配置
  - 支持事件级别的开关控制
  - 实现配置缓存和更新机制
- **成功标准**:
  - 服务端可以控制埋点行为
- **测试要求**:
  - `programmatic` TR-10.1: 验证服务端配置生效
- **状态**: ✅ 已完成（集成在 AnalyticsConfig 中）

## [x] 任务 11: 优化 Swizzle 实现
- **优先级**: P3
- **依赖**: 无
- **描述**:
  - 添加多个 SDK 共存时的冲突检测
  - 使用 AssociatedObject 记录 swizzle 状态
- **成功标准**:
  - 降低与其他 SDK 冲突的风险
- **测试要求**:
  - `human-judgement` TR-11.1: 验证代码结构更加健壮
- **状态**: ✅ 已完成

## 优化后的架构

```
业务层（VC / View）
        ↓
Analytics.track(...)
        ↓
SDK 内部
   ├── 配置中心（开关/采样）
   ├── Session 管理
   ├── 自动页面曝光（Hook + 冲突检测）
   ├── 列表曝光管理（ExposureManager + 节流）
   ├── 事件队列（数量+时间双触发）
   ├── 本地缓存（DiskStorage + NSRecursiveLock）
   ├── 批量上报（gzip 压缩）
   └── 上传管理（指数退避重试机制）
```

## 已完成的优化

1. **DiskStorage** - 使用 NSRecursiveLock 避免死锁，添加失败事件存储
2. **EventQueue** - 添加定时 flush（10秒）和数量触发（20个）
3. **UploadManager** - 真实网络请求、gzip 压缩、指数退避重试
4. **ExposureManager** - 节流机制（100ms）、合并 API
5. **Event 模型** - 增强字段：eventId, eventType, page, element, userId, sessionId
6. **SessionManager** - 会话管理、启动时间、活跃状态
7. **AnalyticsConfig** - 埋点开关、采样率、事件级别配置、服务端配置更新
8. **UIViewController+Track** - 冲突检测、AssociatedObject 状态记录

## 编译结果

✅ BUILD SUCCEEDED
