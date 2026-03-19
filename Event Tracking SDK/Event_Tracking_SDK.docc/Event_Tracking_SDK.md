# Event_Tracking_SDK 完整使用文档

> 这是一份一看就懂的埋点 SDK 文档，新手也能快速上手

---

## 目录

1. [快速开始](#一快速开始)
2. [核心概念](#二核心概念)
3. [完整 Demo](#三完整-demo)
4. [所有 API 参考](#四所有-api-参考)
5. [常见问题](#五常见问题)

---

## 一、快速开始

### 1.1 最简单的用法（1 行代码）

```swift
import Event_Tracking_SDK

// 在 AppDelegate 中初始化
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // 启用自动页面埋点（这一步很重要！）
    UIViewController.swizzle()
    
    return true
}

//  anywhere in your code
Analytics.shared.trackClick("buy_button")
```

### 1.2 自动追踪的内容

| 类型 | 说明 | 自动？ |
|------|------|--------|
| 页面显示 | 进入页面时自动触发 `page_show` | ✅ 自动 |
| 页面隐藏 | 离开页面时自动触发 `page_hide` | ✅ 自动 |
| 列表曝光 | Cell 露出 50% 以上时触发 | ⚠️ 需配置 |
| 点击事件 | 需要手动调用 | ❌ 手动 |

---

## 二、核心概念

> 这一节解释 SDK 的核心概念，帮助你理解它的工作原理

### 2.1 什么是拦截器（Interceptor）？

**比喻：拦截器就像邮局的"安检通道"**

```
你寄信 → 安检员检查（拦截器）→ 贴邮票（添加信息）→ 决定是否寄出
```

**在 SDK 中**：
- 每个事件发送前都会经过拦截器
- 拦截器可以修改事件内容（添加设备信息）
- 拦截器可以阻止事件发送（返回 false）

**默认拦截器会自动添加**：
```swift
device_id    // 设备唯一标识
app_version  // App 版本
os_version   // iOS 版本
device_model // 设备型号
locale       // 地区
```

**自定义拦截器示例**：
```swift
// 创建一个自定义拦截器：添加用户 ID
class UserIdInterceptor: AnalyticsInterceptor {
    func intercept(event: inout Event) -> Bool {
        event.params["user_id"] = AnyCodable(getCurrentUserId())
        return true // 返回 true 表示事件继续传递
    }
}

// 添加到链中
InterceptorChain.shared.addInterceptor(UserIdInterceptor())
```

### 2.2 什么是曝光管理（ExposureManager）？

**比喻：曝光就像"货架上的商品被顾客看到"**

```
顾客滚动列表 → 看到商品 → 记录"已曝光"
              ↓
        下次滚动不再重复记录
```

**曝光触发条件**：
- Cell 可见面积 > 50%
- 同一个曝光 ID 只触发一次
- 滚动时 0.1 秒内只处理一次（节流）

**如何使用**：
```swift
// 在 UITableView 或 UICollectionView 的代理方法中调用
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    ExposureManager.shared.handleScroll(scrollView)
}
```

### 2.3 什么是 Session？

**比喻：Session 就像"用户的访问会话"**

```
用户打开 App → 开始一个 Session
    ↓
30 分钟无操作 → Session 结束
    ↓
再次操作 → 开始新 Session
```

**Session 的作用**：
- 区分不同用户的访问
- 跟踪用户停留时长
- 事件会自动带上 sessionId

### 2.4 什么是采样（Sampling）？

**比喻：采样就像"抽查"**

```
100% 采样 = 记录所有事件
50% 采样 = 随机丢弃一半事件
0% 采样 = 不记录任何事件
```

**使用场景**：
- 测试环境降低采样率，减少数据量
- 特定事件单独配置采样率

```swift
// 全局采样 50%
AnalyticsConfig.shared.setSamplingRate(0.5)

// 某个事件不采样
AnalyticsConfig.shared.setEventConfig("important_event", 
    config: AnalyticsConfig.EventConfig(enabled: true, samplingRate: 1.0))
```

---

## 三、完整 Demo

### 3.1 基础集成（AppDelegate）

```swift
import Event_Tracking_SDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 1. 启用自动页面埋点（最重要的一步！）
        UIViewController.swizzle()
        
        // 2. 配置服务器地址（可选，不配置则只打印日志）
        UploadManager.shared.setServerURL(URL(string: "https://your-server.com/track")!)
        
        // 3. 设置调试模式（可选，方便调试时查看日志）
        AnalyticsConfig.shared.setDebugMode(true)
        
        // 4. 跟踪 App 启动
        Analytics.shared.trackAppLaunch()
        
        return true
    }
    
    // 应用进入后台时强制上传
    func applicationDidEnterBackground(_ application: UIApplication) {
        Analytics.shared.flush()
    }
    
    // 应用即将退出
    func applicationWillTerminate(_ application: UIApplication) {
        Analytics.shared.trackAppExit()
        Analytics.shared.flush()
    }
}
```

### 3.2 列表曝光跟踪

```swift
class HomeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    // 定义数据模型，实现 ExposureTrackable 协议
    struct Product: ExposureTrackable {
        let id: String
        let name: String
        let price: Double
        
        // 关键：每个商品必须有唯一的 exposureId
        var exposureId: String {
            return "product_\(id)"
        }
    }
    
    var products: [Product] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 加载数据...
    }
    
    // MARK: - UITableView 滚动时触发曝光
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 调用曝光管理器
        ExposureManager.shared.handleScroll(scrollView, listId: "home_products")
    }
    
    // 列表刷新时重置曝光
    func refreshData() {
        // 重新加载数据
        products = loadProducts()
        
        // 重置曝光记录（可选）
        ExposureManager.shared.resetExposedSet(for: "home_products")
        
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProductCell", for: indexPath)
        let product = products[indexPath.row]
        cell.textLabel?.text = product.name
        return cell
    }
}
```

### 3.3 手动埋点

```swift
class ProductDetailViewController: UIViewController {

    @IBAction func buyButtonTapped(_ sender: UIButton) {
        // 埋点：用户点击购买按钮
        Analytics.shared.trackClick("buy_button", params: [
            "product_id": "12345",
            "product_name": "iPhone 15",
            "price": 5999.0
        ])
    }
    
    @IBAction func addToCartTapped(_ sender: UIButton) {
        Analytics.shared.track("add_to_cart", params: [
            "product_id": "12345",
            "quantity": 1
        ])
    }
}
```

### 3.4 动态埋点平台化

```swift
class AppDelegate: UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // ... 其他初始化 ...
        
        // 启用动态埋点
        DynamicTracker.shared.enable()
        
        // 模拟从服务端获取配置
        fetchTrackConfig()
        
        return true
    }
    
    func fetchTrackConfig() {
        // 实际项目中，这里应该从服务端获取
        // 这里用本地模拟
        let config: [String: DynamicTracker.TrackConfig] = [
            "home_banner_click": DynamicTracker.TrackConfig(
                eventName: "banner_click",
                action: "click",
                page: "HomeViewController",
                element: "banner"
            ),
            "product_buy_click": DynamicTracker.TrackConfig(
                eventName: "product_buy",
                action: "click",
                page: "ProductDetailViewController",
                element: "buyButton"
            )
        ]
        
        DynamicTracker.shared.updateConfigs(config)
    }
}
```

### 3.5 可视化埋点

```swift
class DebugViewController: UIViewController {

    // 开启可视化选点模式
    @IBAction func startVisualTracking(_ sender: UIButton) {
        VisualTracker.shared.start()
    }
    
    // 停止
    @IBAction func stopVisualTracking(_ sender: UIButton) {
        VisualTracker.shared.stop()
    }
}
```

### 3.6 DSL 用法（更优雅的埋点方式）

```swift
// 方式一：链式调用
AnalyticsDSL.track {
    EventBuilder.click("buy_button")
        .page("home")
        .param("product_id", value: "12345")
}

// 方式二：批量埋点
AnalyticsDSL.batch {
    EventBuilder.pageView("home")
    EventBuilder.click("banner_1")
    EventBuilder.click("banner_2")
}

// 方式三：PageContext（适合同一个页面的多个事件）
page("home") { ctx in
    ctx.click("banner")
    ctx.click("buy_button")
    ctx.click("cart_icon")
}
```

### 2.7 自定义拦截器（添加用户信息）

```swift
// 第一步：创建拦截器
class UserInterceptor: AnalyticsInterceptor {
    
    private var userId: String?
    private var userName: String?
    
    func setUser(id: String, name: String) {
        self.userId = id
        self.userName = name
    }
    
    func logout() {
        self.userId = nil
        self.userName = nil
    }
    
    func intercept(event: inout Event) -> Bool {
        // 添加用户信息
        if let userId = userId {
            event.params["user_id"] = AnyCodable(userId)
        }
        if let userName = userName {
            event.params["user_name"] = AnyCodable(userName)
        }
        return true
    }
}

// 第二步：添加拦截器
let userInterceptor = UserInterceptor()
InterceptorChain.shared.addInterceptor(userInterceptor)

// 登录时设置用户
userInterceptor.setUser(id: "123456", name: "张三")

// 退出时清除
userInterceptor.logout()
```

---

## 四、所有 API 参考

### 4.1 Analytics - 主入口

```swift
// 基础
Analytics.shared.track("event_name", params: ["key": "value"])
Analytics.shared.flush()  // 立即上传

// 页面
Analytics.shared.trackPageShow("home")
Analytics.shared.trackPageHide("home")
Analytics.shared.trackPageDuration("home", duration: 10.5)

// 点击/交互
Analytics.shared.trackClick("button")
Analytics.shared.trackSwipe("left")
Analytics.shared.trackLongPress("image", duration: 2.0)

// 网络
Analytics.shared.trackNetworkStart("https://api.example.com", method: "GET")
Analytics.shared.trackNetworkEnd("https://api.example.com", method: "GET", statusCode: 200, duration: 1.5)
Analytics.shared.trackNetworkError("https://api.example.com", method: "GET", error: "timeout")

// 应用生命周期
Analytics.shared.trackAppLaunch()
Analytics.shared.trackAppExit()
Analytics.shared.trackAppEnterBackground()
Analytics.shared.trackAppEnterForeground()

// 性能/错误
Analytics.shared.trackAppStartDuration(2.5)
Analytics.shared.trackMemoryUsage(1024)
Analytics.shared.trackCPUUsage(45.5)
Analytics.shared.trackError("错误信息")
Analytics.shared.trackException("异常信息")
Analytics.shared.trackCrash("崩溃信息", stackTrace: "堆栈...")
```

### 4.2 AnalyticsConfig - 配置

```swift
// 全局开关
AnalyticsConfig.shared.setEnabled(true)  // 启用/禁用
AnalyticsConfig.shared.isTrackingEnabled()

// 调试模式
AnalyticsConfig.shared.setDebugMode(true)
AnalyticsConfig.shared.isDebug()

// 采样
AnalyticsConfig.shared.setSamplingRate(0.5)  // 50% 采样
AnalyticsConfig.shared.shouldSample()

// 事件级配置
AnalyticsConfig.shared.setEventConfig("click", config: 
    AnalyticsConfig.EventConfig(enabled: true, samplingRate: 1.0))

// 服务端配置下发
AnalyticsConfig.shared.updateConfigFromServer(data)
```

### 4.3 EventQueue - 事件队列

```swift
// 获取队列中事件数量
EventQueue.shared.getEventsCount()

// 手动触发上传
EventQueue.shared.flush()

// 暂停/恢复定时上传
EventQueue.shared.pauseTimer()
EventQueue.shared.resumeTimer()
```

### 4.4 ExposureManager - 曝光管理

```swift
// 处理列表滚动
ExposureManager.shared.handleScroll(scrollView)
ExposureManager.shared.handleScroll(scrollView, listId: "home_list")

// 手动曝光
ExposureManager.shared.trackExposure(for: myModel, listId: "home_list")

// 重置曝光记录
ExposureManager.shared.resetExposedSet()  // 重置所有
ExposureManager.shared.resetExposedSet(for: "home_list")  // 重置指定列表
```

### 4.5 WhitelistManager - 黑白名单

```swift
// 白名单（只有白名单中的 VC 会被跟踪）
WhitelistManager.shared.addToWhitelist("HomeViewController")
WhitelistManager.shared.removeFromWhitelist("HomeViewController")

// 黑名单（黑名单中的 VC 不会被跟踪）
WhitelistManager.shared.addToBlacklist("DebugViewController")
WhitelistManager.shared.removeFromBlacklist("DebugViewController")

// 检查
WhitelistManager.shared.isWhitelisted("HomeViewController")

// 清空
WhitelistManager.shared.clearAll()
```

### 4.6 InterceptorChain - 拦截器

```swift
// 添加拦截器
InterceptorChain.shared.addInterceptor(myInterceptor)

// 移除拦截器
InterceptorChain.shared.removeInterceptor(myInterceptor)

// 清空所有拦截器（注意：这会清空默认的设备信息拦截器）
InterceptorChain.shared.clearInterceptors()
```

---

## 五、常见问题

### Q1: 为什么 Cell 必须实现 ExposureTrackable 协议？

**问题描述**：
编译时报错：`fatalError("Cell 必须实现 ExposureTrackable 协议")`

**原因**：
SDK 强制要求每个可曝光的 Cell 实现 `ExposureTrackable` 协议，提供唯一的 `exposureId`。

**错误示范**：
```swift
// ❌ 错误：没有实现协议
class ProductCell: UITableViewCell {
    var product: Product?
}
```

**正确示范**：
```swift
// ✅ 正确：实现协议
class ProductCell: UITableViewCell, ExposureTrackable {
    var product: Product?
    
    var exposureId: String {
        return "product_\(product?.id ?? "")"
    }
}
```

**为什么要这么设计？**
- 传统方式用 `section_row` 作为曝光 key
- 问题：列表数据变化时，位置不变但内容变了，会重复曝光
- 解决：用唯一 ID（如商品 ID）作为 key，内容变化时 ID 变化，正确触发曝光

---

### Q2: 采样不生效怎么办？

**检查步骤**：

1. 确认采样率设置正确
```swift
// 设置全局采样率
AnalyticsConfig.shared.setSamplingRate(1.0)  // 100% 采样

// 检查是否生效
print(AnalyticsConfig.shared.shouldSampleEvent("click"))
```

2. 检查事件是否被采样过滤
```swift
// 在 track() 方法中加日志
// SDK 会在 shouldSampleEvent() 返回 false 时丢弃事件
```

3. 检查事件级配置
```swift
// 某个事件可能配置了 0% 采样
AnalyticsConfig.shared.setEventConfig("click", 
    config: AnalyticsConfig.EventConfig(enabled: true, samplingRate: 1.0))
```

---

### Q3: 为什么要用 Bundle.main 判断？

**问题描述**：
SDK 使用 `Bundle.main` 来判断是否为主工程的 ViewController。

**原因**：
- 防止跟踪 SDK 内部的 ViewController
- 只跟踪主 App 的页面

**如果不生效**：
```swift
// 手动控制某个 VC 是否跟踪
class MyViewController: UIViewController, AnalyticsTrackable {
    func shouldTrackPageExposure() -> Bool {
        return false  // 不跟踪这个页面
    }
}
```

---

### Q4: 如何调试？

```swift
// 1. 开启调试模式
AnalyticsConfig.shared.setDebugMode(true)

// 2. 现在所有事件都会打印到控制台
// [Analytics] event: click, params: [...]

// 3. 查看队列中的事件数量
print("队列事件数：\(EventQueue.shared.getEventsCount())")

// 4. 手动触发上传
Analytics.shared.flush()
```

---

### Q5: 数据存储在哪里？

| 数据 | 位置 | 说明 |
|------|------|------|
| 待上传事件 | Documents/analytics_events.jsonl | JSONL 格式 |
| 失败事件 | Documents/analytics_failed_events.jsonl | 上传失败的会在这里 |
| 配置 | UserDefaults | samplingRate、enabled 等 |
| Session | UserDefaults | sessionId、startTime |

---

### Q6: 如何接入公司现有项目？

1. **集成 SDK**
   - CocoaPods: `pod 'Event_Tracking_SDK'`
   - SPM: 从 GitHub 导入

2. **初始化配置**
   ```swift
   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
       UIViewController.swizzle()
       UploadManager.shared.setServerURL(URL(string: "https://your-analytics.com")!)
       return true
   }
   ```

3. **添加曝光跟踪**
   ```swift
   func scrollViewDidScroll(_ scrollView: UIScrollView) {
       ExposureManager.shared.handleScroll(scrollView)
   }
   ```

4. **自定义埋点**
   ```swift
   Analytics.shared.trackClick("buy", params: ["product_id": "123"])
   ```

---

## 更新日志

### v1.0.0 (2026-3-18)
- 初始版本
- 支持自动页面埋点
- 支持列表曝光跟踪
- 支持拦截器
- 支持 DSL
- 支持动态埋点
- 支持可视化埋点
