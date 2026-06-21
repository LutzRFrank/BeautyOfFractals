//
//  ContentView.swift
//  BeautyFractals Watch App
//

import SwiftUI
import Combine
import WatchConnectivity
import UIKit

struct ContentView: View {
    @StateObject private var mirror = WatchFractalMirrorStore()

    var body: some View {
        ZStack {
            FractalBackdrop()

            if let image = mirror.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(.black.opacity(0.14))
            }

            VStack(spacing: 5) {
                if mirror.image == nil {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)

                    Text("Beauty of\nFractals")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(mirror.statusText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                } else {
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                VStack(spacing: 2) {
                    Text(mirror.zoomText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text(mirror.statusText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.44), in: Capsule())
                .padding(.bottom, 3)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            mirror.requestLatestFrame()
        }
    }
}

@MainActor
final class WatchFractalMirrorStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var image: UIImage?
    @Published private(set) var zoomText = "Waiting for iPhone…"
    @Published private(set) var statusText = "Mirror ready"

    private let session = WCSession.default
    private let imageKey = "WatchFractalMirror.lastJPEG"
    private let zoomKey = "WatchFractalMirror.zoomText"
    private let statusKey = "WatchFractalMirror.statusText"

    override init() {
        super.init()
        restoreLastFrame()
        configureSession()
    }

    func requestLatestFrame() {
        guard session.activationState == .activated, session.isReachable else { return }

        session.sendMessage(
            ["action": "requestLatestFrame"],
            replyHandler: { [weak self] context in
                Task { @MainActor in
                    self?.accept(context: context)
                }
            },
            errorHandler: nil
        )
    }

    private func configureSession() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    private func restoreLastFrame() {
        guard let data = UserDefaults.standard.data(forKey: imageKey),
              let image = UIImage(data: data) else { return }

        self.image = image
        zoomText = UserDefaults.standard.string(forKey: zoomKey) ?? zoomText
        statusText = UserDefaults.standard.string(forKey: statusKey) ?? statusText
    }

    private func accept(context: [String: Any]) {
        guard let data = context["fractalJPEG"] as? Data,
              let image = UIImage(data: data) else { return }

        self.image = image
        zoomText = context["zoomText"] as? String ?? "Current view"
        statusText = context["statusText"] as? String ?? "High Precision"

        UserDefaults.standard.set(data, forKey: imageKey)
        UserDefaults.standard.set(zoomText, forKey: zoomKey)
        UserDefaults.standard.set(statusText, forKey: statusKey)
    }

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }

        Task { @MainActor in
            self.accept(context: context)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.accept(context: applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            self.accept(context: message)
        }
        replyHandler([:])
    }
}

private struct FractalBackdrop: View {
    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    Color(red: 0.05, green: 0.24, blue: 0.52),
                    Color(red: 0.02, green: 0.05, blue: 0.16),
                    .black
                ],
                center: .center,
                startRadius: 5,
                endRadius: 120
            )

            Circle()
                .stroke(Color.cyan.opacity(0.20), lineWidth: 1)
                .frame(width: 120, height: 120)

            Circle()
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
                .frame(width: 164, height: 164)

            Circle()
                .fill(.black)
                .frame(width: 66, height: 66)
                .overlay(
                    Circle()
                        .stroke(Color.cyan.opacity(0.46), lineWidth: 1)
                )

            Circle()
                .fill(.black)
                .frame(width: 24, height: 24)
                .offset(x: 42, y: -34)

            Circle()
                .fill(.black)
                .frame(width: 17, height: 17)
                .offset(x: -44, y: 41)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
