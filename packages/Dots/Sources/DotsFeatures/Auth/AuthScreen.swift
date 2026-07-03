import ComposableArchitecture2
import DotsDomain
import DotsUI
import SwiftUI

/// The entry surface, ported from proof's login screen: a split brand panel +
/// live shader when wide; a full-bleed shader with a floating glass sheet when
/// narrow. Theme and backdrop controls float bottom-trailing as glass.
struct AuthScreen: View {
    private let store: StoreOf<Auth>

    @AppStorage("blog.dots.appearanceMode") private var appearanceRaw = DotsAppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @State private var isWide = false
    // Sticky backdrop: you land on whichever shader you last left it on.
    @AppStorage("blog.dots.heroShader") private var shaderRaw = DotsHeroShader.halftone.rawValue

    init(store: StoreOf<Auth>) {
        self.store = store
    }

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width > proxy.size.height * 1.05
            Group {
                if wide {
                    splitLayout
                } else {
                    backdropLayout
                }
            }
            .onChange(of: wide, initial: true) { _, newValue in
                isWide = newValue
            }
        }
        .ignoresSafeArea()
        // Full-bleed like Home: hide the titlebar's own chrome so the
        // backdrop runs edge to edge under the traffic lights — no opaque
        // strip with its own appearance opinions.
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        // The brand mark already says Dots — no window title needed.
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .overlay(alignment: .topLeading) {
            // Over a shader the mark wears glass for local contrast on any
            // backdrop; on the wide layout it sits on the solid panel.
            Group {
                if isWide {
                    DotsLogoMark(height: 18)
                } else {
                    DotsLogoMark(height: 18)
                        .padding(.horizontal, DotsSpacing.md)
                        .padding(.vertical, DotsSpacing.sm)
                        .background(Capsule().fill(.ultraThinMaterial))
                }
            }
            .padding(DotsSpacing.xl)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: DotsSpacing.sm) {
                DotsGlassButton(systemName: themeIcon, accessibilityLabel: themeLabel) {
                    toggleAppearance()
                }
                DotsGlassButton(
                    systemName: "arrow.right",
                    accessibilityLabel: "Next backdrop style"
                ) {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        shaderRaw = shader.next.rawValue
                    }
                }
            }
            .padding(DotsSpacing.xl)
        }
    }

    // MARK: Theme

    private var themeIcon: String {
        colorScheme == .dark ? "sun.max.fill" : "moon.fill"
    }

    private var themeLabel: String {
        colorScheme == .dark ? "Switch to light mode" : "Switch to dark mode"
    }

    private func toggleAppearance() {
        let target: DotsAppearanceMode = colorScheme == .dark ? .light : .dark
        appearanceRaw = target.rawValue
    }

    // MARK: Layouts

    private var shader: DotsHeroShader {
        DotsHeroShader(rawValue: shaderRaw) ?? .halftone
    }

    private var heroBackdrop: some View {
        DotsHeroShaderView(shader)
            .id(shader)
            .transition(.opacity)
    }

    private var splitLayout: some View {
        HStack(spacing: 0) {
            brandPanel
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DotsColor.Background.primary)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(DotsColor.Background.hairline)
                        .frame(width: 0.5)
                }
                .zIndex(1)

            heroBackdrop
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var brandPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            brandMark
            Spacer(minLength: DotsSpacing.xxl)
            panelContent
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 340, alignment: .leading)
        .padding(.horizontal, DotsSpacing.xxl)
        .padding(.vertical, DotsSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var backdropLayout: some View {
        ZStack {
            heroBackdrop

            LinearGradient(
                colors: [
                    .clear,
                    DotsColor.Hero.scrim,
                    DotsColor.Hero.scrim.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Chrome only — touches must fall through to the shader.
            .allowsHitTesting(false)

            VStack(alignment: .center, spacing: 0) {
                Spacer(minLength: 0)
                authSheet
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, DotsSpacing.xl)
            .padding(.top, DotsSpacing.xxl)
            .padding(.bottom, DotsSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var authSheet: some View {
        VStack(spacing: 0) {
            brandMark
                .padding(.bottom, DotsSpacing.lg)
            panelContent
        }
        .padding(DotsSpacing.lg)
        // Liquid glass, regular weight: ultraThin lets a bright backdrop wash
        // out light-mode ink; regular keeps the glass read with stable type.
        .background(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.panel, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.panel, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        )
        .dotsElevation(.floating)
    }

    // MARK: Content

    private var brandMark: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.sm) {
            Text("Dots")
                .font(DotsTypography.display)
                .foregroundStyle(DotsColor.Ink.primary)
            Text("Read to collect dots. Write to connect them.")
                .font(DotsTypography.title)
                .fontWeight(.regular)
                .foregroundStyle(DotsColor.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var panelContent: some View {
        if let grant = store.grant {
            verification(grant: grant)
        } else {
            authButtons
        }

        if let errorMessage = store.errorMessage {
            Text(errorMessage)
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Accent.red)
                .padding(.top, DotsSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var authButtons: some View {
        VStack(spacing: DotsSpacing.sm) {
            DotsProviderSignInButton(
                title: "Sign in with GitHub",
                accessibilityLabel: "Sign in with GitHub",
                style: .filled
            ) {
                store.send(.signInButtonTapped)
            }
            .disabled(store.isWorking)

            DotsProviderSignInButton(
                title: "Use locally",
                accessibilityLabel: "Continue without signing in",
                style: .elevated
            ) {
                store.send(.useLocallyButtonTapped)
            }
        }
    }

    private func verification(grant: DeviceCodeGrant) -> some View {
        VStack(spacing: DotsSpacing.md) {
            DotsMetaLabel("ENTER THIS CODE ON GITHUB")

            Text(grant.userCode)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .tracking(5)
                .foregroundStyle(DotsColor.Ink.primary)
                .textSelection(.enabled)

            Link(destination: grant.verificationURL) {
                Text("Open GitHub")
                    .font(DotsTypography.headline)
                    .foregroundStyle(DotsColor.Ink.inverse)
                    .padding(.horizontal, DotsSpacing.xl)
                    .padding(.vertical, DotsSpacing.sm)
                    .background(DotsColor.Ink.primary, in: Capsule())
            }

            HStack(spacing: DotsSpacing.xs) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for approval — we'll finish automatically.")
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.muted)
            }
        }
        .frame(maxWidth: .infinity)
    }

}

#Preview("Auth — wide") {
    AuthScreen(
        store: Store(initialState: Auth.State()) {
            Auth()
        }
    )
    .frame(width: 1100, height: 700)
}

#Preview("Auth — narrow") {
    AuthScreen(
        store: Store(initialState: Auth.State()) {
            Auth()
        }
    )
    .frame(width: 500, height: 760)
}
