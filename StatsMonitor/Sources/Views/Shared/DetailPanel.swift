import SwiftUI

enum PanelID: String, CaseIterable {
    case cpu, gpu, memory, disk, network, thermal, power, fans
}

struct PanelView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(24)
            .frame(width: 280)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    PanelView {
        Text("CPU content")
    }
        .environment(AppSettings())
        .environment(SystemMonitor(settings: AppSettings()).start())
}
