import SwiftUI

enum PanelID: String, CaseIterable {
    case cpu, gpu, memory, disk, network, thermal, power, fans

    var accessibilityName: String {
        switch self {
        case .cpu:     String(localized: "CPU")
        case .gpu:     String(localized: "GPU")
        case .memory:  String(localized: "Memory")
        case .disk:    String(localized: "Disk")
        case .network: String(localized: "Network")
        case .thermal: String(localized: "Thermal")
        case .power:   String(localized: "Power")
        case .fans:    String(localized: "Fans")
        }
    }
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
            .padding(16)
            .frame(width: 280)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
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
