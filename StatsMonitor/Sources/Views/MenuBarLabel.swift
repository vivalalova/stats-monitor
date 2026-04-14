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
