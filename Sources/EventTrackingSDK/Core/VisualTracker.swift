import UIKit

public class VisualTracker {

    public static let shared = VisualTracker()

    private var overlayWindow: UIWindow?
    private var selectedView: UIView?
    private var viewHierarchy: [ViewInfo] = []
    private var isActive: Bool = false

    public struct ViewInfo: Codable {
        public let className: String
        public let accessibilityLabel: String?
        public let viewId: String?
        public let frame: CGRect
        public let superClassName: String?
        public let xPath: String

        public init(className: String, accessibilityLabel: String?, viewId: String?, frame: CGRect, superClassName: String?, xPath: String) {
            self.className = className
            self.accessibilityLabel = accessibilityLabel
            self.viewId = viewId
            self.frame = frame
            self.superClassName = superClassName
            self.xPath = xPath
        }
    }

    public struct TrackingCode: Codable {
        public let viewInfo: ViewInfo
        public let suggestedEventName: String
        public let suggestedParams: [String: String]

        public init(viewInfo: ViewInfo, suggestedEventName: String, suggestedParams: [String: String]) {
            self.viewInfo = viewInfo
            self.suggestedEventName = suggestedEventName
            self.suggestedParams = suggestedParams
        }

        public func generateCode() -> String {
            var code = "Analytics.shared.track(\"\(suggestedEventName)\", params: ["

            var params: [String] = []
            for (key, value) in suggestedParams {
                params.append("\"\(key)\": \"\(value)\"")
            }

            code += params.joined(separator: ", ")
            code += "])"

            return code
        }
    }

    private init() {}

    public func start() {
        guard !isActive else { return }
        isActive = true

        setupOverlayWindow()
        setupGesture()
    }

    public func stop() {
        isActive = false
        overlayWindow?.isHidden = true
        selectedView = nil
    }

    private func setupOverlayWindow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow?.windowLevel = .alert + 1
        overlayWindow?.backgroundColor = .clear
        overlayWindow?.isUserInteractionEnabled = true

        let viewController = OverlayViewController()
        viewController.visualTracker = self
        overlayWindow?.rootViewController = viewController
        overlayWindow?.isHidden = false
    }

    private func setupGesture() {
    }

    public func selectView(_ view: UIView) {
        selectedView = view
        captureViewHierarchy()
    }

    public func getSelectedViewInfo() -> ViewInfo? {
        guard let view = selectedView else { return nil }
        return buildViewInfo(for: view)
    }

    public func generateTrackingCode(for view: UIView) -> TrackingCode {
        let viewInfo = buildViewInfo(for: view)
        let eventName = suggestEventName(for: view)
        let params = suggestParams(for: view)

        return TrackingCode(viewInfo: viewInfo, suggestedEventName: eventName, suggestedParams: params)
    }

    private func captureViewHierarchy() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }

        viewHierarchy = []
        captureView(window, xPath: "/")
    }

    private func captureView(_ view: UIView, xPath: String) {
        let viewInfo = buildViewInfo(for: view, xPath: xPath)
        viewHierarchy.append(viewInfo)

        for (index, subview) in view.subviews.enumerated() {
            let childXPath = "\(xPath)/\(view.className)[\(index)]"
            captureView(subview, xPath: childXPath)
        }
    }

    private func buildViewInfo(for view: UIView, xPath: String = "") -> ViewInfo {
        let className = String(describing: type(of: view))
        let superClassName = view.superclass.map { String(describing: $0) }

        var accessibilityLabel: String? = nil
        if let label = view.accessibilityLabel, !label.isEmpty {
            accessibilityLabel = label
        }

        var viewId: String? = nil
        if let textField = view as? UITextField {
            viewId = textField.placeholder
        } else if let button = view as? UIButton {
            viewId = button.currentTitle
        } else if let label = view as? UILabel {
            viewId = label.text
        }

        return ViewInfo(
            className: className,
            accessibilityLabel: accessibilityLabel,
            viewId: viewId,
            frame: view.frame,
            superClassName: superClassName,
            xPath: xPath
        )
    }

    private func suggestEventName(for view: UIView) -> String {
        if view is UIButton {
            return "button_click"
        } else if view is UITextField {
            return "text_input"
        } else if view is UISwitch {
            return "switch_toggle"
        } else if view is UISlider {
            return "slider_change"
        } else if view is UISegmentedControl {
            return "segment_select"
        } else if view is UITableView {
            return "table_click"
        } else if view is UICollectionView {
            return "collection_click"
        }

        return "element_click"
    }

    private func suggestParams(for view: UIView) -> [String: String] {
        var params: [String: String] = [:]

        let className = String(describing: type(of: view))
        params["element_type"] = className

        if let vc = findViewController(for: view) {
            params["page"] = NSStringFromClass(type(of: vc))
        }

        if let accessibilityLabel = view.accessibilityLabel, !accessibilityLabel.isEmpty {
            params["element_label"] = accessibilityLabel
        }

        if let button = view as? UIButton, let title = button.currentTitle {
            params["button_text"] = title
        }

        if let cell = view as? UITableViewCell {
            params["cell_reuse_id"] = cell.reuseIdentifier ?? ""
        }

        if let cell = view as? UICollectionViewCell {
            params["cell_reuse_id"] = cell.reuseIdentifier ?? ""
        }

        return params
    }

    private func findViewController(for view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }

    public func traverseViewTree(from rootView: UIView? = nil, maxDepth: Int = 10) -> [ViewInfo] {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return []
        }

        let root = rootView ?? window
        var result: [ViewInfo] = []

        traverse(root, currentDepth: 0, maxDepth: maxDepth, result: &result)

        return result
    }

    private func traverse(_ view: UIView, currentDepth: Int, maxDepth: Int, result: inout [ViewInfo]) {
        guard currentDepth < maxDepth else { return }

        result.append(buildViewInfo(for: view))

        for subview in view.subviews {
            traverse(subview, currentDepth: currentDepth + 1, maxDepth: maxDepth, result: &result)
        }
    }

    public func findViews(matching predicate: (ViewInfo) -> Bool) -> [ViewInfo] {
        let allViews = traverseViewTree()
        return allViews.filter(predicate)
    }

    public func getViewHierarchyJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(viewHierarchy),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }
}

private class OverlayViewController: UIViewController {

    weak var visualTracker: VisualTracker?

    private var selectionOverlay: UIView?
    private var highlightLayer: CAShapeLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }

        let convertedLocation = CGPoint(
            x: location.x + window.frame.origin.x,
            y: location.y + window.frame.origin.y
        )

        if let hitView = window.hitTest(convertedLocation, with: nil) {
            visualTracker?.selectView(hitView)

            showHighlight(for: hitView)

            if let viewInfo = visualTracker?.getSelectedViewInfo(),
               let trackingCode = visualTracker?.generateTrackingCode(for: hitView) {
                print("选中的视图信息:")
                print("  类名: \(viewInfo.className)")
                print("  可访问性标签: \(viewInfo.accessibilityLabel ?? "无")")
                print("  建议事件名: \(trackingCode.suggestedEventName)")
                print("  生成的代码: \(trackingCode.generateCode())")
            }
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: view)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }

        let convertedLocation = CGPoint(
            x: location.x + window.frame.origin.x,
            y: location.y + window.frame.origin.y
        )

        if let hitView = window.hitTest(convertedLocation, with: nil) {
            showHighlight(for: hitView)
        }
    }

    private func showHighlight(for view: UIView) {
        highlightLayer?.removeFromSuperlayer()

        let highlight = CAShapeLayer()
        highlight.frame = view.convert(view.bounds, to: self.view)
        highlight.path = UIBezierPath(rect: highlight.frame).cgPath
        highlight.fillColor = UIColor.clear.cgColor
        highlight.strokeColor = UIColor.systemBlue.cgColor
        highlight.lineWidth = 2.0

        view.layer.addSublayer(highlight)
        highlightLayer = highlight

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.highlightLayer?.removeFromSuperlayer()
        }
    }
}

public extension VisualTracker {

    func exportViewTree() -> String? {
        captureViewHierarchy()
        return getViewHierarchyJSON()
    }

    func findButtons() -> [ViewInfo] {
        return findViews { $0.className.contains("Button") }
    }

    func findTextFields() -> [ViewInfo] {
        return findViews { $0.className.contains("TextField") }
    }

    func findTableViews() -> [ViewInfo] {
        return findViews { $0.className.contains("TableView") }
    }

    func findCollectionViews() -> [ViewInfo] {
        return findViews { $0.className.contains("CollectionView") }
    }
}
