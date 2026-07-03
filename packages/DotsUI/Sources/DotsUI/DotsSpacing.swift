public import CoreGraphics

public enum DotsSpacing {
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 28
    public static let xxl: CGFloat = 40
}

public enum DotsControlSize {
    case xs
    case sm
    case md
    case lg

    public var height: CGFloat {
        switch self {
        case .xs: 24
        case .sm: 32
        case .md: 40
        case .lg: 52
        }
    }

    public var horizontalPadding: CGFloat {
        switch self {
        case .xs: 12
        case .sm: 14
        case .md: 18
        case .lg: 22
        }
    }

    public var labelSize: CGFloat {
        switch self {
        case .xs: 12
        case .sm: 13
        case .md: 15
        case .lg: 17
        }
    }

    public var medallionSize: CGFloat {
        switch self {
        case .xs: 16
        case .sm: 20
        case .md: 24
        case .lg: 30
        }
    }
}
