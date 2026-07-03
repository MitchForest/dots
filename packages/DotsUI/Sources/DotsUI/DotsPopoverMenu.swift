public import SwiftUI

/// One action row in a `DotsPopoverMenu`.
public struct DotsPopoverMenuItem: Identifiable {
    public enum Role: Sendable {
        case destructive
        case standard
    }

    public let action: () -> Void
    public let id: String
    public let role: Role
    public let systemImage: String
    public let title: String

    public init(
        _ title: String,
        systemImage: String,
        role: Role = .standard,
        action: @escaping () -> Void
    ) {
        self.action = action
        self.id = title
        self.role = role
        self.systemImage = systemImage
        self.title = title
    }
}

/// The house popover menu: quiet rows, hairline discipline, hover highlight.
/// Present inside `.popover { }` anywhere an item needs contextual actions.
public struct DotsPopoverMenu: View {
    private let items: [DotsPopoverMenuItem]

    public init(items: [DotsPopoverMenuItem]) {
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                DotsPopoverMenuRow(item: item)
            }
        }
        .padding(DotsSpacing.xs)
        .frame(minWidth: 200, alignment: .leading)
    }
}

private struct DotsPopoverMenuRow: View {
    let item: DotsPopoverMenuItem

    @State private var isHovered = false

    private var tint: Color {
        item.role == .destructive ? DotsColor.Accent.red : DotsColor.Ink.primary
    }

    var body: some View {
        Button(action: item.action) {
            HStack(spacing: DotsSpacing.sm) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)
                Text(item.title)
                    .font(DotsTypography.body)
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, DotsSpacing.sm)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DotsRadius.sm, style: .continuous)
                    .fill(isHovered ? DotsColor.Surface.pressed : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(item.title)
    }
}

#Preview("Popover menu") {
    DotsPopoverMenu(items: [
        DotsPopoverMenuItem("Rename…", systemImage: "pencil") {},
        DotsPopoverMenuItem("Reveal in Finder", systemImage: "folder") {},
        DotsPopoverMenuItem("Delete", systemImage: "trash", role: .destructive) {}
    ])
    .padding(DotsSpacing.lg)
    .background(DotsColor.Background.primary)
}
