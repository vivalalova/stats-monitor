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
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(width: 280)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    PanelView {
        Text("CPU content")
    }
        .environment(AppSettings())
        .environment(SystemMonitor(settings: AppSettings()).start())
}
