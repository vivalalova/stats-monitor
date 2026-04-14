import SwiftUI

struct MenuBarItemLabel: View {
    let icon: String
    let text: String
    var width: CGFloat = 80

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text).monospacedDigit()
        }
        .frame(width: width)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    HStack(spacing: 16) {
        MenuBarItemLabel(icon: "cpu",          text: "42%")
        MenuBarItemLabel(icon: "display",      text: "18%")
        MenuBarItemLabel(icon: "memorychip",   text: "71%")
        MenuBarItemLabel(icon: "internaldrive",text: "55%")
        MenuBarItemLabel(icon: "network",      text: "↓1.2MB", width: 100)
    }
    .padding()
}
