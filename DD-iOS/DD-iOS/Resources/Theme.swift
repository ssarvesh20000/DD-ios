import SwiftUI

enum DD {
    // Brand / accent
    static let accentLight  = Color(red: 0.043, green: 0.239, blue: 0.569) // #0B3D91  navy
    static let accentDark   = Color(red: 0.478, green: 0.682, blue: 1.000) // #7AAEFF  light navy

    // Surfaces
    static let bgLight       = Color(red: 0.957, green: 0.961, blue: 0.969) // #F4F5F7
    static let bgDark        = Color(red: 0.051, green: 0.067, blue: 0.090) // #0D1117
    static let cardLight     = Color.white
    static let cardDark      = Color(red: 0.086, green: 0.106, blue: 0.133) // #161B22

    // Text
    static let textLight     = Color(red: 0.043, green: 0.122, blue: 0.200) // #0B1F33
    static let textDark      = Color(red: 0.902, green: 0.929, blue: 0.953) // #E6EDF3

    // Borders
    static let borderLight   = Color.black.opacity(0.08)
    static let borderDark    = Color.white.opacity(0.08)

    // Semantic detection colors (unchanged — keep existing colorForLabel)
}

struct DDTheme {
    let scheme: ColorScheme
    var accent: Color   { scheme == .dark ? DD.accentDark  : DD.accentLight }
    var bg:     Color   { scheme == .dark ? DD.bgDark      : DD.bgLight }
    var card:   Color   { scheme == .dark ? DD.cardDark    : DD.cardLight }
    var text:   Color   { scheme == .dark ? DD.textDark    : DD.textLight }
    var secondary: Color { text.opacity(0.6) }
    var border: Color   { scheme == .dark ? DD.borderDark  : DD.borderLight }
}
