import XCTest
@testable import Event_Tracking_SDK

class AnalyticsSDKTests: XCTestCase {

    func testEventCreation() {
        let event = Event(
            id: UUID().uuidString,
            name: "test_event",
            params: ["key": AnyCodable("value")],
            timestamp: Date().timeIntervalSince1970
        )
        XCTAssertNotNil(event)
        XCTAssertEqual(event.name, "test_event")
    }

    func testAnalyticsTrack() {
        let initialCount = EventQueue.shared.getEventsCount()
        Analytics.shared.track("test_event", params: ["key": "value"])
        let finalCount = EventQueue.shared.getEventsCount()
        XCTAssertEqual(finalCount, initialCount + 1)
    }

    func testPageTracking() {
        let initialCount = EventQueue.shared.getEventsCount()
        Analytics.shared.trackPageShow("home")
        let finalCount = EventQueue.shared.getEventsCount()
        XCTAssertEqual(finalCount, initialCount + 1)
    }

    func testClickTracking() {
        let initialCount = EventQueue.shared.getEventsCount()
        Analytics.shared.trackClick("button")
        let finalCount = EventQueue.shared.getEventsCount()
        XCTAssertEqual(finalCount, initialCount + 1)
    }

    func testNetworkTracking() {
        let initialCount = EventQueue.shared.getEventsCount()
        Analytics.shared.trackNetworkStart("https://example.com", method: "GET")
        let finalCount = EventQueue.shared.getEventsCount()
        XCTAssertEqual(finalCount, initialCount + 1)
    }

    func testAppLifecycleTracking() {
        let initialCount = EventQueue.shared.getEventsCount()
        Analytics.shared.trackAppLaunch()
        let finalCount = EventQueue.shared.getEventsCount()
        XCTAssertEqual(finalCount, initialCount + 1)
    }

    func testPerformanceTracking() {
        let initialCount = EventQueue.shared.getEventsCount()
        Analytics.shared.trackAppStartDuration(1.5)
        let finalCount = EventQueue.shared.getEventsCount()
        XCTAssertEqual(finalCount, initialCount + 1)
    }

    func testErrorTracking() {
        let initialCount = EventQueue.shared.getEventsCount()
        Analytics.shared.trackError("test_error")
        let finalCount = EventQueue.shared.getEventsCount()
        XCTAssertEqual(finalCount, initialCount + 1)
    }

    func testEventQueueFlush() {
        // 添加多个事件
        for _ in 0..<25 {
            Analytics.shared.track("test_event")
        }
        // 验证队列被清空
        XCTAssertEqual(EventQueue.shared.getEventsCount(), 0)
    }

    func testDiskStorage() {
        let testEvents = [
            Event(
                id: UUID().uuidString,
                name: "test_event_1",
                params: ["key": AnyCodable("value1")],
                timestamp: Date().timeIntervalSince1970
            ),
            Event(
                id: UUID().uuidString,
                name: "test_event_2",
                params: ["key": AnyCodable("value2")],
                timestamp: Date().timeIntervalSince1970
            )
        ]
        
        // 保存事件
        DiskStorage.shared.saveEvents(testEvents)
        
        // 加载事件
        let loadedEvents = DiskStorage.shared.loadEvents()
        XCTAssertEqual(loadedEvents.count, 2)
        
        // 清除事件
        DiskStorage.shared.clearEvents()
        let clearedEvents = DiskStorage.shared.loadEvents()
        XCTAssertEqual(clearedEvents.count, 0)
    }
}
