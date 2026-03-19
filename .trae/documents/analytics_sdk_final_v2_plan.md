# iOS 埋点 SDK 最终优化计划

解决关键问题并实现高级功能。

## [ ] 任务 1: Interceptor 接入主流程（关键修复）
- **优先级**: P0
- **依赖**: 无
- **描述**:
  - 在 Analytics.track() 中调用 InterceptorChain.shared.processEvent(event)
  - 确保所有事件都经过拦截器处理
- **成功标准**:
  - 所有埋点事件都包含 device_id、app_version 等信息
- **测试要求**:
  - `programmatic` TR-1.1: 验证拦截器添加的字段存在

## [ ] 任务 2: 采样真正生效（关键修复）
- **优先级**: P0
- **依赖**: 任务 1
- **描述**:
  - 在 Analytics.track() 开头添加采样检查
  - guard config.shouldSampleEvent(name) else { return }
- **成功标准**:
  - 采样率为 0 时不产生任何事件
- **测试要求**:
  - `programmatic` TR-2.1: 验证采样关闭时不记录事件

## [ ] 任务 3: EventQueue 竞态风险修复
- **优先级**: P0
- **依赖**: 任务 2
- **描述**:
  - 将 NSLock 改为 DispatchQueue 串行队列
  - 所有操作在串行队列中执行
- **成功标准**:
  - 并发场景下不丢数据、顺序正确
- **测试要求**:
  - `programmatic` TR-3.1: 多线程并发测试

## [ ] 任务 4: DiskStorage 性能优化
- **优先级**: P1
- **依赖**: 任务 3
- **描述**:
  - 改为批量写入，减少频繁 IO
  - 添加内存缓冲，定期刷新到磁盘
- **成功标准**:
  - 减少主线程 IO 阻塞
- **测试要求**:
  - `programmatic` TR-4.1: 验证批量写入功能

## [ ] 任务 5: ExposureManager Bug 修复
- **优先级**: P1
- **依赖**: 无
- **描述**:
  - 修复 pendingScrollView 只保存一个的问题
  - 简化逻辑，丢弃 pending 状态
- **成功标准**:
  - 多个列表滚动不丢事件
- **测试要求**:
  - `programmatic` TR-5.1: 验证多列表场景

## [ ] 任务 6: Swizzle 增强
- **优先级**: P1
- **依赖**: 无
- **描述**:
  - 处理 childViewController
  - 处理 container VC 重复触发问题
- **成功标准**:
  - 嵌套页面不重复埋点
- **测试要求**:
  - `human-judgement` TR-6.1: 验证嵌套 VC 行为

## [ ] 任务 7: 动态埋点平台化（高级功能）
- **优先级**: P2
- **依赖**: 任务 1-6
- **描述**:
  - 服务端下发事件配置
  - 自动绑定点击事件
  - 支持运行时动态修改埋点规则
- **成功标准**:
  - 支持服务端控制埋点行为
- **测试要求**:
  - `programmatic` TR-7.1: 验证服务端配置生效

## [ ] 任务 8: 可视化埋点（高级功能）
- **优先级**: P2
- **依赖**: 任务 7
- **描述**:
  - UI 选中控件自动生成埋点
  - 使用 Runtime 和 hitTest
  - View 树遍历
- **成功标准**:
  - 可视化选择并生成埋点代码
- **测试要求**:
  - `human-judgement` TR-8.1: 验证可视化功能

## [ ] 任务 9: 埋点 DSL（架构高级功能）
- **优先级**: P3
- **依赖**: 任务 8
- **描述**:
  - 实现链式调用 DSL
  - 支持 track { ... } 语法
- **成功标准**:
  - API 更加优雅易用
- **测试要求**:
  - `programmatic` TR-9.1: 验证 DSL 语法

## 优化后的架构

```
业务层 → Analytics.track() 
              ↓
        采样检查 (shouldSampleEvent)
              ↓
        InterceptorChain 处理
              ↓
        EventQueue (DispatchQueue 串行)
              ↓
        DiskStorage (批量写入)
              ↓
        UploadManager (并发控制)
              ↓
        服务器
```

## 预期效果

- 所有关键 bug 修复
- 性能大幅提升
- 支持动态埋点平台化
- 支持可视化埋点
- API 更优雅
