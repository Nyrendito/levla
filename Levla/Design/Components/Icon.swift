import SwiftUI

/// SF Symbols mapping for Levla — the design used Phosphor/Lucide-style strokes,
/// matched here to closest SF Symbols with consistent stroke weight.
enum LIcon {
    static func name(_ key: String) -> String {
        switch key {
        case "home":         return "house.fill"
        case "fridge":       return "refrigerator"
        case "recipe":       return "book.closed"
        case "cart":         return "cart"
        case "scan":         return "viewfinder"
        case "camera":       return "camera.fill"
        case "sparkle":      return "sparkles"
        case "clock":        return "clock"
        case "flame":        return "flame.fill"
        case "leaf":         return "leaf.fill"
        case "chevron":      return "chevron.right"
        case "chevronL":     return "chevron.left"
        case "chevronDown":  return "chevron.down"
        case "check":        return "checkmark"
        case "close":        return "xmark"
        case "search":       return "magnifyingglass"
        case "filter":       return "line.3.horizontal.decrease"
        case "dots":         return "ellipsis"
        case "minus":        return "minus"
        case "plus":         return "plus"
        case "receipt":      return "doc.text"
        case "users":        return "person.2.fill"
        case "user":         return "person.fill"
        case "heart":        return "heart.fill"
        case "bookmark":     return "bookmark.fill"
        case "drop":         return "drop.fill"
        case "mic":          return "mic.fill"
        case "bolt":         return "bolt.fill"
        case "box":          return "shippingbox"
        case "arrowR":       return "arrow.right"
        case "arrowL":       return "arrow.left"
        case "undo":         return "arrow.uturn.left"
        case "trash":        return "trash"
        case "edit":         return "pencil"
        case "bell":         return "bell.fill"
        case "snow":         return "snowflake"
        case "milk":         return "carton.fill"
        case "egg":          return "circle.fill"
        case "apple":        return "applelogo"
        default:             return "circle"
        }
    }
}

struct LSymbol: View {
    let key: String
    var size: CGFloat = 20
    var weight: Font.Weight = .semibold
    var body: some View {
        Image(systemName: LIcon.name(key))
            .font(.system(size: size, weight: weight))
    }
}
