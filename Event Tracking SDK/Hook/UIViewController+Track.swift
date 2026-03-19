import UIKit

// ============================================================
// MARK: - 方法替换（Swizzle）辅助变量
// ============================================================

/// 关联对象 Key：标记是否已替换过方法
private var swizzledKey: UInt8 = 0

/// 关联对象 Key：白名单标记
private var whitelistKey: UInt8 = 0

/// 关联对象 Key：上次跟踪时间（防止重复触发）
private var lastTrackedTimeKey: UInt8 = 0

// ============================================================
// MARK: - 可跟踪协议
// ============================================================

/// 可跟踪协议
/// 让 UIViewController 实现此协议，控制是否跟踪页面曝光
public protocol AnalyticsTrackable {
    func shouldTrackPageExposure() -> Bool
}

// ============================================================
// MARK: - UIViewController 自动埋点扩展
// ============================================================

/// UIViewController 自动埋点扩展
///
/// - 什么是方法替换（Swizzle）？
///   就像把一个方法的"灵魂"换掉
///   原方法：viewDidAppear → 我们的：track_viewDidAppear
///   调用 viewDidAppear 时，实际执行的是 track_viewDidAppear
///
/// - 自动跟踪的页面事件：
///   1. page_show：页面显示（viewDidAppear）
///   2. page_hide：页面隐藏（viewWillDisappear）
///
/// - 防误跟踪机制：
///   1. Bundle.main 判断：只跟踪主工程 VC
///   2. 黑白名单：可以配置排除/包含某些 VC
///   3. 防重复：0.5 秒内不重复触发
///   4. 容器过滤：不跟踪 UINavigationController 等容器 VC
public extension UIViewController {

    /// 替换 viewDidAppear 方法（类方法，只执行一次）
    /// 在 AppDelegate 中调用：UIViewController.swizzle()
    static func swizzle() {
        // 防止重复替换
        guard !isSwizzled() else {
            return
        }

        // 获取原方法和替换方法
        let original = class_getInstanceMethod(self, #selector(viewDidAppear(_:)))
        let swizzled = class_getInstanceMethod(self, #selector(track_viewDidAppear(_:)))

        // 替换方法实现
        if let original = original, let swizzled = swizzled {
            method_exchangeImplementations(original, swizzled)
            setSwizzled(true)
        }
    }

    /// 替换后的 viewDidAppear
    /// 1. 先调用原方法（self.track_viewDidAppear 实际是原 viewDidAppear）
    /// 2. 然后发送埋点事件
    @objc func track_viewDidAppear(_ animated: Bool) {
        // 先执行原逻辑
        self.track_viewDidAppear(animated)
        
        // 检查是否需要跟踪
        guard shouldTrackPageExposure() else { return }
        
        // 防重复触发（0.5 秒内不重复）
        if shouldPreventDuplicateTrack() {
            return
        }
        
        // 发送页面显示埋点
        Analytics.shared.trackPageShow("\(type(of: self))")
        
        // 同时跟踪子 VC
        trackChildViewControllers()
    }

    /// 替换后的 viewWillDisappear
    @objc func track_viewWillDisappear(_ animated: Bool) {
        self.track_viewWillDisappear(animated)
        
        guard shouldTrackPageExposure() else { return }
        
        Analytics.shared.trackPageHide("\(type(of: self))")
    }

    /// 同时替换两个方法
    static func swizzleAll() {
        guard !isSwizzled() else {
            return
        }

        // 替换 viewDidAppear
        swizzle()

        // 替换 viewWillDisappear
        let original = class_getInstanceMethod(self, #selector(viewWillDisappear(_:)))
        let swizzled = class_getInstanceMethod(self, #selector(track_viewWillDisappear(_:)))

        if let original = original, let swizzled = swizzled {
            method_exchangeImplementations(original, swizzled)
        }
    }

    // MARK: - 私有辅助方法

    /// 检查是否已替换方法
    private static func isSwizzled() -> Bool {
        return objc_getAssociatedObject(self, &swizzledKey) as? Bool ?? false
    }

    /// 设置已替换标记
    private static func setSwizzled(_ value: Bool) {
        objc_setAssociatedObject(self, &swizzledKey, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    /// 防重复触发检查
    /// 0.5 秒内不重复触发同页面的埋点
    private func shouldPreventDuplicateTrack() -> Bool {
        let className = NSStringFromClass(type(of: self))
        
        if let lastTime = objc_getAssociatedObject(self, &lastTrackedTimeKey) as? Date {
            let timeSinceLastTrack = Date().timeIntervalSince(lastTime)
            if timeSinceLastTrack < 0.5 {
                return true
            }
        }
        
        objc_setAssociatedObject(self, &lastTrackedTimeKey, Date(), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return false
    }
    
    /// 跟踪子 ViewController
    /// 处理嵌套在 UINavigationController、UITabBarController 中的 VC
    private func trackChildViewControllers() {
        guard let children = self.children as? [UIViewController] else { return }
        
        for child in children {
            let className = NSStringFromClass(type(of: child))
            
            // 跳过容器 VC
            if isContainerViewController(child) {
                continue
            }
            
            if child.shouldTrackPageExposure() && !isRecentlyTracked(child) {
                Analytics.shared.trackPageShow(className)
            }
        }
    }
    
    /// 判断是否为容器 VC
    private func isContainerViewController(_ vc: UIViewController) -> Bool {
        let containerTypes = [
            "UIPageViewController",
            "UINavigationController",
            "UITabBarController",
            "UISplitViewController"
        ]
        
        let className = NSStringFromClass(type(of: vc))
        return containerTypes.contains(className)
    }
    
    /// 检查 VC 是否最近已跟踪（1 秒内）
    private func isRecentlyTracked(_ vc: UIViewController) -> Bool {
        if let lastTime = objc_getAssociatedObject(vc, &lastTrackedTimeKey) as? Date {
            return Date().timeIntervalSince(lastTime) < 1.0
        }
        return false
    }

    /// 判断是否应该跟踪此页面
    /// 1. 实现 AnalyticsTrackable 协议的优先级最高
    /// 2. 系统 VC 不跟踪
    /// 3. 非主工程 VC 不跟踪
    /// 4. 在黑名单中不跟踪
    func shouldTrackPageExposure() -> Bool {
        // 1. 如果实现了协议，听协议的
        if let trackable = self as? AnalyticsTrackable {
            return trackable.shouldTrackPageExposure()
        }

        // 2. 系统 VC 不跟踪
        if isSystemViewController() {
            return false
        }

        // 3. 检查白名单
        return !isInWhitelist()
    }

    /// 判断是否为系统 VC
    /// 排除 UIAlertController、UINavigationController 等
    private func isSystemViewController() -> Bool {
        let systemClassNames = [
            "UIAlertController",
            "UINavigationController",
            "UITabBarController",
            "UISplitViewController",
            "UIPageViewController",
            "UINavigationBar",
            "UIToolbar"
        ]
        
        let className = NSStringFromClass(type(of: self))
        
        // 直接匹配系统类名
        if systemClassNames.contains(className) {
            return true
        }
        
        // 以 UI 开头的系统类（排除自定义类）
        if className.hasPrefix("UI") && !className.contains(".") {
            return true
        }
        
        // 关键：只跟踪主工程的 VC（Bundle.main）
        // 这避免跟踪 SDK 自己的 VC
        return !isMainAppViewController()
    }
    
    /// 判断是否为主工程的 VC
    /// 只有主工程的 VC 才会被跟踪
    private func isMainAppViewController() -> Bool {
        guard let bundle = Bundle(for: type(of: self)) as Bundle? else {
            return false
        }
        return bundle == Bundle.main
    }

    /// 检查是否在白名单中
    private func isInWhitelist() -> Bool {
        return WhitelistManager.shared.isWhitelisted(NSStringFromClass(type(of: self)))
    }
}

public class WhitelistManager {

    public static let shared = WhitelistManager()

    private var whitelist: Set<String> = []
    private var blacklist: Set<String> = []

    private init() {}

    public func addToWhitelist(_ className: String) {
        whitelist.insert(className)
    }

    public func removeFromWhitelist(_ className: String) {
        whitelist.remove(className)
    }

    public func addToBlacklist(_ className: String) {
        blacklist.insert(className)
    }

    public func removeFromBlacklist(_ className: String) {
        blacklist.remove(className)
    }

    public func isWhitelisted(_ className: String) -> Bool {
        if blacklist.contains(className) {
            return false
        }

        if whitelist.isEmpty {
            return true
        }

        return whitelist.contains(className)
    }

    public func clearWhitelist() {
        whitelist.removeAll()
    }

    public func clearBlacklist() {
        blacklist.removeAll()
    }

    public func clearAll() {
        whitelist.removeAll()
        blacklist.removeAll()
    }
}
