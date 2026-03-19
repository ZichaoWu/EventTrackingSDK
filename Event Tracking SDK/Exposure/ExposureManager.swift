import UIKit

// ============================================================
// MARK: - 曝光跟踪协议
// ============================================================

/// 曝光跟踪协议
/// 让数据模型实现此协议，提供唯一的曝光 ID
///
/// - 为什么需要这个协议？
///   传统方式用 "section_row" 作为曝光 key
///   问题：列表数据变化时，key 不变会导致重复曝光
///
/// - 正确做法：
///   给每个数据模型一个唯一 ID，无论位置如何变化
///   只有 ID 变化时才触发新曝光
public protocol ExposureTrackable {
    var exposureId: String { get }
}

// ============================================================
// MARK: - 曝光管理器
// ============================================================

/// 曝光管理器，负责检测列表项的可见性并触发曝光事件
///
/// - 工作原理：
///   1. 用户滚动列表 → scrollViewDidScroll
///   2. 计算每个可见 Cell 的可见比例
///   3. 超过 50% 视为"曝光"
///   4. 只在首次曝光时触发，之后不再重复
///
/// - 核心特性：
///   1. 节流（throttle）：0.1 秒内只处理一次，避免频繁触发
///   2. 去重：同一个曝光 ID 只触发一次
///   3. 多列表支持：用 pendingScrollViews 字典支持同时监听多个列表
///   4. 强制协议：必须实现 ExposureTrackable，保证 key 稳定性
public class ExposureManager {

    public static let shared = ExposureManager()

    /// 已曝光集合：记录哪些 ID 已经曝光过
    /// 用 Set 存储，查找效率 O(1)
    private var exposedSet: Set<String> = []

    /// 线程锁：保护 exposedSet 的并发访问
    private let lock = NSLock()

    /// 上次触发时间：用于节流控制
    private var lastTriggerTime: Date = .distantPast

    /// 节流间隔：0.1 秒
    /// 滚动时 100ms 内只处理一次，避免性能问题
    private let throttleInterval: TimeInterval = 0.1

    /// 待处理滚动视图字典
    /// 支持同时监听多个列表滚动
    /// Key: 滚动视图，Value: 列表 ID
    private var pendingScrollViews: [UIScrollView: String] = [:]

    private init() {}

    public func handleScroll(_ scrollView: UIScrollView, listId: String? = nil) {
        let now = Date()

        lock.lock()
        let timeSinceLastTrigger = now.timeIntervalSince(lastTriggerTime)
        if timeSinceLastTrigger < throttleInterval {
            pendingScrollViews[scrollView] = listId
            lock.unlock()
            scheduleDelayedHandle()
            return
        }
        lastTriggerTime = now
        lock.unlock()

        processScroll(scrollView, listId: listId)
    }

    private func scheduleDelayedHandle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + throttleInterval) { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            let pendingCopy = self.pendingScrollViews
            self.pendingScrollViews.removeAll()
            self.lock.unlock()

            for (scrollView, listId) in pendingCopy {
                self.processScroll(scrollView, listId: listId)
            }
        }
    }

    private func processScroll(_ scrollView: UIScrollView, listId: String?) {
        if let tableView = scrollView as? UITableView {
            processTableView(tableView, listId: listId)
        } else if let collectionView = scrollView as? UICollectionView {
            processCollectionView(collectionView, listId: listId)
        }
    }

    private func processTableView(_ tableView: UITableView, listId: String?) {
        guard let visible = tableView.indexPathsForVisibleRows else { return }

        for indexPath in visible {
            let key = generateKey(for: indexPath, in: tableView)

            lock.lock()
            if exposedSet.contains(key) {
                lock.unlock()
                continue
            }
            lock.unlock()

            if let cell = tableView.cellForRow(at: indexPath) {
                let rect = tableView.rectForRow(at: indexPath)
                let visibleRect = tableView.bounds.intersection(rect)

                let ratio = visibleRect.height / rect.height

                if ratio > 0.5 {
                    lock.lock()
                    exposedSet.insert(key)
                    lock.unlock()

                    var params: [String: Any] = [
                        "row": indexPath.row,
                        "section": indexPath.section,
                        "cell_type": "\(type(of: cell))"
                    ]
                    if let listId = listId {
                        params["list_id"] = listId
                    }

                    if let model = getModel(for: indexPath, in: tableView) as? ExposureTrackable {
                        params["exposure_id"] = model.exposureId
                    }

                    Analytics.shared.track("cell_expose", params: params)
                }
            }
        }
    }

    private func processCollectionView(_ collectionView: UICollectionView, listId: String?) {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems

        for indexPath in visibleIndexPaths {
            let key = generateCollectionKey(for: indexPath, in: collectionView)

            lock.lock()
            if exposedSet.contains(key) {
                lock.unlock()
                continue
            }
            lock.unlock()

            if let cell = collectionView.cellForItem(at: indexPath) {
                let rect = collectionView.layoutAttributesForItem(at: indexPath)?.frame ?? .zero
                let visibleRect = collectionView.bounds.intersection(rect)

                let ratio = rect.height > 0 ? visibleRect.height / rect.height : 0

                if ratio > 0.5 {
                    lock.lock()
                    exposedSet.insert(key)
                    lock.unlock()

                    var params: [String: Any] = [
                        "row": indexPath.row,
                        "section": indexPath.section,
                        "cell_type": "\(type(of: cell))"
                    ]
                    if let listId = listId {
                        params["list_id"] = listId
                    }

                    if let model = getModel(for: indexPath, in: collectionView) as? ExposureTrackable {
                        params["exposure_id"] = model.exposureId
                    }

                    Analytics.shared.track("cell_expose", params: params)
                }
            }
        }
    }

    private func getModel(for indexPath: IndexPath, in tableView: UITableView) -> Any? {
        if let dataSource = tableView.dataSource as? UITableViewDiffableDataSource<AnyHashable, AnyHashable> {
            return dataSource.itemIdentifier(for: indexPath)
        }

        if let dataSource = tableView.dataSource {
            let numberOfSections = dataSource.numberOfSections?(in: tableView) ?? 1
            if indexPath.section < numberOfSections {
                let numberOfRows = dataSource.tableView(tableView, numberOfRowsInSection: indexPath.section)
                if indexPath.row < numberOfRows {
                    return dataSource.tableView(tableView, cellForRowAt: indexPath)
                }
            }
        }

        return nil
    }

    private func getModel(for indexPath: IndexPath, in collectionView: UICollectionView) -> Any? {
        if let dataSource = collectionView.dataSource as? UICollectionViewDiffableDataSource<AnyHashable, AnyHashable> {
            return dataSource.itemIdentifier(for: indexPath)
        }

        if let dataSource = collectionView.dataSource {
            let numberOfSections = dataSource.numberOfSections?(in: collectionView) ?? 1
            if indexPath.section < numberOfSections {
                let numberOfItems = dataSource.collectionView(collectionView, numberOfItemsInSection: indexPath.section)
                if indexPath.item < numberOfItems {
                    return dataSource.collectionView(collectionView, cellForItemAt: indexPath)
                }
            }
        }

        return nil
    }

    private func generateKey(for indexPath: IndexPath, in tableView: UITableView) -> String {
        guard let model = getModel(for: indexPath, in: tableView) as? ExposureTrackable else {
            fatalError("Cell 必须实现 ExposureTrackable 协议以保证曝光稳定性")
        }
        return model.exposureId
    }

    private func generateCollectionKey(for indexPath: IndexPath, in collectionView: UICollectionView) -> String {
        guard let model = getModel(for: indexPath, in: collectionView) as? ExposureTrackable else {
            fatalError("Cell 必须实现 ExposureTrackable 协议以保证曝光稳定性")
        }
        return model.exposureId
    }

    public func trackExposure(for item: ExposureTrackable, listId: String? = nil) {
        let key = item.exposureId

        lock.lock()
        if exposedSet.contains(key) {
            lock.unlock()
            return
        }
        exposedSet.insert(key)
        lock.unlock()

        var params: [String: Any] = ["exposure_id": item.exposureId]
        if let listId = listId {
            params["list_id"] = listId
        }

        Analytics.shared.track("cell_expose", params: params)
    }

    public func resetExposedSet() {
        lock.lock()
        exposedSet.removeAll()
        lock.unlock()
    }

    public func resetExposedSet(for listId: String) {
        lock.lock()
        exposedSet = exposedSet.filter { !$0.hasPrefix("\(listId)_") }
        lock.unlock()
    }

    public func handleScrollEnd(_ scrollView: UIScrollView, listId: String? = nil) {
        processScroll(scrollView, listId: listId)
    }
}
