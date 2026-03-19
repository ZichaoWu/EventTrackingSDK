import class Foundation.Bundle

extension Foundation.Bundle {
    static let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("EventTrackingSDK_EventTrackingSDK.bundle").path
        let buildPath = "/Users/mac/Desktop/Swift/Event Tracking SDK/.build/x86_64-apple-macosx/debug/EventTrackingSDK_EventTrackingSDK.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}