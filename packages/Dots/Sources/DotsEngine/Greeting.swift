public import Foundation

/// Time-of-day greeting for the Home screen.
public enum Greeting {
    public static func text(at date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Late night thoughts"
        }
    }
}
