import SwiftUI

enum PanelID: String, CaseIterable {
    case cpu, gpu, memory, disk, network

    var title: LocalizedStringKey {
        switch self {
        case .cpu:     "CPU"
        case .gpu:     "GPU"
        case .memory:  "Memory"
        case .disk:    "Disk"
        case .network: "Network"
        }
    }
}

struct PanelView: View {
    let id: PanelID
    let content: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailToolbar(title: id.title)
            content
        }
        .padding(16)
        .frame(width: 280)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    PanelView(id: .cpu, content: AnyView(Text("CPU content")))
        .environment(AppSettings())
        .environment(StatsViewModel())
}
