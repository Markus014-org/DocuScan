import SwiftUI

enum DokuTheme {
    static let orange = Color(red: 1.0, green: 0.43, blue: 0.04)
    static let turquoise = Color(red: 0.0, green: 0.70, blue: 0.69)
    static let background = Color(red: 0.87, green: 0.88, blue: 0.89)
    static let panel = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let ink = Color(red: 0.18, green: 0.21, blue: 0.24)
}

struct PrimaryActionStyle: ButtonStyle {
    let tint: Color
    init(tint: Color = DokuTheme.orange) { self.tint = tint }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.74 : 1)
    }
}

struct Surface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DokuTheme.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func surface() -> some View { modifier(Surface()) }
}
