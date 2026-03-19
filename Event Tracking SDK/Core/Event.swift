import Foundation

/// 事件模型，所有埋点事件的基础结构
public struct Event: Codable {
    
    /// 事件唯一标识符
    /// 用于去重和追踪
    public let id: String
    
    /// 事件名称
    /// 如 "click", "page_show", "expose" 等
    public let name: String
    
    /// 事件参数
    /// 存储各种自定义参数，如用户 ID、商品 ID 等
    public let params: [String: AnyCodable]
    
    /// 事件发生时间戳
    /// 从 1970 年开始的秒数
    public let timestamp: TimeInterval
    
    /// 事件 ID（冗余字段，用于兼容）
    /// 通常与 id 相同
    public let eventId: String
    
    /// 事件类型
    /// 通常与 name 相同，用于分类
    public let eventType: String
    
    /// 页面名称
    /// 事件发生的页面，如 "home", "product_detail" 等
    public let page: String
    
    /// 元素名称
    /// 事件发生的元素，如 "buy_button", "banner" 等
    public let element: String
    
    /// 用户 ID
    /// 当前登录用户的唯一标识
    public let userId: String
    
    /// 会话 ID
    /// 用于区分不同的用户会话
    public let sessionId: String

    /// 初始化事件
    /// - Parameters:
    ///   - id: 事件唯一标识符
    ///   - name: 事件名称
    ///   - params: 事件参数
    ///   - timestamp: 事件发生时间戳
    ///   - eventId: 事件 ID（默认与 id 相同）
    ///   - eventType: 事件类型（默认与 name 相同）
    ///   - page: 页面名称
    ///   - element: 元素名称
    ///   - userId: 用户 ID
    ///   - sessionId: 会话 ID
    public init(
        id: String,
        name: String,
        params: [String: AnyCodable],
        timestamp: TimeInterval,
        eventId: String = "",
        eventType: String = "",
        page: String = "",
        element: String = "",
        userId: String = "",
        sessionId: String = ""
    ) {
        self.id = id
        self.name = name
        self.params = params
        self.timestamp = timestamp
        self.eventId = eventId
        self.eventType = eventType
        self.page = page
        self.element = element
        self.userId = userId
        self.sessionId = sessionId
    }
}
