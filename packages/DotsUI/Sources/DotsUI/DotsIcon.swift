public import SwiftUI

public enum DotsIconSize {
    public static let control: CGFloat = 24
    public static let badge: CGFloat = 16
}

public struct DotsIcon: View {
    private let systemName: String
    private var size: CGFloat = DotsIconSize.control

    public init(systemName: String, size: CGFloat = DotsIconSize.control) {
        self.systemName = systemName
        self.size = size
    }

    public var body: some View {
        image
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var image: Image {
        Image(systemName: systemName)
    }
}

#Preview {
    HStack(spacing: DotsSpacing.md) {
        DotsIcon(systemName: "house")
        DotsIcon(systemName: "bolt.fill")
        DotsIcon(systemName: "flame.fill")
        DotsIcon(systemName: "checkmark")
    }
    .padding()
    .background(DotsTheme.paperBase)
}
