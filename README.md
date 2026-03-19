# EventTrackingSDK

A comprehensive event tracking SDK for iOS, featuring automatic page tracking, exposure tracking, session management, and more.

## Features

- ✅ **Automatic Page Tracking** - Track page show/hide events automatically
- ✅ **Exposure Tracking** - Track when list items become visible
- ✅ **Session Management** - Automatic session timeout and renewal
- ✅ **Sampling** - Control data volume with sampling rates
- ✅ **Interceptor Chain** - AOP-based event enrichment
- ✅ **Batch Upload** - Optimize network requests
- ✅ **Disk Persistence** - Never lose events
- ✅ **Retry Mechanism** - Exponential backoff for failed uploads
- ✅ **Debug Mode** - Easy debugging with console logs
- ✅ **Dynamic Tracking** - Server-side config support
- ✅ **Visual Tracking** - UI-based event creation
- ✅ **DSL** - Elegant tracking syntax

## Requirements

- iOS 13.0+
- Swift 5.0+

## Installation

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'EventTrackingSDK', :git => 'https://github.com/yourusername/EventTrackingSDK.git', :tag => '1.0.0'
```

Then run:

```bash
pod install
```

### Swift Package Manager

Add the package to your project:

1. In Xcode, go to `File` → `Swift Packages` → `Add Package Dependency`
2. Enter the GitHub URL: `https://github.com/yourusername/EventTrackingSDK.git`
3. Select the version you want to use

## Quick Start

### 1. Initialize in AppDelegate

```swift
import EventTrackingSDK

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Enable automatic page tracking
    UIViewController.swizzle()
    
    // Set server URL (optional)
    UploadManager.shared.setServerURL("https://your-analytics-server.com/track")
    
    // Enable debug mode (optional)
    AnalyticsConfig.shared.setDebugMode(true)
    
    // Track app launch
    Analytics.shared.trackAppLaunch()
    
    return true
}

// Flush events when app enters background
func applicationDidEnterBackground(_ application: UIApplication) {
    Analytics.shared.flush()
}

// Track app exit
func applicationWillTerminate(_ application: UIApplication) {
    Analytics.shared.trackAppExit()
    Analytics.shared.flush()
}
```

### 2. Basic Tracking

```swift
// Track a custom event
Analytics.shared.track("button_click", params: ["button_id": "buy"])

// Track a click event
Analytics.shared.trackClick("buy_button")

// Track page duration
Analytics.shared.trackPageDuration("home", duration: 60.5)
```

### 3. Exposure Tracking

```swift
// Make your data model conform to ExposureTrackable
struct Product: ExposureTrackable {
    let id: String
    let name: String
    
    var exposureId: String {
        return "product_\(id)"
    }
}

// Handle scroll in your table view
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    ExposureManager.shared.handleScroll(scrollView)
}
```

### 4. DSL Usage

```swift
// Using DSL
AnalyticsDSL.track {
    EventBuilder.click("buy_button")
        .page("product_detail")
        .param("product_id", value: "123")
}

// Batch tracking
AnalyticsDSL.batch {
    EventBuilder.pageView("home")
    EventBuilder.click("banner")
}
```

## Configuration

```swift
// Enable/disable tracking
AnalyticsConfig.shared.setEnabled(true)

// Set sampling rate (0.0-1.0)
AnalyticsConfig.shared.setSamplingRate(0.8) // 80% sampling

// Event-specific configuration
AnalyticsConfig.shared.setEventConfig("click", config: 
    AnalyticsConfig.EventConfig(enabled: true, samplingRate: 1.0)
)

// Update config from server
let configData = // Data from server
AnalyticsConfig.shared.updateConfigFromServer(configData)
```

## Advanced Features

### Custom Interceptor

```swift
class UserInterceptor: AnalyticsInterceptor {
    func intercept(event: inout Event) -> Bool {
        event.params["user_id"] = AnyCodable(getCurrentUserId())
        return true
    }
}

// Add to chain
InterceptorChain.shared.addInterceptor(UserInterceptor())
```

### Dynamic Tracking

```swift
// Enable dynamic tracking
DynamicTracker.shared.enable()

// Update config from server
let config: [String: DynamicTracker.TrackConfig] = [
    "home_banner": DynamicTracker.TrackConfig(
        eventName: "banner_click",
        action: "click",
        page: "HomeViewController"
    )
]
DynamicTracker.shared.updateConfigs(config)
```

### Visual Tracking

```swift
// Start visual tracking mode
VisualTracker.shared.start()

// Select views to generate tracking code
// Stop when done
VisualTracker.shared.stop()
```

## Troubleshooting

### Common Issues

1. **Cell must implement ExposureTrackable**
   - Ensure your cell or data model implements the `ExposureTrackable` protocol

2. **Sampling not working**
   - Check your sampling rate settings
   - Verify event-specific configurations

3. **Events not uploading**
   - Check server URL configuration
   - Look for network errors in console
   - Check failed events count: `UploadManager.shared.getFailedEventsCount()`

### Debugging

```swift
// Enable debug mode
AnalyticsConfig.shared.setDebugMode(true)

// Check queue size
print("Queue size: \(EventQueue.shared.getEventsCount())")

// Manually flush events
Analytics.shared.flush()
```

## Architecture

- **Core** - Main analytics functionality
- **Storage** - Disk persistence
- **Upload** - Network upload with retry
- **Exposure** - View exposure tracking
- **Hook** - Automatic page tracking
- **Dynamic** - Server-side config
- **Visual** - UI-based tracking

## License

MIT License - see the [LICENSE](LICENSE) file for details
