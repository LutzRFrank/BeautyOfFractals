import SwiftUI
import AppKit

@main
struct MandelbrotExplorerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Fractal") {
                Button("Export 2560 × 1600 PNG") {
                    NotificationCenter.default.post(
                        name: .exportDefaultFractal,
                        object: nil
                    )
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Divider()
                
                Button("Zoom In") {
                    NotificationCenter.default.post(
                        name: .zoomInFractal,
                        object: nil
                    )
                }
                .keyboardShortcut("+", modifiers: [])
                
                Button("Zoom Out") {
                    NotificationCenter.default.post(
                        name: .zoomOutFractal,
                        object: nil
                    )
                }
                .keyboardShortcut("-", modifiers: [])
                
                Button("Reset View") {
                    NotificationCenter.default.post(
                        name: .resetFractal,
                        object: nil
                    )
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

extension Notification.Name {
    static let exportDefaultFractal = Notification.Name("exportDefaultFractal")
    static let zoomInFractal = Notification.Name("zoomInFractal")
    static let zoomOutFractal = Notification.Name("zoomOutFractal")
    static let resetFractal = Notification.Name("resetFractal")
}

struct FractalActions {
    let snap: () -> Void
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let reset: () -> Void
}

private struct FractalActionsKey: FocusedValueKey {
    typealias Value = FractalActions
}

extension FocusedValues {
    var fractalActions: FractalActions? {
        get { self[FractalActionsKey.self] }
        set { self[FractalActionsKey.self] = newValue }
    }
}
