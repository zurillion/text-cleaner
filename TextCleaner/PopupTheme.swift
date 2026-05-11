import AppKit
import SwiftUI

enum PopupTheme: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark
    case midnight
    case ocean
    case forest
    case sunset
    case mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:   return "System"
        case .light:    return "Light"
        case .dark:     return "Dark"
        case .midnight: return "Midnight"
        case .ocean:    return "Ocean"
        case .forest:   return "Forest"
        case .sunset:   return "Sunset"
        case .mono:     return "Mono"
        }
    }

    /// Background fill of the popup card.
    var background: AnyShapeStyle {
        switch self {
        case .system:
            return AnyShapeStyle(.regularMaterial)
        case .light:
            return AnyShapeStyle(Color(red: 0.97, green: 0.97, blue: 0.98))
        case .dark:
            return AnyShapeStyle(Color(red: 0.13, green: 0.13, blue: 0.15))
        case .midnight:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.10, green: 0.10, blue: 0.22), Color(red: 0.18, green: 0.10, blue: 0.30)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .ocean:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.04, green: 0.20, blue: 0.32), Color(red: 0.05, green: 0.34, blue: 0.40)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .forest:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.07, green: 0.18, blue: 0.13), Color(red: 0.12, green: 0.26, blue: 0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .sunset:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.99, green: 0.85, blue: 0.70), Color(red: 0.96, green: 0.65, blue: 0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .mono:
            return AnyShapeStyle(Color(red: 0.18, green: 0.18, blue: 0.19))
        }
    }

    /// Primary text/icon color (for non-selected rows).
    var foreground: Color {
        switch self {
        case .system:   return .primary
        case .light:    return Color(red: 0.12, green: 0.12, blue: 0.15)
        case .dark:     return .white
        case .midnight: return Color(red: 0.90, green: 0.92, blue: 1.0)
        case .ocean:    return Color(red: 0.88, green: 0.97, blue: 1.0)
        case .forest:   return Color(red: 0.88, green: 0.98, blue: 0.88)
        case .sunset:   return Color(red: 0.30, green: 0.15, blue: 0.10)
        case .mono:     return Color(white: 0.92)
        }
    }

    /// Secondary/dim foreground (header, hint, chip text).
    var secondaryForeground: Color {
        foreground.opacity(0.55)
    }

    /// Accent / selection background.
    var accent: Color {
        switch self {
        case .system:   return .accentColor
        case .light:    return Color(red: 0.0,  green: 0.48, blue: 1.0)
        case .dark:     return Color(red: 0.40, green: 0.72, blue: 1.0)
        case .midnight: return Color(red: 0.62, green: 0.45, blue: 0.95)
        case .ocean:    return Color(red: 0.30, green: 0.82, blue: 0.95)
        case .forest:   return Color(red: 0.55, green: 0.85, blue: 0.40)
        case .sunset:   return Color(red: 0.92, green: 0.38, blue: 0.30)
        case .mono:     return Color(white: 0.88)
        }
    }

    /// Text/icon color on top of the accent background.
    var onAccent: Color {
        switch self {
        case .forest, .ocean, .mono: return Color.black.opacity(0.85)
        default:                     return .white
        }
    }

    /// Background for the "1…9" number chip on non-selected rows.
    var chipBackground: Color {
        foreground.opacity(0.10)
    }

    /// Border tint of the popup card.
    var borderTint: Color {
        switch self {
        case .system: return Color.primary.opacity(0.08)
        case .light:  return Color.black.opacity(0.10)
        case .sunset: return Color.black.opacity(0.10)
        default:      return Color.white.opacity(0.10)
        }
    }

    /// `NSAppearance` to apply to AppKit views (e.g., the rich-text editor)
    /// hosted inside the popup, so that system colors (text, cursor,
    /// selection) match the theme.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light, .sunset:
            return NSAppearance(named: .aqua)
        case .dark, .midnight, .ocean, .forest, .mono:
            return NSAppearance(named: .darkAqua)
        }
    }
}
