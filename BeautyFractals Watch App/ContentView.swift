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
        GeometryReader { geometry in
            ZStack {
                FractalBackdrop()

                if let image = mirror.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .overlay(.black.opacity(0.14))
                }

                if mirror.isRendering {
                    ZStack {
                        Circle()
                            .stroke(.black.opacity(0.42), lineWidth: 8)

                        Circle()
                            .trim(from: 0, to: mirror.renderProgress)
                            .stroke(
                                Color.cyan,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Text(mirror.renderPercentText)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .frame(width: 82, height: 82)
                    .padding(10)
                    .background(.black.opacity(0.46), in: Circle())
                    .shadow(color: .black.opacity(0.28), radius: 7, y: 3)
                    .accessibilityLabel("Render progress")
                    .accessibilityValue(mirror.renderPercentText)
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
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9)

                Text(mirror.zoomText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.78), in: Capsule())
                    .frame(maxWidth: max(80, geometry.size.width - 24))
                    .position(
                        x: geometry.size.width / 2,
                        y: max(18, geometry.size.height - 18)
                    )
                    .zIndex(100)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Zoom")
                    .accessibilityValue(mirror.zoomText)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onTapGesture {
                mirror.requestLatestFrame()
            }
        }
    }
}

@MainActor
final class WatchFractalMirrorStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var image: UIImage?
    @Published private(set) var zoomText = "Waiting for iPhone…"
    @Published private(set) var statusText = "Mirror ready"
    @Published private(set) var renderProgress = 0.0
    @Published private(set) var isRendering = false

    var renderPercentText: String {
        "\(Int((renderProgress * 100).rounded()))%"
    }

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
        if let data = context["fractalJPEG"] as? Data,
           let image = UIImage(data: data) {
            self.image = image
            UserDefaults.standard.set(data, forKey: imageKey)
        }

        if let zoomText = context["zoomText"] as? String {
            self.zoomText = zoomText
            UserDefaults.standard.set(zoomText, forKey: zoomKey)
        }

        if let statusText = context["statusText"] as? String {
            self.statusText = statusText
            UserDefaults.standard.set(statusText, forKey: statusKey)
        }

        if let progress = context["renderProgress"] as? Double {
            renderProgress = min(max(progress, 0), 1)
        }
        if let isRendering = context["isRendering"] as? Bool {
            self.isRendering = isRendering
        }
    }

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in
            if context.isEmpty {
                self.requestLatestFrame()
            } else {
                self.accept(context: context)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in
            self.requestLatestFrame()
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

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.accept(context: message)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.accept(context: userInfo)
        }
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
