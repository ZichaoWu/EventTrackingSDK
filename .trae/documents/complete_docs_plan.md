# 代码注释完善与文档更新计划

## 目标
1. 为关键且难以理解的代码添加详细注释
2. 更新 Event_Tracking_SDK.md 文档，包含所有用法示例，demo 一看就懂

## 任务清单

### Task 1: 为核心代码添加注释

#### 1.1 AnalyticsInterceptor.swift - 拦截器链
- 解释什么是 AOP 切面编程
- 解释 intercept 返回 Bool 的作用（可终止事件）
- 解释 DefaultInterceptor 自动添加的设备信息

#### 1.2 DiskStorage.swift - 磁盘存储
- 解释 JSONL 格式（每行一个 JSON）
- 解释 FileHandle 追加写原理
- 解释为什么用 seekToEnd()

#### 1.3 EventQueue.swift - 事件队列
- 解释串行队列如何避免竞态
- 解释 flush 机制

#### 1.4 ExposureManager.swift - 曝光管理
- 解释 throttle 节流原理
- 解释为什么强制要求 ExposureTrackable 协议
- 解释 pendingScrollViews 字典的作用

#### 1.5 UIViewController+Track.swift - 自动页面埋点
- 解释 Swizzle 方法替换原理
- 解释为什么用 Bundle.main 判断主工程 VC
- 解释防止重复触发机制

#### 1.6 UploadManager.swift - 上传管理
- 解释指数退避重试算法
- 解释 gzip 压缩原理

#### 1.7 Analytics.swift - 主入口
- 解释采样逻辑
- 解释 InterceptorChain 如何接入

### Task 2: 更新 Event_Tracking_SDK.md 文档

#### 2.1 完善目录结构
- 基本使用
- 核心概念（重点解释）
- 高级特性
- 常见问题
- 更新日志

#### 2.2 核心概念章节（新增）
- 什么是拦截器（Interceptor）
- 什么是曝光管理
- 什么是 Session
- 什么是采样

#### 2.3 Demo 示例（一看就懂）
- 最简单用法（1行代码）
- 完整集成示例
- 自定义拦截器示例
- 曝光跟踪示例
- DSL 用法示例
- 动态埋点平台化示例

#### 2.4 常见问题
- 为什么 Cell 必须实现 ExposureTrackable
- 为什么要用 Bundle.main 判断
- 采样不生效怎么办

## 实施顺序

1. 先为所有核心文件添加注释
2. 然后更新文档

## 验收标准
- [ ] 所有核心文件都有清晰的中文注释
- [ ] 文档 demo 一看就懂
- [ ] 新手能通过文档快速集成 SDK
