import Foundation

public struct AnalyticsDSL {

    public static func track(@AnalyticsBuilder _ builder: () -> EventBuilder) {
        let eventBuilder = builder()
        eventBuilder.send()
    }

    public static func batch(@AnalyticsBuilder _ builder: () -> [EventBuilder]) {
        let builders = builder()
        for builder in builders {
            builder.send()
        }
    }
}

@resultBuilder
public struct AnalyticsBuilder {
    public static func buildBlock(_ components: EventBuilder...) -> [EventBuilder] {
        components
    }

    public static func buildBlock(_ components: [EventBuilder]) -> [EventBuilder] {
        components
    }
}

public class EventBuilder {

    private var eventName: String = ""
    private var page: String = ""
    private var element: String = ""
    private var params: [String: Any] = [:]
    private var userId: String = ""
    private var timestamp: Date = Date()

    public init() {}

    public func event(_ name: String) -> EventBuilder {
        self.eventName = name
        return self
    }

    public func page(_ pageName: String) -> EventBuilder {
        self.page = pageName
        return self
    }

    public func element(_ elementName: String) -> EventBuilder {
        self.element = elementName
        return self
    }

    public func param(_ key: String, value: Any) -> EventBuilder {
        self.params[key] = value
        return self
    }

    public func params(_ dictionary: [String: Any]) -> EventBuilder {
        for (key, value) in dictionary {
            self.params[key] = value
        }
        return self
    }

    public func user(_ id: String) -> EventBuilder {
        self.userId = id
        return self
    }

    public func at(_ date: Date) -> EventBuilder {
        self.timestamp = date
        return self
    }

    public func send() {
        var finalParams = params

        if !page.isEmpty {
            finalParams["page"] = page
        }

        if !element.isEmpty {
            finalParams["element"] = element
        }

        finalParams["timestamp"] = timestamp.timeIntervalSince1970

        if !userId.isEmpty {
            finalParams["user_id"] = userId
        }

        Analytics.shared.track(eventName, params: finalParams)
    }

    public func toEvent() -> Event {
        var finalParams = params.mapValues { AnyCodable($0) }

        if !page.isEmpty {
            finalParams["page"] = AnyCodable(page)
        }

        if !element.isEmpty {
            finalParams["element"] = AnyCodable(element)
        }

        finalParams["timestamp"] = AnyCodable(timestamp.timeIntervalSince1970)

        if !userId.isEmpty {
            finalParams["user_id"] = AnyCodable(userId)
        }

        return Event(
            id: UUID().uuidString,
            name: eventName,
            params: finalParams,
            timestamp: timestamp.timeIntervalSince1970,
            eventId: UUID().uuidString,
            eventType: eventName,
            page: page,
            element: element,
            userId: userId,
            sessionId: SessionManager.shared.getSessionId()
        )
    }
}

public extension EventBuilder {

    static func click(_ element: String, on page: String = "") -> EventBuilder {
        return EventBuilder()
            .event("click")
            .element(element)
            .page(page)
    }

    static func pageView(_ page: String) -> EventBuilder {
        return EventBuilder()
            .event("page_show")
            .page(page)
    }

    static func pageLeave(_ page: String) -> EventBuilder {
        return EventBuilder()
            .event("page_hide")
            .page(page)
    }

    static func expose(_ element: String, on page: String = "") -> EventBuilder {
        return EventBuilder()
            .event("expose")
            .element(element)
            .page(page)
    }

    static func custom(_ eventName: String) -> EventBuilder {
        return EventBuilder()
            .event(eventName)
    }
}

public class EventSequence {

    private var builders: [EventBuilder] = []

    public init() {}

    public func add(_ builder: EventBuilder) -> EventSequence {
        builders.append(builder)
        return self
    }

    public func sendAll() {
        for builder in builders {
            builder.send()
        }
    }

    public func toEvents() -> [Event] {
        return builders.map { $0.toEvent() }
    }
}

public extension EventSequence {

    static func + (lhs: EventSequence, rhs: EventBuilder) -> EventSequence {
        lhs.add(rhs)
        return lhs
    }
}

public class PageContext {

    private let pageName: String
    private var elements: [String: Any] = [:]

    public init(page: String) {
        self.pageName = page
    }

    public func track(_ eventName: String, element: String? = nil, params: [String: Any] = [:]) {
        var finalParams = params
        finalParams["page"] = pageName

        if let element = element {
            finalParams["element"] = element
        }

        for (key, value) in elements {
            finalParams[key] = value
        }

        Analytics.shared.track(eventName, params: finalParams)
    }

    public func click(_ element: String, params: [String: Any] = [:]) {
        track("click", element: element, params: params)
    }

    public func view(_ element: String, params: [String: Any] = [:]) {
        track("view", element: element, params: params)
    }

    public func setContext(_ key: String, value: Any) -> PageContext {
        elements[key] = value
        return self
    }
}

public func page(_ name: String, @AnalyticsBuilder _ builder: (PageContext) -> Void) {
    let context = PageContext(page: name)
    builder(context)
}

public extension Analytics {

    func track(@AnalyticsBuilder _ builder: () -> EventBuilder) {
        let eventBuilder = builder()
        eventBuilder.send()
    }

    func batch(@AnalyticsBuilder _ builder: () -> [EventBuilder]) {
        let builders = builder()
        for builder in builders {
            builder.send()
        }
    }
}
