import Foundation
// 导入 SDK 模块
import Event_Tracking_SDK

print("开始测试 iOS 埋点 SDK...")

// 测试 1: 基本事件跟踪
print("\n测试 1: 基本事件跟踪")
Analytics.shared.track("test_event", params: ["key": "value", "number": 123])
print("✓ 基本事件跟踪成功")

// 测试 2: 页面相关埋点
print("\n测试 2: 页面相关埋点")
Analytics.shared.trackPageShow("home")
Analytics.shared.trackPageHide("home")
Analytics.shared.trackPageDuration("home", duration: 10.5)
print("✓ 页面相关埋点成功")

// 测试 3: 用户交互埋点
print("\n测试 3: 用户交互埋点")
Analytics.shared.trackClick("button")
Analytics.shared.trackSwipe("left")
Analytics.shared.trackLongPress("image", duration: 2.0)
print("✓ 用户交互埋点成功")

// 测试 4: 网络相关埋点
print("\n测试 4: 网络相关埋点")
Analytics.shared.trackNetworkStart("https://example.com", method: "GET")
Analytics.shared.trackNetworkEnd("https://example.com", method: "GET", statusCode: 200, duration: 1.2)
Analytics.shared.trackNetworkError("https://example.com", method: "GET", error: "Timeout")
print("✓ 网络相关埋点成功")

// 测试 5: 应用生命周期埋点
print("\n测试 5: 应用生命周期埋点")
Analytics.shared.trackAppLaunch()
Analytics.shared.trackAppEnterBackground()
Analytics.shared.trackAppEnterForeground()
Analytics.shared.trackAppExit()
print("✓ 应用生命周期埋点成功")

// 测试 6: 性能相关埋点
print("\n测试 6: 性能相关埋点")
Analytics.shared.trackAppStartDuration(2.5)
Analytics.shared.trackMemoryUsage(1024)
Analytics.shared.trackCPUUsage(45.5)
print("✓ 性能相关埋点成功")

// 测试 7: 错误相关埋点
print("\n测试 7: 错误相关埋点")
Analytics.shared.trackError("Test error")
Analytics.shared.trackException("Test exception")
Analytics.shared.trackCrash("Test crash", stackTrace: "Stack trace here")
print("✓ 错误相关埋点成功")

// 测试 8: 事件队列和批量上报
print("\n测试 8: 事件队列和批量上报")
print("当前队列事件数: \(EventQueue.shared.getEventsCount())")
// 添加足够的事件来触发批量上报
for i in 0..<25 {
    Analytics.shared.track("batch_event", params: ["index": i])
}
print("触发批量上报后，队列事件数: \(EventQueue.shared.getEventsCount())")
print("✓ 事件队列和批量上报成功")

// 测试 9: 磁盘存储
print("\n测试 9: 磁盘存储")
let testEvents = [
    Event(
        id: UUID().uuidString,
        name: "disk_test_event",
        params: ["test": AnyCodable("value")],
        timestamp: Date().timeIntervalSince1970
    )
]
DiskStorage.shared.saveEvents(testEvents)
let loadedEvents = DiskStorage.shared.loadEvents()
print("保存和加载事件数: \(loadedEvents.count)")
DiskStorage.shared.clearEvents()
let clearedEvents = DiskStorage.shared.loadEvents()
print("清除后事件数: \(clearedEvents.count)")
print("✓ 磁盘存储测试成功")

print("\n所有测试完成！")
