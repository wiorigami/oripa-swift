// Splash screen — port of `SplashActivity` / `SplashTheme` (`background_splash_raster`).
//
// Android: the window background is grey_50 (#fafafa) with the centred
// `oripa_logo_text_v2_raster` bitmap; `SplashActivity.onCreate` immediately starts
// `ProjectsActivity` and finishes. The port keeps the branded splash for 800 ms (the JS
// port's SPLASH_DURATION_MS), then replaces itself with the projects screen.
import SwiftUI

public struct SplashScreen: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.oripaNavID) private var navID

    @State private var logoVisible = false
    @State private var didScheduleTransition = false

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                OrTheme.background.ignoresSafeArea()
                OripaLogo(.wordmark,
                          height: min(proxy.size.height * 0.46, 480))
                    .frame(maxWidth: proxy.size.width * 0.72)
                    .opacity(logoVisible ? 1 : 0)
                    .scaleEffect(logoVisible ? 1 : 0.985)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            // splash-in 280 ms ease-out
            withAnimation(.easeOut(duration: 0.28)) { logoVisible = true }
        }
        .task {
            // SplashActivity.startActivity(ProjectsActivity) + finish(), after 800 ms.
            guard !didScheduleTransition else { return }
            didScheduleTransition = true
            try? await Task.sleep(nanoseconds: UInt64(OrTheme.splashDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if case .splash? = app.currentRoute {
                app.replaceTop(.projects)
            }
        }
        .onAppear {
            // SplashActivity swallows back while it is finishing.
            app.setBackHandler(for: navID) { true }
        }
        .onDisappear {
            app.removeBackHandler(for: navID)
        }
    }
}
