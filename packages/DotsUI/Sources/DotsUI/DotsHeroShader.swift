/// The family of brand hero shaders that can fill the entry surface.
public enum DotsHeroShader: String, CaseIterable, Sendable, Identifiable {
    case mosaic
    case halftone

    public var id: String { rawValue }

    public var next: DotsHeroShader {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }
}
