public import SwiftUI

/// A single scrollable design-review surface for the whole DotsUI system:
/// color tokens, the type scale, spacing/radius primitives, components, and
/// a live shader showcase. Drop it in a window or preview and scroll.
public struct DotsUIGallery: View {
    private enum ShaderChoice: String, CaseIterable, Identifiable {
        case halftone
        case mosaic

        var id: String { rawValue }

        var label: String {
            switch self {
            case .halftone: "Halftone"
            case .mosaic: "Mosaic"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var isDark = false
    @State private var shaderChoice: ShaderChoice = .halftone
    @State private var burstID = 0
    @State private var burstVisible = false
    @State private var progressDemo = 0.6

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DotsSpacing.xxl) {
                header
                colorSection
                typographySection
                spacingSection
                radiusSection
                componentSection
                shaderSection
            }
            .padding(DotsSpacing.xxl)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background {
            ZStack {
                DotsColor.Background.primary.ignoresSafeArea()
                DotsGridSurface().ignoresSafeArea()
            }
        }
        .preferredColorScheme(isDark ? .dark : .light)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.md) {
            HStack(alignment: .center) {
                DotsLogoMark(height: 18)
                Spacer()
                Toggle(isOn: $isDark) {
                    DotsMetaLabel("Dark", tint: DotsColor.Ink.secondary)
                }
                .toggleStyle(.switch)
                .fixedSize()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DotsColor.Ink.muted)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close gallery")
                .padding(.leading, DotsSpacing.sm)
            }
            DotsWordmark()
            DotsMetaLabel("Design system gallery")
        }
    }

    // MARK: Colors

    private var colorSection: some View {
        section("Color") {
            swatchGroup("Surface", [
                ("canvas", DotsColor.Surface.canvas),
                ("control", DotsColor.Surface.control),
                ("pressed", DotsColor.Surface.pressed),
                ("edge", DotsColor.Surface.edge),
                ("gridLine", DotsColor.Surface.gridLine),
                ("gridMajorLine", DotsColor.Surface.gridMajorLine)
            ])
            swatchGroup("Ink", [
                ("primary", DotsColor.Ink.primary),
                ("secondary", DotsColor.Ink.secondary),
                ("muted", DotsColor.Ink.muted),
                ("inverse", DotsColor.Ink.inverse)
            ])
            swatchGroup("Accent", [
                ("green", DotsColor.Accent.green),
                ("red", DotsColor.Accent.red),
                ("orange", DotsColor.Accent.orange),
                ("brand", DotsColor.brand)
            ])
            swatchGroup("Background", [
                ("primary", DotsColor.Background.primary),
                ("elevated", DotsColor.Background.elevated),
                ("hairline", DotsColor.Background.hairline)
            ])
            swatchGroup("Hero", [
                ("blueDeep", DotsColor.Hero.blueDeep),
                ("ink", DotsColor.Hero.ink),
                ("paper", DotsColor.Hero.paper),
                ("scrim", DotsColor.Hero.scrim)
            ])
            swatchGroup("Spectrum", [
                ("red", DotsColor.Spectrum.red),
                ("orange", DotsColor.Spectrum.orange),
                ("yellow", DotsColor.Spectrum.yellow),
                ("green", DotsColor.Spectrum.green),
                ("blue", DotsColor.Spectrum.blue),
                ("violet", DotsColor.Spectrum.violet)
            ])
        }
    }

    private func swatchGroup(_ name: String, _ swatches: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: DotsSpacing.xs) {
            DotsMetaLabel(name, tint: DotsColor.Ink.secondary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: DotsSpacing.sm, alignment: .topLeading)],
                alignment: .leading,
                spacing: DotsSpacing.sm
            ) {
                ForEach(swatches, id: \.0) { swatch in
                    VStack(alignment: .leading, spacing: DotsSpacing.xs / 2) {
                        RoundedRectangle(cornerRadius: DotsRadius.sm, style: .continuous)
                            .fill(swatch.1)
                            .frame(height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: DotsRadius.sm, style: .continuous)
                                    .strokeBorder(DotsColor.Background.hairline, lineWidth: 1)
                            )
                        Text(swatch.0)
                            .font(DotsTypography.caption)
                            .foregroundStyle(DotsColor.Ink.secondary)
                    }
                }
            }
        }
    }

    // MARK: Typography

    private var typographySection: some View {
        section("Typography") {
            specimen("displayXL · 64 bold", font: DotsTypography.displayXL)
            specimen("display · 52 bold", font: DotsTypography.display)
            specimen("title · 24 semibold", font: DotsTypography.title)
            specimen("titleSmall · 20 semibold", font: DotsTypography.titleSmall)
            specimen("headline · 17 semibold", font: DotsTypography.headline)
            specimen("breadcrumb · 17 medium", font: DotsTypography.breadcrumb)
            specimen("callout · 16 semibold", font: DotsTypography.callout)
            specimen("body · 15 medium", font: DotsTypography.body)
            specimen("footnote · 12 medium", font: DotsTypography.footnote)
            specimen("caption · 11 semibold", font: DotsTypography.caption)
            HStack(spacing: DotsSpacing.md) {
                Text("128")
                    .font(DotsTypography.Metric.countCompact)
                    .foregroundStyle(DotsColor.Ink.primary)
                DotsMetaLabel("Metric.countCompact — numerals only")
            }
            DotsMetaLabel("meta label · tracked uppercase whisper")
        }
    }

    private func specimen(_ name: String, font: Font) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Keep both sides balanced")
                .font(font)
                .foregroundStyle(DotsColor.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(name)
                .font(DotsTypography.caption)
                .foregroundStyle(DotsColor.Ink.muted)
        }
    }

    // MARK: Spacing

    private var spacingSection: some View {
        section("Spacing") {
            spacingRow("xs", DotsSpacing.xs)
            spacingRow("sm", DotsSpacing.sm)
            spacingRow("md", DotsSpacing.md)
            spacingRow("lg", DotsSpacing.lg)
            spacingRow("xl", DotsSpacing.xl)
            spacingRow("xxl", DotsSpacing.xxl)
        }
    }

    private func spacingRow(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: DotsSpacing.md) {
            Text("\(name) · \(Int(value))")
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Ink.secondary)
                .frame(width: 72, alignment: .leading)
            RoundedRectangle(cornerRadius: 2)
                .fill(DotsColor.brand.opacity(0.55))
                .frame(width: value * 4, height: 12)
        }
    }

    // MARK: Radius

    private var radiusSection: some View {
        section("Radius") {
            HStack(alignment: .bottom, spacing: DotsSpacing.md) {
                radiusCell("xs · 4", DotsRadius.xs)
                radiusCell("sm · 6", DotsRadius.sm)
                radiusCell("md · 8", DotsRadius.md)
                radiusCell("xl · 16", DotsRadius.xl)
                radiusCell("xxl · 20", DotsRadius.xxl)
            }
            DotsMetaLabel("Semantic: medallion 4 · control 8 · chip 8 · card 16 · panel 20")
        }
    }

    private func radiusCell(_ name: String, _ radius: CGFloat) -> some View {
        VStack(spacing: DotsSpacing.xs / 2) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DotsColor.Background.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(DotsColor.Background.hairline, lineWidth: 1)
                )
                .frame(width: 64, height: 64)
            Text(name)
                .font(DotsTypography.caption)
                .foregroundStyle(DotsColor.Ink.secondary)
        }
    }

    // MARK: Components

    private var componentSection: some View {
        section("Components") {
            DotsMetaLabel("DotsCard", tint: DotsColor.Ink.secondary)
            DotsCard {
                VStack(alignment: .leading, spacing: DotsSpacing.xs) {
                    Text("Linear equations")
                        .font(DotsTypography.titleSmall)
                        .foregroundStyle(DotsColor.Ink.primary)
                    Text("Solve for the unknown by keeping both sides balanced.")
                        .font(DotsTypography.body)
                        .foregroundStyle(DotsColor.Ink.secondary)
                }
            }

            DotsMetaLabel("DotsHairlineCard", tint: DotsColor.Ink.secondary)
            HStack(spacing: DotsSpacing.md) {
                DotsHairlineCard(
                    title: "Today's session",
                    metaLeading: "2 reviews · 1 lesson",
                    metaTrailing: "~18 min",
                    minHeight: 120,
                    action: {}
                )
                DotsHairlineCard(title: "Map", metaLeading: "14 of 27", minHeight: 120, action: {})
            }

            DotsMetaLabel("Glass buttons", tint: DotsColor.Ink.secondary)
            HStack(spacing: DotsSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DotsRadius.Semantic.card, style: .continuous)
                        .fill(DotsColor.Hero.ink)
                    DotsGlassButton(systemName: "arrow.right", accessibilityLabel: "Next") {}
                }
                .frame(width: 120, height: 76)
                HStack(spacing: DotsSpacing.sm) {
                    DotsGlassIconButton(systemImage: "pencil.tip", label: "Pen", isSelected: true, width: 38, height: 38) {}
                    DotsGlassIconButton(systemImage: "eraser", label: "Eraser", width: 38, height: 38) {}
                    DotsGlassIconButton(systemImage: "arrow.uturn.backward", label: "Undo", isEnabled: false, width: 38, height: 38) {}
                }
            }

            DotsMetaLabel("DotsProgressBar", tint: DotsColor.Ink.secondary)
            VStack(spacing: DotsSpacing.sm) {
                DotsProgressBar(progress: progressDemo).frame(height: 8)
                DotsProgressBar(progress: progressDemo, style: .inset)
                    .frame(width: 220, height: 34)
                    .background(DotsColor.Surface.control, in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: $progressDemo, in: 0...1) {
                    DotsMetaLabel("Progress")
                }
                .frame(maxWidth: 220)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            DotsMetaLabel("Chips + meta label", tint: DotsColor.Ink.secondary)
            HStack(spacing: DotsSpacing.sm) {
                DotsRectLabel(label: "8 XP") {
                    DotsStatusMark(size: .md, color: DotsColor.brand, systemImage: "bolt.fill")
                }
                DotsChip(semantic: DotsColor.solved, systemImage: "checkmark", label: "Correct")
                DotsChip(semantic: DotsColor.needsWork, systemImage: "pencil", label: "Needs work")
            }
            DotsMetaLabel("Tuesday · June 10 · Streak 6")

            DotsMetaLabel("Logo mark + wordmark", tint: DotsColor.Ink.secondary)
            HStack(alignment: .center, spacing: DotsSpacing.xl) {
                DotsLogoMark()
                DotsLogoMark(tint: DotsColor.brand, height: 32)
                DotsWordmark()
            }
        }
    }

    // MARK: Shaders

    private var shaderSection: some View {
        section("Shaders") {
            Picker("Shader", selection: $shaderChoice) {
                ForEach(ShaderChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ZStack {
                shaderView
                    .clipShape(RoundedRectangle(cornerRadius: DotsRadius.Semantic.panel, style: .continuous))
                if burstVisible {
                    DotsSpectrumBurst {
                        burstVisible = false
                    }
                    .id(burstID)
                }
            }
            .frame(height: 380)
            .overlay(
                RoundedRectangle(cornerRadius: DotsRadius.Semantic.panel, style: .continuous)
                    .strokeBorder(DotsColor.Background.hairline, lineWidth: 1)
            )

            HStack {
                DotsMetaLabel("Drag to disturb · tap to plant")
                Spacer()
                Button {
                    burstID += 1
                    burstVisible = true
                } label: {
                    Text("Spectrum burst")
                        .font(DotsTypography.callout)
                }
                .buttonStyle(.glass)
            }
        }
    }

    @ViewBuilder private var shaderView: some View {
        switch shaderChoice {
        case .halftone:
            DotsHeroShaderView(.halftone)
        case .mosaic:
            DotsHeroShaderView(.mosaic)
        }
    }

    // MARK: Section scaffold

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DotsSpacing.md) {
            Text(title)
                .font(DotsTypography.title)
                .foregroundStyle(DotsColor.Ink.primary)
            Rectangle()
                .fill(DotsColor.Background.hairline)
                .frame(height: 1)
            content()
        }
    }
}

#Preview("Gallery") {
    DotsUIGallery()
        .frame(minWidth: 720, minHeight: 900)
}
