import Foundation
import UIKit

public class DynamicTracker {

    public static let shared = DynamicTracker()

    private var trackConfigs: [String: TrackConfig] = [:]
    private let queue = DispatchQueue(label: "com.analytics.dynamic", qos: .utility)
    private var isEnabled: Bool = false

    public struct TrackConfig: Codable {
        public let eventName: String
        public let action: String
        public let page: String?
        public let element: String?
        public let params: [String: String]?

        public init(eventName: String, action: String, page: String? = nil, element: String? = nil, params: [String: String]? = nil) {
            self.eventName = eventName
            self.action = action
            self.page = page
            self.element = element
            self.params = params
        }
    }

    private init() {}

    public func enable() {
        isEnabled = true
        applyAllConfigs()
    }

    public func disable() {
        isEnabled = false
    }

    public func updateConfigs(_ configs: [String: TrackConfig]) {
        queue.async { [weak self] in
            self?.trackConfigs = configs
            self?.saveConfigs()
            
            DispatchQueue.main.async {
                self?.applyAllConfigs()
            }
        }
    }

    public func updateConfigsFromServer(_ data: Data) {
        queue.async { [weak self] in
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            var configs: [String: TrackConfig] = [:]

            if let trackConfigs = json["trackConfigs"] as? [String: [String: Any]] {
                for (key, value) in trackConfigs {
                    let eventName = value["eventName"] as? String ?? key
                    let action = value["action"] as? String ?? "click"
                    let page = value["page"] as? String
                    let element = value["element"] as? String
                    let params = value["params"] as? [String: String]

                    configs[key] = TrackConfig(
                        eventName: eventName,
                        action: action,
                        page: page,
                        element: element,
                        params: params
                    )
                }
            }

            self?.trackConfigs = configs
            self?.saveConfigs()

            DispatchQueue.main.async {
                self?.applyAllConfigs()
            }
        }
    }

    private func applyAllConfigs() {
        guard isEnabled else { return }

        for (key, config) in trackConfigs {
            applyConfig(key, config: config)
        }
    }

    private func applyConfig(_ key: String, config: TrackConfig) {
        switch config.action {
        case "click":
            applyClickConfig(key, config: config)
        case "expose":
            applyExposeConfig(key, config: config)
        case "custom":
            break
        default:
            break
        }
    }

    private func applyClickConfig(_ key: String, config: TrackConfig) {
        guard let page = config.page, !page.isEmpty else { return }

        let targetClasses = findViewControllerClasses(matching: page)

        for className in targetClasses {
            if let cls = NSClassFromString(className) as? UIViewController.Type {
                cls.swizzleAll()
            }
        }

        UIView.swizzleTouchHandler()
    }

    private func applyExposeConfig(_ key: String, config: TrackConfig) {
    }

    private func findViewControllerClasses(matching pattern: String) -> [String] {
        return [pattern]
    }

    public func getConfigs() -> [String: TrackConfig] {
        var result: [String: TrackConfig] = [:]
        queue.sync {
            result = trackConfigs
        }
        return result
    }

    private func saveConfigs() {
        guard let data = try? JSONEncoder().encode(trackConfigs) else { return }
        UserDefaults.standard.set(data, forKey: "analytics_dynamic_configs")
    }

    private func loadConfigs() {
        guard let data = UserDefaults.standard.data(forKey: "analytics_dynamic_configs"),
              let configs = try? JSONDecoder().decode([String: TrackConfig].self, from: data) else { return }
        trackConfigs = configs
    }

    public func clearConfigs() {
        queue.async { [weak self] in
            self?.trackConfigs.removeAll()
            self?.saveConfigs()
        }
    }
}

public extension UIView {

    static var hasSwizzledTouch: Bool = false

    static func swizzleTouchHandler() {
        guard !hasSwizzledTouch else { return }

        let original = class_getInstanceMethod(self, #selector(touchesBegan(_:with:)))
        let swizzled = class_getInstanceMethod(self, #selector(track_touchesBegan(_:with:)))

        if let original = original, let swizzled = swizzled {
            method_exchangeImplementations(original, swizzled)
            UIView.hasSwizzledTouch = true
        }
    }

    @objc func track_touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.track_touchesBegan(touches, with: event)

        guard DynamicTracker.shared.getConfigs().isEmpty == false else { return }

        DispatchQueue.main.async {
            self.handleDynamicTrack()
        }
    }

    private func handleDynamicTrack() {
        guard let viewController = findViewController() else { return }

        let vcClassName = NSStringFromClass(type(of: viewController))
        let viewPath = generateViewPath()

        let configs = DynamicTracker.shared.getConfigs()

        for (key, config) in configs {
            if let page = config.page, page == vcClassName {
                if let element = config.element, element == viewPath || viewPath.contains(element) {
                    var params: [String: Any] = [
                        "element": viewPath,
                        "page": vcClassName
                    ]

                    if let customParams = config.params {
                        for (k, v) in customParams {
                            params[k] = v
                        }
                    }

                    Analytics.shared.track(config.eventName, params: params)
                }
            }
        }
    }

    private func generateViewPath() -> String {
        var path: [String] = []

        var currentView: UIView? = self
        while let view = currentView {
            let className = String(describing: type(of: view))

            if let accessibilityLabel = view.accessibilityLabel, !accessibilityLabel.isEmpty {
                path.append(accessibilityLabel)
                break
            }

            if let reuseIdentifier = getReuseIdentifier(from: view) {
                path.append(reuseIdentifier)
                break
            }

            path.append(className)

            currentView = view.superview
        }

        return path.reversed().joined(separator: ".")
    }

    private func getReuseIdentifier(from view: UIView) -> String? {
        if let cell = view as? UITableViewCell {
            return cell.reuseIdentifier
        }
        if let cell = view as? UICollectionViewCell {
            return cell.reuseIdentifier
        }
        return nil
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
}
