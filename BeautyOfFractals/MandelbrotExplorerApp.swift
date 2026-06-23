import SwiftUI
import AppKit

@main
struct MandelbrotExplorerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    DispatchQueue.main.async {
                        AppDelegate.resizeMainWindowToAppStoreSize()
                    }
                }
        }
        .defaultSize(width: 1280, height: 800)
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
                
                Divider()
                
                Button("Show / Hide Render Status") {
                    NotificationCenter.default.post(
                        name: .toggleRenderStatus,
                        object: nil
                    )
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
    
    static func resizeMainWindowToAppStoreSize() {
        guard let window = NSApplication.shared.windows.first else { return }
        
        let targetSize = NSSize(width: 1280, height: 800)
        let currentFrame = window.frame
        
        let newOrigin = NSPoint(
            x: currentFrame.midX - targetSize.width / 2.0,
            y: currentFrame.midY - targetSize.height / 2.0
        )
        
        let newFrame = NSRect(origin: newOrigin, size: targetSize)
        window.setFrame(newFrame, display: true, animate: false)
        window.center()
    }
}

extension Notification.Name {
    static let exportDefaultFractal = Notification.Name("exportDefaultFractal")
    static let zoomInFractal = Notification.Name("zoomInFractal")
    static let zoomOutFractal = Notification.Name("zoomOutFractal")
    static let resetFractal = Notification.Name("resetFractal")
    static let toggleRenderStatus = Notification.Name("toggleRenderStatus")
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
